---
name: agentic-router
description: Routes incoming messages (text/voice from iPhone Telegram topics, SSH commands, MCP calls) to the right harness target (Hermes self / Claude Code / opencode-omo / Paperclip / Obsidian). Activates on every incoming message. Analyzes intent → auto-selects skill + harness + model + workflow engine (Rule 0 meta-mapping), with keyword tables (Rule 1-9) as deterministic fast-path. Returns routing decision before any action.
priority: 9999
auto_activate: true
---

# Agentic Router

The single entry-point classifier. Every Telegram message, voice note, or external trigger passes through this skill before any work happens.

## Decision Output Format

Every routing decision returns:

```
[Route]   target=<harness>  | skill=<optional>  | workdir=<path>
[Action]  <one-line description of what will happen>
[ETA]     <expected duration, e.g. "instant", "2-5 min", "30+ min">
[Confirm] <yes|no — yes if cost/risk warrants explicit user OK>
```

Then either execute (if Confirm=no) or wait for user OK in the same topic.

## Routing Rules (Priority Order)

### Rule 0 — Context-Aware Auto Mapping (메타 규칙 · 모든 메시지에 선행)

> 핵심: **키워드 테이블에 없는 표현도** Hermes가 의도를 분석해 적절한 skill/harness/model/engine을 스스로 찾아 매핑·실행. 키워드 매칭(Rule 1~9)은 빠른 결정용 fast-path, 이 메타 규칙은 그 밖을 잡는 semantic fallback.

매 메시지 처리 순서:

```
1. Intent 분석 (LLM)
   "사용자가 실제로 원하는 것은?" → {build, fix, refactor, research,
   plan, status, review, debug, write, schedule, ...} 중 분류
   + 범위(파일1개 / 모듈 / repo전체) + 위험도(read-only / 파괴적) 추정

2. Skill 매칭 (description 기반)
   ~/.hermes/skills/*/SKILL.md 의 description 필드를 의도와 대조.
   (Hermes는 이미 skill description 매칭 + 6h skill-review cron 보유)
   가장 잘 맞는 skill 0~N개 선택.

3. (skill, harness, model, engine) 튜플로 매핑
   - harness: self / claude-code / opencode-omo  (Rule 5 topic 기본값 참고)
   - model:   아래 "모델 선택 매트릭스"
   - engine:  단순작업이면 직접, 대규모면 Rule 2b 외부 엔진

4. 결정론 우선 (deterministic > inferred)
   Rule 1~9 패턴이 동시에 명시적으로 매치되면 그쪽이 이김.
   아무 패턴도 강하게 안 맞을 때만 step 3의 추론 매핑을 실행.

5. 실행 (cost/risk 높으면 Confirm gate)
```

#### 모델 선택 매트릭스 (gpt-5.5 + Opus 4.8 주축, 나머지 용도별)

| 용도 | 모델 | 위치 | 비고 |
|------|------|------|------|
| **도구 실행 · 대화 · 라우팅** (always-on) | **gpt-5.5** (openai-codex) | Hermes 직접 | tool_use 안정 (omo_proxy Anthropic 분류 이슈 회피 — docs/10 §한계) |
| **깊은 구현 · 리뷰 · 전략 계획** (deep) | **Opus 4.8** (max, fallback 4.7) | omo sisyphus·oracle·prometheus·momus, categories deep/ultrabrain/artistry/visual-engineering | 무거운 reasoning |
| 균형 (중간 복잡도) | Sonnet 4.6 | omo metis(→fallback Opus 4.8)·atlas·sisyphus-junior, unspecified-*/writing | |
| 빠른 탐색 · 조회 | Haiku 4.5 | omo explore·quick | 저비용 대량 |
| 멀티모달 (이미지·스크린샷) | gpt-5-nano | omo multimodal-looker | vision |

규칙: **Hermes 본체는 항상 gpt-5.5** (대화·도구). 실제 heavy lifting은 opencode-omo에 위임하면서 위 매트릭스대로 agent별 모델 자동 선택. 모델을 사용자가 명시("opus로", "빠르게 haiku")하면 그 지정이 매트릭스를 override.

#### 매핑 로깅

추론 매핑이 실행되면 `~/.hermes/logs/router.log`에 `rule=0` + 선택 근거 1줄 기록 → 사용자가 교정 시 `learned-rules.yaml`로 승격 (Self-Modification Hooks 참고).

### Rule 1 — Explicit Harness Prefix (highest priority)

| Prefix      | Target                                |
|-------------|---------------------------------------|
| `cc:` `cc>` | Claude Code 강제                     |
| `oc:` `oc>` | opencode (Codex) 강제                |
| `hm:` `hm>` | Hermes 직접 (위임 안 함)             |
| `pc:` `pc>` | Paperclip API 호출                   |
| `ob:` `ob>` | Obsidian vault 작업 (CC 경유)        |

Example: `cc> 이 함수 리팩토링` → Claude Code 강제

### Rule 2 — Multi-Agent Burst Keywords

| Pattern (regex, case-insensitive)             | Target                          | Confirm |
|------------------------------------------------|---------------------------------|---------|
| `\b(ulw\|ultrawork\|풀세트\|폭주)\b`           | opencode-omo (Sisyphus 허브)   | yes (if 단어 수 < 15) |
| `\b(hpp\s*ulw\|hyperplan)\b`                  | opencode-omo-hyperplan          | yes     |
| `\b(forge\s+test\|slither\|foundry)\b`        | opencode + omo (Solidity 강함) | no      |

### Rule 2b — External Workflow Delegation (도구를 직접 만들지 말고 호출)

검증된 외부 워크플로우 엔진을 상황에 맞게 호출. 직접 구현 X.

| Pattern (regex, case-insensitive)             | Target / 호출                                  | Confirm |
|------------------------------------------------|-----------------------------------------------|---------|
| `\b(끝까지 반복\|완료까지\|ulw-?loop\|self-?loop)\b` | opencode `$ulw-loop "task"` (omo/lazycodex — Oracle 검증까지 self-referential loop, ulw 500회) | yes |
| `\b(계획 짜\|plan 짜\|전략 세우\|ulw-?plan\|prometheus)\b` | opencode `$ulw-plan "what"` (Prometheus 전략 planner → plans/<slug>.md, product code 안 씀) | no |
| `\b(작업 시작\|plan 실행\|start-?work\|체크박스)\b` | opencode `$start-work [plan]` (plan checkbox 전부 완료 → "ORCHESTRATION COMPLETE") | yes |
| `\b(전체 코드베이스\|대규모 마이그레이션\|codebase.?wide\|workflow)\b` | Claude Code **dynamic workflow** (프롬프트에 `workflow` 단어 prepend → JS 스크립트가 수십~수백 subagent 조율, v2.1.154+) | yes |
| `\b(deep.?research\|깊은 조사\|교차 검증\|cross.?validat)\b` | Claude Code `/deep-research <질문>` (multi-angle 웹검색 + 교차검증 + 인용 보고서) | no |

**선택 기준** (어느 엔진?):

- opencode 안 코딩 작업 (구현/리팩토링/디버그) → omo `$ulw-loop` / `$ulw-plan` / `$start-work`
- 코드베이스 전체 (대규모 마이그레이션/감사) → Claude Code dynamic workflow
- 웹 리서치/교차검증 → Claude Code `/deep-research`
- 단순 burst → 기존 Rule 2 `ulw`

### Rule 3 — Methodology Keywords (Superpowers + bootstrap)

| Pattern                                        | Target                                |
|------------------------------------------------|---------------------------------------|
| `새 프로젝트`, `프로젝트 시작`, `new project`, `bootstrap`, `DDD`, `클린.?아키텍처`, `clean.?architecture` | Claude Code + `new-project-bootstrap` skill (Phase A→B→C→D 4단계 강제) |
| `brainstorm`, `설계`, `기획`, `discovery`      | Claude Code + Superpowers `/brainstorming` |
| `TDD`, `red-green`, `테스트부터`               | 현재 하네스 + Superpowers TDD          |
| `리뷰`, `code review`, `PR 검토`               | Claude Code + code-reviewer subagent  |
| `debug`, `디버그`, `에러 분석`, `crash`        | Claude Code + debugger / error-detective |
| `worktree`, `격리`, `분기`                     | Superpowers using-git-worktrees       |
| `대시보드`, `dashboard`, `mission control`, `상황판` | Hermes self (`scripts/dashboard-render.sh` + `canvas-render.sh` 결과 안내) |
| `커밋해`, `푸시해`, `올려`, `commit`, `push`, `결과 저장`, `변경사항 저장` | 현재 토픽 workdir + `auto-commit-push` skill (`agent-commit-push.sh` 호출, agent/<task>-<ts> branch push) |

### Rule 4 — Domain Skill Keywords

| Pattern                                        | Target                                | Skill                          |
|------------------------------------------------|---------------------------------------|--------------------------------|
| `excel`, `xlsx`, `csv`, `재무 모델`, `DCF`, `pivot` | Claude Code                       | xlsx                           |
| `schema`, `migration`, `EXPLAIN`, `index`, `postgres`, `mysql` | Claude Code           | postgres + database-designer   |
| `query plan`, `slow query`, `N+1`              | Claude Code                           | sql-pro subagent               |
| `ghidra`, `reverse`, `disassembl`, `binary`, `.exe`, `.so`, `.dylib`, `crackme` | opencode | reverse-engineering (ghidra-cli) |
| `IPA`, `Mach-O`, `iOS app`, `class-dump`       | opencode                              | ios-reverse-engineering        |
| `solidity`, `EIP-\d+`, `foundry`               | opencode                              | (Codex Solidity 강함)          |
| `bytecode`, `selector`, `4byte`                | opencode + omo                        | reverse-engineering            |
| `vault`, `노트`, `obsidian`, `내가 쓴`, `예전에 정리` | Claude Code (via /ide)         | obsidian + daydream            |
| `daydream`, `연결`, `cross-topic`, `비명백`    | Claude Code                           | daydream                       |
| `회사`, `agent team`, `routine`, `스케줄`, `cron`, `매일`, `매주` | Paperclip API           | paperclip-mcp                  |
| `세무`, `tax`, `CARF`, `종합소득세`, `양도세`  | Claude Code                           | korean-crypto-tax + xlsx       |

### Rule 5 — Topic Context (workdir override)

토픽별 워크디렉토리는 `~/.hermes/topic_map.yaml`에서 로드. 기본 매핑:

| Topic              | Workdir                              | Default Harness | Extra Skills                 |
|--------------------|--------------------------------------|-----------------|------------------------------|
| `#general`         | `~/dev`                              | Hermes self     | -                            |
| `#ops`             | `~/dev/ops`                          | Hermes self     | -                            |
| `#<project-a>`     | `~/dev/<project-a>`                  | Claude Code     | monitoring                   |
| `#<project-b>`     | `~/dev/<project-b>`                  | Claude Code     | xlsx, domain-tax             |
| `#<project-c>`     | `~/dev/<project-c>`                  | opencode        | solidity                     |
| `#<project-d>`     | `~/dev/<project-d>`                  | opencode        | solidity, perp-dex           |
| `#<project-e>`     | `~/dev/<project-e>`                  | Claude Code     | onchain, postgres            |
| `#research`        | `~/dev/research`                     | Claude Code     | obsidian, daydream, web      |
| `#scratch`         | `~/scratch`                          | Hermes self     | -                            |

토픽 기본 하네스는 Rule 2-4가 명시적이지 않을 때 적용.

### Rule 6 — Status / Read-Only Queries

| Pattern                                        | Target            |
|------------------------------------------------|-------------------|
| `상태`, `지금 뭐`, `현재`, `status`            | Hermes self (Mission Control + Paperclip board 쿼리) |
| `로그`, `last log`, `에러 있어`                | Hermes self (logs 직접 tail) |
| `잔고`, `포지션`, `pnl`                        | Hermes self (read-only API 호출) |
| `오늘 일정`, `routine`, `예약`                 | Paperclip board read |

### Rule 7 — Complexity Heuristic

Rule 2 (ulw/hpp ulw) 트리거 후 confirmation 여부 결정:

```python
def needs_confirmation(message: str) -> bool:
    word_count = len(message.split())
    has_scope_marker = bool(re.search(
        r'\b(전체|모든|모듈|시스템|repo|codebase|전부)\b', message
    ))
    has_destructive = bool(re.search(
        r'\b(삭제|drop|truncate|migrate|deploy|publish|게시)\b', message
    ))
    
    # Always confirm destructive
    if has_destructive:
        return True
    
    # Confirm if explicit broad scope
    if has_scope_marker:
        return True
    
    # ulw on tiny input → likely test, no confirm
    if word_count < 5:
        return False
    
    # Default: confirm if estimated > 5 min
    return word_count > 15
```

### Rule 8 — Voice Note Handling

음성 입력 처리:

1. faster-whisper STT (Korean + English 혼용 인식)
2. 도메인 lexicon으로 후처리 보정:

   ```
   대체 사전 (STT 오인식 → 정답):
   "울워" → "ulw"
   "오엠오" → "omo"
   "오픈코드" → "opencode"
   "엠시피" → "MCP"
   "박" → "vault"
   "패이퍼크립" → "Paperclip"
   "베이스" → "vase" or "base" (context dependent)
   ```

3. 트랜스크라이브된 텍스트를 Rule 1~7 통해 재라우팅
4. **음성 입력은 디폴트로 confirmation 한 번 추가** (오인식 방지)
5. 신뢰도 < 0.8 STT 결과는 텍스트로 재확인 요청

### Rule 9 — Multi-Step Composition

여러 룰이 동시 매치되면 다음 우선:

1. Rule 1 (명시 prefix) 무조건 승
2. Rule 6 (read-only)이 다른 룰과 매치되면 read-only 먼저 (정보 수집)
3. Rule 2 (ulw)가 Rule 3/4 (스킬)와 매치되면 → opencode + omo 위에 해당 스킬 로드
4. Rule 5 (topic) 항상 workdir 설정 우선 (다른 룰의 target은 유지)

복합 예시:

```
사용자: "#<project-d> 토픽에서 'ulw 보안 감사 후 결과 vault에 저장'"

라우팅:
- Rule 1: 없음
- Rule 2: ulw → opencode-omo
- Rule 4: vault → obsidian + daydream (CC)
- Rule 5: #<project-d> → workdir=~/dev/<project-d>, opencode 기본

해결:
- Step 1: opencode + omo로 보안 감사 실행 (워크디렉토리=<project-d>)
- Step 2: 결과를 CC로 전달 → obsidian_write_note로 vault에 저장
- Step 3: #<project-d> 토픽에 요약 + vault 노트 링크
```

## Execution Logic

라우팅 결정 후 `target` 값에 따라:

### target=self (Hermes 직접)

Hermes의 빌트인 도구로 처리. 응답은 동일 토픽에 직접.

### target=claude-code

```bash
# tmux 세션 매니지먼트
SESSION="cc-${topic_name}"
if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  tmux new-session -d -s "$SESSION" -c "$workdir"
  tmux send-keys -t "$SESSION" -l -- 'claude'
  tmux send-keys -t "$SESSION" Enter
  sleep 2  # CC 부팅 대기
fi

# 프롬프트 인젝션 (-l: literal 모드로 키 이름 해석 방지, Enter는 별도 전송)
tmux send-keys -t "$SESSION" -l -- "$prompt"
tmux send-keys -t "$SESSION" Enter

# 백그라운드 결과 폴링 (5분 간격)
# 토픽에 진행상황 push
```

### target=opencode-omo

```bash
SESSION="oc-${topic_name}"
if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  tmux new-session -d -s "$SESSION" -c "$workdir"
  tmux send-keys -t "$SESSION" -l -- 'opencode'
  tmux send-keys -t "$SESSION" Enter
  sleep 2
fi

# ulw 키워드 자동 prepend (Rule 2에서 매치된 경우)
# -l: literal 모드로 키 이름 해석 방지, Enter는 별도 전송
PROMPT="ulw $prompt"
tmux send-keys -t "$SESSION" -l -- "$PROMPT"
tmux send-keys -t "$SESSION" Enter
```

### target=opencode-omo-hyperplan

위와 동일하되 `hpp ulw $prompt` 로 prepend.

### target=paperclip

```text
# MCP 도구 호출 (pseudo-code)
mcp__paperclip__create_issue(
  company="<your-research-lab>",
  title="$prompt",
  assigned_to="auto"  # routine engine이 적절한 에이전트 매칭
)

# 또는 routine 즉시 트리거
mcp__paperclip__trigger_routine(id="$routine_id")
```

### target=obsidian (CC 경유)

Claude Code의 obsidian MCP 도구 호출:

- `obsidian_search_notes` / `obsidian_read_notes` (검색/읽기)
- `obsidian_write_note` (쓰기)
- `/daydream` (cross-note connection mining)

## Background Task Push

장시간 작업 (ETA > 5 min):

1. 즉시 시작 메시지 + ETA push:

   ```
   [Started] opencode-omo + Sisyphus 진행 중
   [Workdir] ~/dev/<project-d>
   [ETA] ~15 min (보안 감사 + 패치 작성)
   ```

2. 5분 간격으로 진행상황 ping:

   ```
   [Progress 5min] Sisyphus → Hephaestus (impl) / Oracle (review) 병렬
   [Logs] forge test 실행 중 (32/45 통과)
   ```

3. 완료 시 결과 push + 토픽에 reply chain:

   ```
   [Done 17min] ✅ 감사 완료, 3개 패치 제안
   [PR] https://github.com/.../pull/142
   [Vault] ~/dev/<project-d>/audits/2026-05-27.md
   ```

## Confirmation Gate

`Confirm=yes` 케이스 처리:

폰에 confirmation 메시지:

```
[Confirm Required]
작업: ulw <project-d> 전체 모듈 가스 최적화 (예: 컨트랙트 가스 절감 + EIP 호환 검증)
예상 시간: 30~60분
예상 토큰: ~150K (Codex max variant)
영향: 컨트랙트 파일 12개 수정 예정
승인하려면: ✅
취소: ❌
수정 요청: ✏️ + 메시지
```

응답 받으면 그에 따라 진행.

## Self-Modification Hooks

라우터가 학습하면서 진화:

- 사용자가 라우팅 결과를 수정하면 (예: "다음부턴 그건 CC 말고 opencode로") → 해당 패턴을 `~/.hermes/skills/router/learned-rules.yaml`에 추가
- 주간 리뷰: `learned-rules.yaml`을 검토 후 메인 룰로 승격 또는 폐기

## Failure Modes / Fallback

- 라우팅 불확실 (어느 규칙도 강하게 매치 안 됨) → Hermes self가 분류 질문:

  ```
  [Clarify]
  이 요청을 어떻게 처리할까요:
  (a) 간단히 답변만 (Hermes 직접)
  (b) Claude Code 위임
  (c) opencode + omo 풀 위임
  ```

- 위임된 하네스가 응답 없음 (timeout 10분) → 알람:

  ```
  [Timeout] $target 응답 없음
  옵션: 재시도 | 다른 하네스 | 수동 진입 (SSH)
  ```

- 라우터 자기 모순 (룰 충돌) → 안전 디폴트는 Hermes self + 사용자 confirm

## Logging

모든 라우팅 결정은 `~/.hermes/logs/router.log`에:

```
2026-05-27T10:30:15Z | topic=#<project-d> | rule=2+5 | target=opencode-omo | confirm=yes | message="ulw 보안 감사..."
2026-05-27T10:30:42Z | user_response=✅
2026-05-27T10:31:05Z | dispatched to tmux session oc-<project-d>
2026-05-27T10:48:11Z | completed | duration=17m | result=success
```

## Skill Composition

이 라우터 자체는 다른 스킬을 invoke만 함. 본인이 코드 작성 등 직접 작업은 안 함.

호출되는 스킬:

- Superpowers (brainstorming, TDD, code-review, etc.)
- Vault skills (obsidian, daydream)
- Domain (xlsx, postgres, ghidra-cli, ios-reverse-engineering, korean-crypto-tax)
- Methodology (playbook-override)
- Bootstrap (new-project-bootstrap — Phase 0(infra) + A→B→C→D 5단계 신규 프로젝트 부트스트랩)
- Operations (dashboard-render, canvas-render — Mission Control 가시화)
- Git automation (auto-commit-push — agent 작업을 agent/<task>-<ts> branch에 자동 커밋+푸시)

라우터가 정확히 하는 일은 "어디로 보낼지" + "어떻게 보낼지" 결정과 dispatch. 그 다음은 호출된 곳에서 진행.

**스킬 자동 탐색**: 위 목록은 고정 매핑이 아님. Rule 0가 매 메시지마다 `~/.hermes/skills/*/SKILL.md`의 `description`을 의도와 대조해 새/숨은 스킬도 자동 선택. 새 스킬을 추가하면 (description만 잘 쓰면) 라우터 코드 수정 없이 즉시 라우팅 대상이 됨. Hermes의 6h skill-review cron이 자주 쓰는 패턴을 새 스킬로 승격하므로, 매핑 테이블은 시간이 갈수록 self-extending.
