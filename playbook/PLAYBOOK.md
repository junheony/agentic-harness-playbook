# Agentic Coding Harness Playbook (Mobile-First)

> Companion to AI Dev Playbook v5.5  
> Target: iPhone → Telegram Forum Topics → Mac Mini (Apple Silicon) → Claude Code (Anthropic) ⊕ opencode (Codex OAuth) ⊕ Hermes (메모리/라우팅)  
> 정책: 토큰 제약 없음 (풀 스로틀). 비용보다 처리량/품질 우선.

---

## 0. 개요 (Why this exists)

폰에서 보이스/텍스트만으로 멀티 프로젝트(<project-a>, <project-b>, <project-c>, <project-d> 등)를 동시에 굴리기 위한 영구 인프라. Anthropic ToS 안전 경로 (Codex OAuth 우회) 위에서 Claude Code 본진을 보존하면서 opencode 트랙으로 폭발력을 추가.

### 핵심 원칙

1. **Anthropic OAuth는 Claude Code 안에서만 사용** (2026-04-04 ToS 발효, 3rd-party 사용 금지)
2. **Codex OAuth는 opencode/Hermes 트랙에 사용** (OpenAI 공식 지원)
3. **Superpowers는 cross-harness 공통 메서돌로지 레이어**
4. **omo `ulw`는 opencode 한정 폭발 모드 — 풀스로틀 정책상 적극 사용**
5. **Hermes는 코딩 하네스가 아닌 메모리/메시징/디스패치 레이어**

### 레이어 스택

```
┌──────────────────────────────────────────────────────────────────┐
│ L4  진입점         : iPhone Telegram Topics / SSH (Termius)       │
│ L3  학습/메모리/   : Hermes 5 Pillar Core                         │
│     메시징           (Soul / Memory / User / Skills / Crons)      │
│                    + Gateway (20+ 채널) + MCP 양방향              │
│ L3' 지식베이스     : Obsidian Vault (CC + Daydream skill)         │
│ L3" 장기 자율운영  : Paperclip Company (routine/heartbeat)        │
│ L2  오케스트레이션 : CC native subagents | omo ulw (opencode)     │
│ L1  하네스         : Claude Code (Anthropic) ⊕ opencode (Codex)   │
│ L0  메서돌로지/스킬: Superpowers + 도메인 스킬 (xlsx/db/RE/vault) │
└──────────────────────────────────────────────────────────────────┘
```

**핵심 통찰**: Hermes는 단순 "메시징 게이트웨이"가 아니라 **시간이 지날수록 너에 대해 학습하는 영구 AI 코어**. 다른 모든 도구는 세션/작업 단위로만 살지만, Hermes만 **다년**에 걸쳐 너에 대한 모델을 deepening한다.

### 작업 라우팅 매트릭스

| 트리거 키워드 / 패턴               | 라우팅 대상                                          |
|------------------------------------|------------------------------------------------------|
| "ulw" / "ultrawork" / "풀세트"     | opencode + omo Sisyphus (Codex 트랙)                 |
| "hpp ulw" / "hyperplan"            | opencode + omo hyperplan (adversarial)              |
| "brainstorm" / "설계" / "기획"     | Claude Code + Superpowers `/brainstorming`           |
| "TDD" / "테스트부터"               | Claude Code + Superpowers (RED-GREEN-REFACTOR)       |
| "리뷰" / "PR 검토"                 | Claude Code + code-reviewer 서브에이전트            |
| "디버깅" / "에러" / "root cause"   | Claude Code + debugger/error-detective              |
| "보안 감사" / "audit"              | opencode + omo + Oracle / reverse-engineering 스킬  |
| "Excel" / "xlsx" / "재무 모델"     | Claude Code + xlsx skill                            |
| "DB" / "schema" / "쿼리" / "EXPLAIN" | Claude Code + postgres/sql 스킬 + Postgres MCP    |
| "바이너리" / "ghidra" / "reverse"  | opencode + reverse-engineering 스킬                 |
| "vault" / "노트" / "daydream" / "내가 쓴" | Claude Code + obsidian-claude-code (vault 액세스) |
| "회사" / "에이전트 팀" / "routine" / "스케줄" | Paperclip 대시보드 (localhost:3100)         |
| "상태" / "지금 뭐 돌고 있어"       | Hermes 직답 (Mission Control + Paperclip board 쿼리)|
| 보이스 노트 / 모호한 단일 발화     | Hermes → 분류 → 위 매트릭스로 재라우팅              |

---

## 1. 사전 준비 체크리스트

- [ ] 워크호스 서버: Mac Mini (Apple Silicon) 또는 Linux 서버 (Ubuntu 22.04+ 권장) — 헤드리스, Tailscale 연결, sleep 비활성화
- [ ] iPhone with Telegram app
- [ ] ChatGPT Plus 또는 Pro 구독 (Codex 액세스용)
- [ ] Claude Pro/Max 구독 (Claude Code 본진용)
- [ ] BotFather에서 새 Telegram bot 토큰 발급
- [ ] Telegram user_id 확인 (@userinfobot 에게 메시지)
- [ ] Homebrew 설치된 Mac Mini (macOS) 또는 apt 패키지 관리자 (Linux)
- [ ] Node.js 20+ (`brew install node`)
- [ ] Python 3.11+ (`brew install python@3.11`)
- [ ] uv (`brew install uv`)
- [ ] Termius (iPhone 앱) — SSH 폴백용

---

## 2. Phase 1 — Codex OAuth 라인 확보

목적: opencode/Hermes가 사용할 OpenAI 공식 OAuth 토큰 발급. ChatGPT Plus/Pro 구독 한도 내에서 사용자가 선택한 OpenAI 모델 (`${MODEL_LARGE}` / `${MODEL_BALANCED}` / `${MODEL_SMALL}` placeholder 참고) 사용.

### 실행

```bash
# Mac Mini에서
npm i -g @openai/codex

# 헤드리스 환경이면 device-auth 사용 (브라우저는 폰에서 열어도 됨)
codex login --device-auth

# 로그인 확인
codex login status    # exit code 0이면 성공
```

### 검증

```bash
codex --help
# Codex CLI options 출력되면 OK

# 가벼운 테스트
echo "hello" | codex exec "이 입력을 그대로 출력해"
```

### 메모

- 자격증명 저장 위치: `~/.codex/auth.json`
- Codex CLI 엔드포인트: `chatgpt.com/backend-api/codex/responses` (ChatGPT 구독 한도 적용)
- API 키 폴백 발급해두면 안전 (`OPENAI_API_KEY` 환경변수)

---

## 3. Phase 2 — opencode 설치 + Codex OAuth 플러그인

목적: opencode를 Codex 트랙의 메인 TUI로 사용. ChatGPT 구독 OAuth 그대로 활용.

### 실행

```bash
# opencode 본체 설치 (sst/opencode가 anomalyco로 이전됨)
# 안전 패턴: fetch → inspect → run
curl -fsSL https://opencode.ai/install -o /tmp/opencode-install.sh
less /tmp/opencode-install.sh   # 내용 확인 후 진행
bash /tmp/opencode-install.sh
# 또는 공식 GitHub README의 패키지 매니저 설치 안내 따르기:
#   https://github.com/anomalyco/opencode#install

# Codex OAuth 플러그인 인스톨러 (3rd-party — 사용 전 commit/버전 핀 권장)
npx -y opencode-openai-codex-auth@latest

# ~/.config/opencode/opencode.jsonc 자동 생성/패치 확인
cat ~/.config/opencode/opencode.jsonc
```

### 설정 파일 (`~/.config/opencode/opencode.jsonc`)

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": [
    "opencode-openai-codex-auth@latest"
  ],
  "model": "openai/${MODEL_LARGE}",
  "small_model": "openai/${MODEL_SMALL}",
  "provider": {
    "openai": {
      "options": {
        "auth": "oauth"
      },
      "models": {
        "${MODEL_BALANCED}": { "variants": ["max", "high", "medium"] },
        "${MODEL_LARGE}": { "variants": ["max", "high", "medium"] },
        "${MODEL_SMALL}": {}
      }
    }
  },
  "permission": {
    "edit": "allow",
    "bash": "allow",
    "webfetch": "allow"
  }
}
```

### 검증

```bash
opencode auth login    # 플러그인이 OAuth 자동 인식
opencode run "echo $(date)" --model=openai/${MODEL_LARGE} --variant=max
```

---

## 4. Phase 3 — Hermes 설치 + 5 Pillar 구성

**중요**: Hermes는 단순 게이트웨이가 아니라 **자기개선(self-improving) AI 코어**다. 시간이 지날수록 사용자에 대한 모델이 deepening되고, 자동으로 스킬을 만들고 개선한다. 게이트웨이는 그중 한 레이어일 뿐.

### Hermes 5 Pillar (Nous Research 공식 아키텍처)

| Pillar          | 무엇                                                       | 어디 저장                                |
|-----------------|------------------------------------------------------------|------------------------------------------|
| **Soul**        | 페르소나 (정체성/가치/톤/행동 경계) — 고정 프레임          | `~/.hermes/SOUL.md`                      |
| **Memory**      | 환경/프로젝트 컨벤션/도구 quirks/교훈 노트                 | `~/.hermes/MEMORY.md` (2,200자 한도)     |
| **User**        | 사용자 프로필 (이름/통신 선호/스킬 수준/피할 것)           | `~/.hermes/USER.md` (1,375자 한도)       |
| **Skills**      | 자동 생성 + 사용 중 개선되는 작업 스킬                     | `~/.hermes/skills/<name>/SKILL.md`       |
| **Crons**       | 6시간마다 heartbeat → memory consolidate / skill review    | `~/.hermes/crons.yaml`                   |

추가 시스템:

- **FTS5 cross-session recall** — 과거 대화 전문 검색 (SQLite full-text search)
- **Honcho dialectic user modeling** — 사용자 모델을 양방향(dialectic)으로 갱신
- **Self-improving loop** — Agent-curated memory + periodic nudges + skill self-improvement during use
- **Multi-platform gateway** — 20+ 채널 (CLI, Telegram, Discord, Slack, WhatsApp, Signal, Matrix, Email, SMS, ...)

> Kilo의 한 줄 정리: *"Hermes packages a gateway around a learning agent. OpenClaw packages an agent around a messaging gateway."*  
> Hermes의 핵심은 학습이지 메시징이 아님.

### 메모리 동작 메커니즘 (이해 필수)

```
세션 시작 시:
  └─ SOUL.md (frozen) + MEMORY.md (frozen snapshot) + USER.md (frozen snapshot)
       → system prompt에 주입
       → 이번 세션 동안 변경되지 않음

세션 진행 중:
  └─ Hermes가 새 사실 발견 시:
       → MEMORY.md / USER.md 즉시 디스크에 기록
       → 시스템 프롬프트 헤더에 "MEMORY: 73%" 같은 capacity 표시
       → 다음 세션부터 반영

용량 도달 시 (~80%):
  └─ Hermes가 자체 consolidation 트리거
       → 중복 제거, 요약, 압축
       → MEMORY.md를 다시 50-60% 수준으로

크론 heartbeat (매 6시간):
  └─ skill review, memory consolidate, output 정리, status 파일 쓰기
```

### 설치

> **TBD**: Hermes 설치 패턴은 공식 레포 README의 install 섹션을 따른다.
> 공식: <https://github.com/NousResearch/hermes-agent>
> curl|sh 직행 금지. fetch → inspect → run 패턴 권장.

```bash
# 예시 (실제 URL은 공식 README에서 확인)
# curl -fsSL <official-install-url> -o /tmp/hermes-install.sh
# less /tmp/hermes-install.sh
# sh /tmp/hermes-install.sh

# 모델 등록 (Codex OAuth 재사용)
hermes model
# 프롬프트:
# > Select provider: OpenAI
# > Reuse Codex auth from ~/.codex/auth.json? [Y/n]: Y
# > Select default model: ${MODEL_LARGE}
```

### Soul / Memory / User 초기 작성

`hermes init`을 실행하면 빈 템플릿을 생성한다. 직접 작성 또는 이 레포의 `examples/soul/` 참고.

```bash
hermes init
# ~/.hermes/SOUL.md, MEMORY.md, USER.md 생성
```

핵심 가이드:

- **SOUL.md**: 5-10줄. 정체성/가치/톤. 시간이 지나도 (거의) 안 바뀐다. 톤 드리프트 방지가 목적.
- **USER.md**: 10-30줄. 사용자 정보. "내가 누구인가". 이름/직업/선호 언어/스킬 수준/금기 사항. 1,375자 한도 안에서.
- **MEMORY.md**: 20-100줄. 환경 노트. 프로젝트 경로, 도구 quirk, 자주 쓰는 명령 패턴, 알아둘 교훈. 2,200자 한도.

> 한도 초과 시 Hermes가 자동 consolidate하지만, 처음 작성할 때 너무 욕심내지 말 것. 작게 시작해서 사용 중 Hermes가 자동 추가하게 두는 게 자연스럽다.

### 설정 파일 (`~/.hermes/config.yaml`)

```yaml
# 모델 / 추론
provider: openai
model: ${MODEL_LARGE}
small_model: ${MODEL_SMALL}
variant: max   # 토큰 제약 없으면 max 디폴트

# 5 Pillar
soul_file: ~/.hermes/SOUL.md
memory_file: ~/.hermes/MEMORY.md
user_file: ~/.hermes/USER.md
skills_dir: ~/.hermes/skills

memory:
  persistent: true
  fts5_recall: true            # 과거 대화 전문 검색
  honcho_user_modeling: true   # dialectic user model
  auto_consolidate_threshold: 0.80   # 80% 도달 시 자동 압축
  consolidation_strategy: "summarize"   # vs "trim"

skills:
  auto_creation: true          # 사용 중 자동 스킬 생성
  auto_improvement: true       # 사용 중 자동 개선
  hub_sync: false              # agentskills.io Hub 자동 동기화 (옵션)

crons:
  enabled: true
  heartbeat_interval_hours: 6
  tasks:
    - skill_review
    - memory_consolidate
    - output_cleanup
    - status_file_write

# 음성
voice:
  stt: faster-whisper
  stt_model: large-v3
  push_to_talk: true
  confidence_threshold: 0.7    # 이 미만이면 재확인 요청
  telegram_voice_bubbles: true

# 프라이버시 (시크릿 leak 방지)
privacy:
  redact_pii: true
  exclude_paths:
    - ~/.ssh/
    - ~/.gnupg/
    - ~/.config/gh/
    - ~/.codex/
    - ~/.claude/
    - ~/.aws/
    - "**/wallets/**"
    - "**/private-keys/**"
    - "**/tax-docs/**"
    - "**/.env*"

# Telegram (Phase 4에서 채움)
telegram:
  allowed_users: []
  allowed_chats: []          # [v2.1] 봇이 엉뚱한 그룹에 추가돼도 무시
  topic_routing: true
  auto_thread: false
  voice_response: true
  reply_threading: true

# MCP 서버들
mcp_servers:
  filesystem:
    command: npx
    args: ["-y", "@modelcontextprotocol/server-filesystem", "/Volumes/dev"]
  git:
    command: uvx
    args: ["mcp-server-git"]
  github:
    command: npx
    args: ["-y", "@modelcontextprotocol/server-github"]
    env:
      GITHUB_PERSONAL_ACCESS_TOKEN: ${GITHUB_TOKEN}
  postgres:
    command: uvx
    args: ["mcp-server-postgres"]   # connection string은 .pgpass 사용 (v2.1)
  playwright:
    command: npx
    args: ["-y", "@executeautomation/playwright-mcp-server"]
  # Phase 13~17에서 추가:
  # ghidra, obsidian, paperclip, ...

# 라우팅 (Phase 10에서 router/SKILL.md로 이관)
routing:
  enabled: true
  default_target: "self"
  rules_file: ~/.hermes/skills/router/SKILL.md
```

### Skill 자동 생성 동작 (이게 가장 중요)

Hermes가 자동으로 스킬을 만드는 트리거:

1. **반복 패턴 감지** — 같은/유사한 작업을 3회 이상 수행하면 자동 스킬화 후보
2. **사용자 명시적 트리거** — `hermes skill remember "<pattern>"` 또는 채팅에서 "이거 패턴이야"
3. **Cron heartbeat 중** — 최근 24h 활동 분석 → 자주 발생한 미캡처 패턴 발견 시

스킬 개선 동작:

- 스킬 사용 중 사용자가 결과 거부 → 다음 cron heartbeat에서 그 패턴을 스킬에 반영 (negative example)
- 스킬 사용 중 사용자가 명시적 칭찬 → positive example로 추가

이 메커니즘 덕분에 Hermes는 **시간이 지날수록 너에게 fit해진다**. omo/Claude Code/opencode와의 본질적 차이.

### 검증 (5 pillar 작동 확인)

```bash
# 1. Soul 작동 확인 — SOUL.md의 정체성으로 응답하는지
hermes chat -p "What's your name and what's your job?"
# → SOUL.md에 정의된 정체성으로 응답해야 함

# 2. User 인식 확인
hermes chat -p "What do you know about me?"
# → USER.md 내용 요약 응답

# 3. Memory 갱신 확인
hermes chat -p "Add to memory: 내 메인 dev 머신은 Mac Mini (Apple Silicon)야"
# → 응답 후 ~/.hermes/MEMORY.md에 추가됐는지 확인
diff <(cat ~/.hermes/MEMORY.md) <(cat ~/.hermes/MEMORY.md.backup) 2>/dev/null
# 또는
grep "Mac Mini (Apple Silicon)" ~/.hermes/MEMORY.md

# 4. Cross-session recall 확인 (세션 종료 후 새 세션)
hermes chat -p "내 dev 머신 뭐였지?"
# → "Mac Mini (Apple Silicon)" 답변해야 함

# 5. 자동 스킬 생성 트리거
for i in 1 2 3; do
  hermes chat -p "Convert 2026-${i}-15 from KST to UTC"
done
# → ~/.hermes/skills/ 에 timezone-conversion 또는 유사 스킬 생성됐는지
ls ~/.hermes/skills/

# 6. MCP 도구 로딩
hermes mcp test
# → 등록된 서버들이 ✓ 표시되어야

# 7. Cron heartbeat (수동 트리거)
hermes cron run heartbeat
# → 로그에 skill_review / memory_consolidate 등 task 실행 확인
tail ~/.hermes/logs/cron.log
```

### Hermes vs 다른 도구 (시간축 비교)

| 도구              | 시간축          | 학습     | 영구성 |
|-------------------|-----------------|----------|--------|
| omo `ulw`         | 작업 (분~시간)  | ❌ 없음 | 세션 끝 |
| Mission Control   | 세션 (시간)     | ❌      | 휘발성  |
| Claude Code       | 세션 (시간)     | 부분*    | playbook v5.5 (수동) |
| **Hermes**        | **영구 (다년)** | **✅ 자동** | **SOUL/MEMORY/USER + skills** |
| Paperclip         | 영구            | 부분**   | 회사 정의 + audit log |

\* Claude Code는 CLAUDE.md를 수동 갱신해야 함 (Hermes는 자동)  
\** Paperclip은 routine 실행 이력 보존하지만 자기 학습 loop는 없음

### 트러블슈팅 (5 pillar 관련)

| 증상 | 원인 | 해결 |
|------|------|------|
| 새 세션에서 이전 사실 잊어버림 | MEMORY.md/USER.md 미갱신 | `hermes memory show` 확인. 사용자가 "기억해" 명시 안 했을 가능성 |
| MEMORY 95%+ 표시 | consolidation 실패 | `hermes consolidate --force` 또는 수동 편집 |
| Soul 톤이 흔들림 | SOUL.md 너무 추상적 | 더 구체적인 톤 예시 추가 (예: "답변 끝에 항상 확신도 표기") |
| 자동 스킬이 생성 안 됨 | auto_creation 비활성 또는 패턴 미감지 | config 확인 + `hermes skill remember` 수동 트리거 |
| 자동 스킬이 너무 많음 (노이즈) | threshold 낮음 | `config.skills.creation_threshold` 상향 |
| Cron heartbeat 안 돔 | crons.enabled: false 또는 launchd 미등록 | Phase 6 launchd 등록 확인 |

---

## 5. Phase 4 — Telegram bot + Forum Topics

목적: 폰의 1차 진입점. 프로젝트별 토픽 분리 → Hermes session_key 자동 격리.

### Telegram 측 작업

1. iPhone Telegram에서 BotFather와 대화
   - `/newbot` → 이름/username 설정 → 토큰 받기
   - `/setprivacy` → Disable (그룹 메시지 수신용)
   - `/setjoingroups` → Enable

2. 새 슈퍼그룹 생성
   - 이름: `<your-agentic-hq>` (또는 원하는 이름)
   - 봇 추가 + Admin 권한 (메시지 전송/편집/삭제/토픽 관리)
   - 그룹 설정 → **Topics** 활성화

3. 토픽 생성 (Forum)
   - `#general` (기본)
   - `#ops` (시스템 상태, 알람, 빌드)
   - `#<project-a>` (<project-a>)
   - `#<project-b>` (<project-b> 플랫폼)
   - `#<project-c>` (<project-c>)
   - `#<project-d>` (<project-d>)
   - `#<project-e>` (지갑 추적)
   - `#research` (시장/리서치)
   - `#scratch` (일회성)

### Hermes 측 설정

```bash
# 봇 토큰 등록 (macOS Keychain 권장 — 강화 v2.1)
security add-generic-password -a hermes -s telegram-bot-token -w "<TOKEN>"

# .env 파일 (Keychain 못 쓰는 환경용; 권한 600 필수)
cat >> ~/.hermes/.env << 'EOF'
TELEGRAM_BOT_TOKEN=<TOKEN>
TELEGRAM_ALLOWED_USERS=<your_user_id>
TELEGRAM_ALLOWED_CHATS=<your_supergroup_chat_id>
EOF
chmod 600 ~/.hermes/.env

# [v2.1 SECURITY] allowed_chats 핵심 — 봇이 엉뚱한 그룹에 추가돼도
# 그 그룹의 메시지는 무시. allowed_users만 있으면 부족함.

hermes gateway setup
# → Telegram 선택 → 토큰 자동 인식 → users/chats 화이트리스트 적용

# 슈퍼그룹 chat_id 확인 방법:
# 1. Telegram 데스크탑 → 그룹 → t.me/c/<chat_id> 형태 URL
# 2. 또는 봇이 그룹에 들어간 후 hermes log에서 chat_id 확인
```

### 토픽 → 컨텍스트 매핑

`~/.hermes/topic_map.yaml`:

```yaml
topics:
  general: { topic_id: 1, workdir: "~/dev" }
  ops: { topic_id: 2, workdir: "~/dev/ops", silent_default: false }
  <project-a>: { topic_id: 3, workdir: "~/dev/<project-a>", skills_extra: ["finance", "monitoring"] }
  <project-b>: { topic_id: 4, workdir: "~/dev/<project-b>", skills_extra: ["xlsx", "korean-tax"] }
  <project-c>: { topic_id: 5, workdir: "~/dev/<project-c>", skills_extra: ["solidity"] }
  <project-d>: { topic_id: 6, workdir: "~/dev/<project-d>", skills_extra: ["solidity", "perp-dex"] }
  <project-e>: { topic_id: 7, workdir: "~/dev/<project-e>", skills_extra: ["onchain"] }
  research: { topic_id: 8, workdir: "~/dev/research", skills_extra: ["web-research"] }
  scratch: { topic_id: 9, workdir: "~/scratch" }
```

> topic_id는 슈퍼그룹에서 토픽 만든 후 `scripts/topic-discover.sh`로 확인해서 채움. 위 숫자는 예시.

### 검증

폰에서 `#scratch` 토픽 진입 → "echo hello" 입력 → 봇이 답변하는지 확인.

---

## 6. Phase 5 — Claude Code ↔ Hermes MCP 브리지

목적: Claude Code 본진에서 폰 토픽으로 알림/결과 푸시. 폰에서 보낸 메시지를 Claude Code 컨텍스트로 가져오기. 양방향.

### Hermes를 MCP 서버로 노출

```bash
# Hermes가 stdio MCP 서버로 동작
hermes mcp serve --help
```

### Claude Code에 등록

```bash
# 프로젝트 디렉토리에서 (또는 글로벌)
cd /Volumes/dev

# 로컬 스코프 등록
claude mcp add hermes -- hermes mcp serve

# 또는 글로벌
claude mcp add hermes --scope user -- hermes mcp serve

# 확인
claude mcp list
# hermes: hermes mcp serve - ✓ Connected
```

### Claude Code 재시작 후 사용 가능한 도구

- `mcp__hermes__conversations_list` — 활성 Telegram 대화 목록
- `mcp__hermes__messages_read` — 특정 토픽의 최근 메시지
- `mcp__hermes__messages_send` — 토픽에 메시지 보내기
- `mcp__hermes__voice_send` — TTS로 음성 메시지 전송
- `mcp__hermes__skill_create` — 새 스킬 생성 (Hermes 메모리에 저장)

### 사용 예시 (Claude Code 안에서)

```
You: 이 빌드 끝나면 #<project-a> 토픽에 결과 알려줘.

Claude: [작업 수행 후]
       mcp__hermes__messages_send(
         target="telegram:#<project-a>",
         message="<project-a> 빌드 완료. 6개 컴포넌트 분리, 테스트 통과. PR #142 준비됨."
       )
```

---

## 7. Phase 6 — 서버 상시 가동

### macOS (Mac Mini): sleep 비활성화

```bash
sudo pmset -a sleep 0
sudo pmset -a disksleep 0
sudo pmset -a displaysleep 10   # 디스플레이만 sleep OK
sudo pmset -a womp 1            # WoL 활성화
sudo pmset -a autorestart 1     # 정전 후 자동 재부팅
```

### macOS: Hermes Gateway launchd 등록

```bash
hermes gateway install
# ~/Library/LaunchAgents/com.nousresearch.hermes.gateway.plist 자동 생성

launchctl list | grep hermes
# com.nousresearch.hermes.gateway   <PID>   0
```

### macOS: plist 수동 검증 (선택)

`~/Library/LaunchAgents/com.nousresearch.hermes.gateway.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.nousresearch.hermes.gateway</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/local/bin/hermes</string>
    <string>gateway</string>
    <string>run</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key>
  <dict>
    <key>SuccessfulExit</key><false/>
    <key>Crashed</key><true/>
  </dict>
  <key>StandardOutPath</key>
  <string>/Users/<USER>/.hermes/logs/gateway.out</string>
  <key>StandardErrorPath</key>
  <string>/Users/<USER>/.hermes/logs/gateway.err</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <!-- [v2.1 CRITICAL] Apple Silicon: /opt/homebrew/bin 우선. 
         하나라도 빠지면 hermes 명령 못 찾고 launchd가 죽음. -->
    <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
  </dict>
</dict>
</plist>
```

### Linux (systemd user unit)

Linux 서버 (Ubuntu 22.04+ / Debian 12+) 에서는 launchd 대신 systemd user unit을 사용.

```bash
# 1. 부팅 시 user 서비스 자동 기동 (로그인 없이도)
loginctl enable-linger "$USER"

# 2. unit 파일 생성
mkdir -p ~/.config/systemd/user ~/.hermes/logs
cat > ~/.config/systemd/user/hermes-gateway.service <<'EOF'
[Unit]
Description=Hermes AI Gateway
After=network.target
Wants=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/hermes gateway run
Restart=on-failure
RestartSec=5
EnvironmentFile=-%h/.hermes/.env
StandardOutput=append:%h/.hermes/logs/gateway.out
StandardError=append:%h/.hermes/logs/gateway.err

[Install]
WantedBy=default.target
EOF

# 3. 활성화 + 즉시 시작
systemctl --user daemon-reload
systemctl --user enable --now hermes-gateway.service

# 4. 상태 확인
systemctl --user is-active hermes-gateway   # active
journalctl --user -u hermes-gateway -n 20   # 로그 확인

# 5. Sleep/suspend 비활성화 (서버 환경 권장)
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
# 원복: sudo systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target
```

> **Tailscale**: Linux 서버에서도 동일. `curl -fsSL https://tailscale.com/install.sh | sh` 후 `sudo tailscale up --advertise-tags=tag:agent-host`

### Tailscale ACL (선택, 보안 강화)

`~/Library/Application Support/Tailscale/policy.hujson` (또는 admin console):

```hujson
{
  "tagOwners": {
    "tag:agent-host": ["autogroup:admin"],
    "tag:agent-client": ["autogroup:admin"]
  },
  "acls": [
    {
      "action": "accept",
      "src": ["tag:agent-client"],
      "dst": ["tag:agent-host:22,8080,11434"]
    }
  ]
}
```

- 서버 (Mac Mini 또는 Linux): `sudo tailscale up --advertise-tags=tag:agent-host`
- iPhone: tag:agent-client로 인증 (Termius/Tailscale 앱)

---

## 8. Phase 7 — 폰에서 검증 시나리오

### 시나리오 A: 텍스트 명령

```
#scratch 토픽에서:
> "Mac Mini 디스크 사용량 알려줘"

Hermes → 직답 (bash df -h 실행)
```

### 시나리오 B: 보이스 노트

```
#<project-a> 토픽에서 (보이스 노트):
"디더블유에프 워룸 대시보드 어제 변경사항 요약해줘"

Hermes:
1. Whisper STT → 텍스트 변환
2. Topic context: workdir=~/dev/<project-a>
3. git log --since=yesterday 실행
4. 결과 요약 → 같은 토픽에 회신
```

### 시나리오 C: 풀스로틀 위임

```
#<project-d> 토픽에서:
> "ulw 핵심 모듈 가스 최적화 + 테스트 보강"

Hermes:
1. "ulw" 패턴 매치 → opencode-omo 라우팅
2. SSH로 Mac Mini에서 tmux 새 세션
3. cd ~/dev/<project-d> && opencode
4. 세션에 "ulw 핵심 모듈 가스 최적화 + 테스트 보강" 주입
5. Sisyphus → plan → Hephaestus(impl) / Oracle(arch review) / Librarian(EIP-7702 등 spec) / Explore(현재 가스 측정) 병렬
6. 작업 진행상황을 #<project-d> 토픽에 주기적 push (5분 간격)
7. 완료 시 PR 링크 + 가스 절감 표 회신
```

### 시나리오 D: SSH 폴백 (TUI 직접 진입)

```
폰 Termius:
$ ssh user@<mac-mini-host>
$ tmux a -t main
# 또는
$ claude   # 본진 TUI
$ opencode # 확장 트랙 TUI
```

---

## 9. Phase 8 — Superpowers 설치 (양쪽 하네스)

목적: 모든 하네스에서 동일한 메서돌로지(brainstorming, TDD, code review, debug, skill writing) 강제.

### Claude Code 측

```bash
# Claude Code 안에서
/plugin marketplace
# Search: superpowers
# Install: obra-superpowers
```

또는 수동:

```bash
mkdir -p ~/.claude/skills
git clone https://github.com/obra/superpowers ~/.claude/skills/superpowers-source
# Claude Code가 ~/.claude/skills/* 자동 인식
```

### opencode 측

```bash
# opencode 안에서 자기 자신에게:
> Fetch and follow instructions from https://raw.githubusercontent.com/obra/superpowers/refs/heads/main/.opencode/INSTALL.md

# 또는 수동
mkdir -p ~/.config/opencode/plugins
cd ~/.config/opencode/plugins
git clone https://github.com/obra/superpowers
```

### 핵심 스킬

| 스킬 이름                          | 트리거 / 용도                                   |
|------------------------------------|--------------------------------------------------|
| `brainstorming`                    | 코딩 시작 전 Socratic 질문, 스펙 추출           |
| `using-git-worktrees`              | 격리된 worktree + 브랜치 생성                   |
| `test-driven-development`          | RED-GREEN-REFACTOR 강제                         |
| `subagent-driven-development`      | 작업 분할 → 서브에이전트 위임 → code-reviewer로 검증 |
| `systematic-debugging`             | Root cause 분석, 3회 실패 시 architectural review |
| `writing-skills`                   | 새 SKILL.md를 TDD로 작성                        |
| `verification-before-completion`   | 테스트/린트/타입체크 통과 확인 후 완료 선언      |

### Personal skill 오버라이드 (playbook v5.5 통합)

`~/.config/superpowers/skills/playbook-override/SKILL.md`:

```markdown
---
name: playbook-override
description: the user's personal playbook v5.5 conventions override Superpowers defaults
priority: 1000   # Higher than core
---

# Playbook v5.5 Personal Override

When working in the user's projects:

## TDD 적용 예외
- <project-a> 차트 컴포넌트 (시각 검증 우선)
- 일회성 데이터 분석 스크립트

## 6-7 step 응답 구조 사용
- 결론 → 핵심포인트 → 배경/가정 → 분석/추론 → 사실/데이터 → 검증/출처 → 요약/제안

## 신뢰도 태깅
- 모든 주장에 (높음/중간/낮음/미상) 부착

## Korean 본문 + 영어 코드
```

### 검증

```bash
# Claude Code 새 세션
> "Let's make a react todo list"

# 통과 기준: 코드 작성 안 시작, brainstorming 스킬 발동 → 요구사항 질문
```

```bash
# opencode 새 세션
> "Let's make a react todo list"

# 통과 기준: 동일 - brainstorming 스킬 발동
```

---

## 10. Phase 9 — oh-my-openagent (omo) + ulw

목적: opencode 안에서 multi-agent orchestration. Sisyphus 허브, Hephaestus/Oracle/Librarian/Explore 스포크. `ulw` 키워드로 풀스로틀.

### 설치

```bash
# opencode 안에서 자기 자신에게 위임:
> Install and configure oh-my-openagent following the instructions at:
> https://raw.githubusercontent.com/code-yeongyu/oh-my-openagent/refs/heads/dev/docs/guide/installation.md
```

### 설정 파일 (`~/.config/opencode/oh-my-openagent.jsonc`)

```jsonc
{
  // $schema는 oh-my-openagent 공식 레포 안내를 따른다 (URL은 시점에 따라 변동 가능):
  //   https://github.com/code-yeongyu/oh-my-openagent

  // 토큰 제약 없음 - max variant 디폴트
  "default_model": "openai/${MODEL_LARGE}",
  "default_variant": "max",

  "agents": {
    // 오케스트레이터 (허브)
    "sisyphus": {
      "model": "openai/${MODEL_BALANCED}",
      "variant": "max",
      "reasoningEffort": "xhigh"
    },
    // 깊은 구현
    "hephaestus": {
      "model": "openai/${MODEL_LARGE}",
      "variant": "max",
      "reasoningEffort": "xhigh",
      "temperature": 0.2
    },
    // 아키텍처 / 리뷰
    "oracle": {
      "model": "openai/${MODEL_BALANCED}",
      "variant": "max",
      "reasoningEffort": "xhigh"
    },
    // 문서 검색
    "librarian": {
      "model": "openai/${MODEL_SMALL}",
      "variant": "high"
    },
    // 탐색 / grep / AST-Grep
    "explore": {
      "model": "openai/${MODEL_SMALL}",
      "variant": "high"
    },
    // 비전통적 문제해결 (v3+)
    "artistry": {
      "model": "openai/${MODEL_BALANCED}",
      "variant": "max"
    },
    // 계획 수립 (v3+)
    "prometheus": {
      "model": "openai/${MODEL_BALANCED}",
      "variant": "max",
      "reasoningEffort": "xhigh"
    }
  },

  "ultrawork": {
    "enabled": true,
    "force_parallel_planning": true,
    "min_steps_for_plan_agent": 2,
    "stop_until_complete": true,
    "checkpoint_interval_seconds": 300,
    // 토큰 가드레일 제거 (max로) — 단 sanity 알람은 유지
    "budget_guard": {
      "enabled": false   // hard stop 없음
    },
    // [v2.1 DEBUGGER] specialist agent 무한 루프 방지
    "agent_timeouts": {
      "default_seconds": 1800,        // 30분
      "hephaestus_seconds": 3600,     // 1시간 (구현은 더 길게)
      "oracle_seconds": 1800,
      "librarian_seconds": 600,
      "explore_seconds": 600
    },
    "abort_on_repeated_failures": 3   // 같은 task 3회 실패 시 사용자 알람
  },

  // [v2.1 CODE-REVIEWER] sanity 알람 (정지 X, 알람만)
  "telemetry": {
    "alert_thresholds": {
      "monthly_tokens": 50000000,     // 5천만 토큰 도달 시 알람
      "daily_tokens": 5000000,        // 일일 5백만
      "single_task_tokens": 1000000   // 단일 task 백만 초과
    },
    "alert_channel": "telegram:#ops"
  },

  "hyperplan": {
    "enabled": true,
    "adversarial_cross_attack": true,
    "independent_analyses": 3
  },

  "background_tasks": {
    "enabled": true,
    "max_parallel": 8,
    "auto_resume_on_failure": true
  },

  "skills": {
    "builtin": ["playwright", "git-worktrees", "ast-grep", "lsp-tools"],
    "auto_load": true
  }
}
```

### 사용 패턴

```bash
opencode
```

세션 안에서:

```
> ulw <project-a> 핵심 모듈 가스 30% 절감, EIP-7702 호환, 풀 테스트 커버리지

[Sisyphus] 활성화. Plan agent 호출 중...
[Plan]     7개 병렬 태스크 그래프 생성
[Hephaestus] Task 1: bin packing 알고리즘 재구현 (xhigh)
[Oracle]   Task 2: EIP-7702 calldata 영향 분석 (xhigh)
[Librarian] Task 3: 최신 EIP-7702 spec 페치
[Explore]  Task 4: 현재 가스 측정 (forge gas-report)
[Artistry] Task 5: 비정형 최적화 후보 탐색
[code-reviewer] Task 6: 변경사항 검증 (subagent-driven-development 스킬)
[verification-before-completion] Task 7: foundry test + slither + coverage

... 병렬 진행 ...

[Result] 가스 31.4% 절감, 테스트 커버리지 94%, 보안 감사 통과
[PR ready] feat/gas-opt → main
```

### Hyperplan 모드 (adversarial)

```
> hpp ulw 보안 감사: <project-b> KYC 모듈

[hyperplan] 3개 독립 분석가 호출 (서로 모르는 채로 분석)
  - Analyst A: 데이터 흐름 관점
  - Analyst B: 권한/인증 관점
  - Analyst C: 외부 의존성 / SSRF 관점

[cross-attack] 각자 다른 분석가의 결론을 공격 → 약점 도출
[reconciliation] Sisyphus가 합의 산출
[Hephaestus] 발견된 취약점 패치
```

### 검증

```bash
# opencode 세션
> ulw hello world

# 통과 기준:
# - Toast: "Ultrawork Mode Activated - Maximum precision engaged"
# - Sisyphus가 plan 생성
# - 단순 작업이라 plan은 1-2 step
```

---

## 11. Phase 10 — Hermes 라우팅 SKILL.md

목적: Hermes가 폰 입력을 받아서 어떤 하네스/스킬로 보낼지 결정. 위 라우팅 매트릭스를 코드화.

### `~/.hermes/skills/router/SKILL.md`

```markdown
---
name: agentic-router
description: Routes user inputs to the right harness (Claude Code / opencode-omo / self) based on keywords, topic context, and complexity. Activates on every incoming message.
priority: 9999
auto_activate: true
---

# Agentic Router

## Routing Rules (Priority Order)

### 1. Explicit harness keywords (highest priority)
- `ulw` / `ultrawork` / `풀세트` / `폭주` → opencode + omo ulw
- `hpp ulw` / `hyperplan` → opencode + omo hyperplan
- `cc` (prefix) → Claude Code 강제
- `oc` (prefix) → opencode 강제

### 2. Domain keywords
- `excel`, `xlsx`, `재무 모델`, `DCF`, `pivot` → Claude Code + xlsx skill
- `schema`, `migration`, `EXPLAIN`, `index`, `query plan` → Claude Code + postgres skill + Postgres MCP
- `ghidra`, `reverse`, `disassembl`, `binary`, `.exe`, `.so`, `.dylib`, `crackme` → opencode + reverse-engineering skill
- `solidity`, `forge test`, `slither`, `EIP-` → opencode (Codex가 Solidity 강함)
- `brainstorm`, `설계`, `기획`, `discovery` → Claude Code + Superpowers brainstorming
- `TDD`, `red-green`, `테스트부터` → 현재 하네스 + Superpowers TDD
- `review`, `PR 검토`, `code review` → Claude Code + code-reviewer subagent
- `debug`, `에러`, `traceback`, `crash` → Claude Code + debugger/error-detective

### 3. Topic context (override default workdir)
- Topic `#<project-d>` → ~/dev/<project-d> (Solidity 색채 → opencode 우선)
- Topic `#<project-b>` → ~/dev/<project-b> (세무 → Claude Code + xlsx skill)
- Topic `#<project-c>` → ~/dev/<project-c> (Solidity + Satellite → opencode)
- Topic `#<project-a>` → ~/dev/<project-a> (대시보드 → Claude Code)
- Topic `#<project-e>` → ~/dev/<project-e> (on-chain → Claude Code)
- Topic `#ops` → /Volumes/dev/ops (인프라 → Hermes self 또는 Claude Code)
- Topic `#research` → 웹 리서치 → Hermes self
- Topic `#scratch` → 일회성 → Hermes self
- Topic `#general` → ad-hoc → Hermes self → 분류

### 4. Complexity heuristic
- 단어 수 < 10, 단일 질문 → Hermes self
- 코드 변경 동사 ("수정해", "추가해", "리팩토링") 포함 → 하네스 위임
- "분석", "감사", "검토" + "전체" / "모든" / "다" → opencode + omo ulw

### 5. Voice note input
- Whisper STT 후 위 규칙 재적용
- 음성 입력은 디폴트로 confirmation 한 번 더 (오인식 방지)

## Output Format

라우팅 결정을 다음 형식으로 출력:

```

[Route] target=<harness> | skill=<optional> | workdir=<path>
[Action] <one-line description>
[Confirm?] <yes if expensive / multi-step>

```

## Execution

`target` 값에 따라:

- `self` → Hermes 직접 처리
- `claude-code` → SSH → tmux new-window → `claude -p "<prompt>"` 또는 기존 세션에 inject
- `opencode-omo` → SSH → tmux new-window → `cd <workdir> && opencode` → "ulw <prompt>" inject
- `opencode-omo-hyperplan` → 위 + "hpp ulw <prompt>"

세션 끝나면 결과 요약 → 원래 토픽에 회신.

## Background Tasks

장시간 작업 (예상 > 5분):
1. 토픽에 즉시 "작업 시작" 알림 + ETA
2. tmux detached 세션으로 백그라운드 실행
3. 5분 간격으로 진행상황 push
4. 완료 시 결과 push + 토픽에 reply
```

### 활성화 확인

```bash
hermes chat
> [router] status

# Skill loaded, rules: 5 categories, 30+ patterns
```

---

## 12. Phase 11 — Excel/xlsx 스킬 통합

목적: <project-b> 세무 신고서, <project-a> 가격 분석, 재무 모델 등을 Claude Code/opencode 안에서 직접.

### 공식 스킬 설치 (Claude Code)

```bash
mkdir -p ~/.claude/skills/xlsx
curl -L https://raw.githubusercontent.com/anthropics/skills/main/skills/xlsx/SKILL.md \
  -o ~/.claude/skills/xlsx/SKILL.md

# 보조 스크립트들 (recalc, formatting)
git clone --depth=1 https://github.com/anthropics/skills /tmp/anthropic-skills
cp -r /tmp/anthropic-skills/skills/xlsx/* ~/.claude/skills/xlsx/
```

### opencode 측

```bash
mkdir -p ~/.config/opencode/skills/xlsx
cp -r /tmp/anthropic-skills/skills/xlsx/* ~/.config/opencode/skills/xlsx/
```

### Python 의존성

```bash
pip install --user openpyxl pandas matplotlib

# LibreOffice (recalc.py용)
brew install --cask libreoffice
```

### 사용 예시

```
#<project-b> 토픽에서:
> "2025년 거래 데이터 CSV 받아서 종합소득세 계산 시트 만들어줘.
   해외거래소 분리, 연도별 손익통산, 양도세 22% / 종합과세 6-45% 비교표."

→ Claude Code 라우팅 (Topic context)
→ xlsx skill 자동 발동
→ pandas로 CSV 분석
→ openpyxl로 다중 시트 워크북
   - Sheet1: Raw transactions
   - Sheet2: Year-over-year P/L (formulas)
   - Sheet3: Tax comparison table
   - Sheet4: Summary dashboard
→ Industry standard 색상:
   - 파란색: 하드코드 입력 (세율, 공제액)
   - 검정색: 공식 (=B2*0.22)
   - 녹색: 시트 간 참조
→ LibreOffice recalc.py로 공식 재계산
→ ~/dev/<project-b>/output/2025-tax.xlsx 저장
→ #<project-b> 토픽에 파일 링크 + 요약 push
```

### 핵심 메서드 표

| 작업 종류           | 도구                              |
|---------------------|-----------------------------------|
| 데이터 읽기/분석    | pandas (`pd.read_excel`)          |
| 새 워크북 생성      | openpyxl + 공식                   |
| 차트 생성           | openpyxl 차트 또는 pandas viz     |
| 공식 재계산         | LibreOffice headless recalc.py    |
| 기존 템플릿 수정    | openpyxl (스타일 보존)            |

### 트러블슈팅

- **공식 에러 (`#REF!`, `#VALUE!`)**: 스킬 정책상 zero-error 강제. 발생 시 검증 루프
- **한국어 인코딩**: 항상 UTF-8 BOM 없이 저장, openpyxl이 자동 처리
- **대용량 파일 (100MB+)**: `read_only=True` 모드 또는 청크 단위 처리

---

## 13. Phase 12 — Database 스킬 통합

목적: <project-b> DB, <project-e> 지갑 추적 DB, <project-d> 인덱서 등 직접 쿼리/스키마 설계/마이그레이션.

### Postgres MCP 서버 (모든 하네스에서 공유)

```bash
# 이미 Phase 3 hermes config에 포함됨
# Claude Code에도 등록
claude mcp add postgres -- uvx mcp-server-postgres \
  --connection-string "$POSTGRES_URL"

# 도구:
# - mcp__postgres__list_tables
# - mcp__postgres__execute_sql
# - mcp__postgres__describe_schema
# - mcp__postgres__explain_query
```

### Database 스킬들 설치

#### A. database-designer (스키마 설계 / 정규화 / 데이터 모델링)

```bash
mkdir -p ~/.claude/skills/database-designer
curl -L https://raw.githubusercontent.com/alirezarezvani/claude-skills/main/engineering/database-designer/SKILL.md \
  -o ~/.claude/skills/database-designer/SKILL.md
```

#### B. postgres (운영 / 인덱싱 / EXPLAIN)

```bash
mkdir -p ~/.claude/skills/postgres
git clone --depth=1 https://github.com/planetscale/database-skills /tmp/ps-db
cp -r /tmp/ps-db/postgres/* ~/.claude/skills/postgres/
```

#### C. sql-pro (멀티 DBMS 쿼리 최적화 서브에이전트)

```bash
mkdir -p ~/.claude/agents
curl -L https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/02-language-specialists/sql-pro.md \
  -o ~/.claude/agents/sql-pro.md
```

#### D. dbt 통합 (옵션, 데이터 엔지니어링)

```bash
mkdir -p ~/.claude/skills/dbt
git clone --depth=1 https://github.com/dbt-labs/dbt-claude-skill /tmp/dbt-skill 2>/dev/null || \
  echo "dbt skill: 커뮤니티 검색 필요"
```

### 환경변수 설정

**[v2.1 SECURITY]** Postgres 자격증명은 connection string에 절대 plaintext로 넣지 말 것.

#### 옵션 A: `.pgpass` 파일 (권장)

```bash
# ~/.pgpass 형식: hostname:port:database:username:password
cat >> ~/.pgpass << 'EOF'
localhost:5432:<project-b>:<user>:<password-from-keychain>
localhost:5432:<db-a>:<user>:<password-from-keychain>
localhost:5432:<db-b>:<user>:<password-from-keychain>
EOF
chmod 600 ~/.pgpass

# `.env`에는 비밀번호 빠진 URL만
cat >> ~/.hermes/.env << 'EOF'
POSTGRES_URL=postgresql://<user>@localhost:5432/<project-b>
POSTGRES_URL_DB_A=postgresql://<user>@localhost:5432/<db-a>
POSTGRES_URL_DB_B=postgresql://<user>@localhost:5432/<db-b>
EOF
chmod 600 ~/.hermes/.env
```

`mcp-server-postgres`는 `PGHOST/PGPORT/PGDATABASE/PGUSER` 환경변수 + `.pgpass` 자동 인식.

#### 옵션 B: macOS Keychain (최강)

```bash
security add-generic-password -a "$USER" -s postgres-<project-b> -w "<REAL_PASSWORD>"

# 사용 시:
PGPASSWORD=$(security find-generic-password -a "$USER" -s postgres-<project-b> -w) \
  psql -h localhost -U "$USER" -d <project-b>
```

#### 절대 금지

```bash
# ❌ 이렇게 하지 말 것 (v2 본문의 이전 패턴, 정정됨)
POSTGRES_URL=postgresql://user:pass@localhost:5432/<project-b>
```

이유: `.env`가 leak되거나 (git, backup, scp) ps/env로 노출되면 비밀번호 통째로 노출.

### 사용 예시

```
#<project-e> 토픽에서:
> "지난 24시간 동안 5만 달러 이상 거래한 새 지갑 찾고,
   각 지갑의 first-touch CEX 추론해줘"

→ Claude Code 라우팅
→ postgres skill 자동 발동
→ list_tables → wallets, transactions, cex_touches
→ EXPLAIN 우선:
    EXPLAIN (ANALYZE, BUFFERS)
    SELECT w.address, t.usd_value, ct.cex_name
    FROM wallets w
    JOIN transactions t ON t.wallet = w.address
    LEFT JOIN cex_touches ct ON ct.wallet = w.address
    WHERE t.ts > NOW() - INTERVAL '24 hours'
      AND t.usd_value > 50000
      AND w.first_seen > NOW() - INTERVAL '24 hours'
    ORDER BY t.usd_value DESC;
→ 인덱스 누락 발견 시 제안:
    CREATE INDEX CONCURRENTLY idx_wallets_first_seen
    ON wallets(first_seen DESC);
→ 결과 + 추론된 first-touch CEX 표
→ #<project-e> 토픽에 요약 + 풀 결과는 첨부 CSV
```

### 핵심 규칙 (스킬 내장)

- FK 컬럼은 자동 인덱싱 안 됨 → 반드시 추가
- `VACUUM` / `ANALYZE` 작업 후 EXPLAIN 재실행
- 큰 테이블 마이그레이션은 `CREATE INDEX CONCURRENTLY`
- Sequence gaps 정상 (롤백 시 발생, "고치지" 말 것)
- NUMERIC overflow는 silent 안 함 (PG는 에러 발생, 좋은 동작)

---

## 14. Phase 13 — Reverse Engineering 스킬 통합

목적: 외부 스마트 컨트랙트 ABI 없는 바이너리 분석, 경쟁 거래소 SDK 분석, iOS/Android 앱 RE, 의심 바이너리 트리아지.

### Ghidra 설치

```bash
# Ghidra 본체
brew install --cask ghidra
# /Applications/ghidra_*/ 설치됨
echo 'export GHIDRA_INSTALL=/Applications/ghidra_11.3_PUBLIC' >> ~/.zshrc
mkdir -p /Volumes/dev/_ghidra_workspace
echo 'export GHIDRA_WORKSPACE=/Volumes/dev/_ghidra_workspace' >> ~/.zshrc
source ~/.zshrc
```

### ghidra-cli (Rust 헤드리스 브릿지)

```bash
# Rust toolchain
brew install rustup-init && rustup-init -y

# ghidra-cli 빌드
git clone https://github.com/akiselev/ghidra-cli $WORKDIR_ROOT/_tools/ghidra-cli
cd $WORKDIR_ROOT/_tools/ghidra-cli
cargo install --path .

# 스킬 등록
cp -r .claude/skills/ghidra-cli ~/.claude/skills/
cp -r .claude/skills/ghidra-cli ~/.config/opencode/skills/
```

### iOS RE 스킬 (선택, iOS 앱 분석 시)

```bash
# 의존성
brew install blacktop/tap/ipsw
brew install radare2 rizin

# 스킬
git clone https://github.com/incogbyte/iOS-reverse-engineering-claude-skill /tmp/ios-re
cp -r /tmp/ios-re/skills/ios-reverse-engineering ~/.claude/skills/
cp -r /tmp/ios-re/commands/*.md ~/.claude/commands/
```

### wshobson reverse-engineering 플러그인 (멀티 툴체인)

```bash
git clone --depth=1 https://github.com/wshobson/agents /tmp/wshobson
cp -r /tmp/wshobson/plugins/reverse-engineering ~/.claude/plugins/
```

### Ghidra MCP 서버 (선택, MCP 통합 시)

```bash
# 이미 hermes config에 등록됨 (mcp_servers.ghidra)
# Claude Code에도 등록
claude mcp add ghidra -- ghidra-mcp \
  --workspace /Volumes/dev/_ghidra_workspace
```

### 사용 예시

#### 케이스 1: 외부 거래소 SDK 분석

```
#research 토픽에서:
> "이 .dylib 파일 분석해서 사용된 암호화 알고리즘과 외부 API endpoint 추출해줘.
   파일: /Volumes/dev/scratch/competitor-sdk.dylib"

→ opencode + reverse-engineering 스킬
→ ghidra import → analyze
→ FindSecrets.java 헤드리스 실행 → API 키 패턴 스캔
→ ExportCryptoUsage.java → AES/RSA/ECDSA 사용 추출
→ ExportAPICalls.java → 네트워크 endpoint 추출
→ 결과:
   - 암호: AES-256-GCM (libcrypto.dylib)
   - Endpoints: api.competitor.io/v3/{orderbook,trade}
   - 인증: HMAC-SHA256(secret, timestamp || method || path)
→ #research 토픽에 보고 + 디컴파일 코드 첨부
```

#### 케이스 2: iOS 앱 분석

```
#scratch 토픽에서:
> "이 IPA 안에 어떤 SDK 들어있고 보호 메커니즘 뭐 있는지 봐줘"

→ opencode + ios-reverse-engineering 스킬
→ /extract-ipa <path>
→ ipsw class-dump → Objective-C/Swift 클래스 추출
→ detect-sdks.sh → 임베디드 SDK fingerprinting (Firebase, AppsFlyer, etc.)
→ detect-protections.sh → 안티디버깅 / 무결성 체크 / 탈옥 검출 / FairPlay 검출
→ deep-secret-scan.sh → 하드코드된 클라우드 자격증명 스캔
→ 결과 요약 + #scratch 토픽에 push
```

#### 케이스 3: 스마트 컨트랙트 바이트코드

```
#research 토픽에서:
> "이 컨트랙트 주소 바이트코드 받아서 함수 시그니처 추출 + 거버넌스 권한 매핑"

→ opencode + omo (병렬)
→ Hephaestus: cast code <addr> → bytecode
→ Librarian: 4byte.directory에서 selector 매칭
→ Oracle: 권한 패턴 (onlyOwner, Ownable, AccessControl) 식별
→ Artistry: bytecode → high-level pseudo-Solidity 재구성
→ 결과: 함수 목록 + 거버넌스 권한 표 + 의심 패턴
```

### 안전 주의사항

**[v2.1 CRITICAL] 알 수 없는 출처의 바이너리는 호스트에서 직접 분석 금지.**

#### 격리 분석 (필수 패턴)

```bash
# Docker 격리 (권장)
docker run -it --rm \
  --network=none \
  --read-only \
  --tmpfs /tmp:rw,size=2g \
  -v $(pwd)/sample:/sample:ro \
  -v $(pwd)/output:/output:rw \
  ghidra-headless analyze /sample --output /output

# 또는 UTM/VMware 격리 (GUI 필요 시)
# - 스냅샷 기반 throwaway VM
# - 네트워크 차단
# - 호스트 공유 폴더 read-only
```

#### 사전 분석 (격리 진입 전)

```bash
# 항상 hash 먼저
shasum -a 256 sample.bin > sample.sha256

# 메타데이터만 추출 (실행 X)
file sample.bin
strings -n 8 sample.bin | head -50
# packer 검출
upx -t sample.bin 2>&1 | grep -q "NotPackedException" || echo "Packed binary detected"

# 위험 plate 패턴 검색
strings sample.bin | grep -iE "(eval|exec|system|/tmp/|cmd\.exe|powershell)"
```

#### 다른 안전 규칙

- iOS/Android RE: 본인 또는 명시 허가받은 앱만 (법적 경계)
- 회사 자산은 NDA 확인 (전 직장 자산 포함)
- 분석 산출물은 `#research` / `#scratch` 토픽에만; 자동 공개 채널 송신 절대 금지
- vault에 저장 시 별도 폴더 (`05-RE-Reports/`) + git ignore

---

## 15. Phase 14 — 추가 스킬 카탈로그 (Optional)

도메인별 유용 스킬. 필요할 때 설치.

### Frontend / UI

- `obra/superpowers` (이미 포함) - 메서돌로지
- `Vercel React Best Practices` - Next.js 성능 룰북
- `frontend-design` (Anthropic 공식, 디자인 토큰)

### Browser Automation

- Playwright MCP (이미 hermes config 포함)
- `superpowers/skills/browser-automation`

### Documentation / Spec

- `Context7 MCP` - 라이브러리 라이브 docs (Upstash)
- `superpowers/skills/writing-skills` - SKILL.md 작성 TDD
- `obra/code-clarity` - 가독성 리팩토링

### Solidity / DeFi

- `wshobson/agents/plugins/solidity-audit`
- Foundry 통합 (forge test, slither, mythril)
- Mainnet fork 테스트 패턴

### LLM Application

- `wshobson/plugins/llm-application` - LangGraph/RAG 패턴
- `superpowers/skills/llm-eval` - eval 작성

### Korean Tax / <project-b> 도메인 (커스텀)

이건 본인이 직접 만들어야 함. `~/.claude/skills/korean-crypto-tax/SKILL.md`:

```markdown
---
name: korean-crypto-tax
description: 한국 가상자산 과세 규정 (2027 시행) 및 CARF 호환. 양도세 22%/기본공제 250만원, 종합소득세 비교, 해외거래소 분리, 손익통산 1년 한정.
---

# Korean Crypto Tax (2027+)

## 핵심 규정
- 시행일: 2027-01-01 (예정)
- 양도세: 250만원 공제 후 22% (지방세 포함)
- 손익통산: 같은 과세연도 내, 다음 해 이월 불가
- 해외거래소 거래는 별도 신고 (외화자산명세서)
- CARF 자동 정보교환 (2027~)

## 계산 방식
- 선입선출 (FIFO) 디폴트
- 이동평균 (개별 자산별)
- 환산: 거래일 매매기준율 (한국은행)

## 신고서 양식
- 양도소득세 신고서 (서식 H03)
- 해외금융계좌 신고 (5억 초과 시)

## 데이터 소스
- 거래소 CSV: Upbit, Bithumb, Binance, Bybit
- 온체인: Etherscan, Arbiscan, Solscan
- 한국은행 환율 API

(... v5.5 playbook에서 가져온 디테일 ...)
```

---

## 16. Phase 15 — Obsidian Vault 통합

목적: 사용자의 Second Brain vault (리서치 노트, 학습 기록, 개인 도메인 자료, playbook 등)를 Claude Code/opencode에서 직접 검색/읽기/쓰기. 토픽 컨텍스트에 vault knowledge를 흘려넣기.

### 채택된 구현: Hermes built-in obsidian skill + vault mirror

> 옛 가이드는 `iansinnott/obsidian-claude-code` 가정 — 그 레포는 2026-05에 404. 우리는 더 깔끔한 대안 채택:
>
> **Hermes는 자체 `note-taking/obsidian` skill 내장**. `OBSIDIAN_VAULT_PATH` 환경변수만 설정하면 filesystem-first 패턴으로 동작 (`read_file`, `search_files`, `write_file`).
>
> 셋업:
>
> 1. Mac에서 Linux로 vault 단방향 sync (~/Documents/Obsidian Vault → ~/vault-mirror)
>    - `scripts/vault-mirror-sync.sh` (rsync + `--ignore-errors` for long-filename)
>    - launchd plist `com.user.vault-mirror-sync` 5분 간격
> 2. `~/.hermes/.env`에 `OBSIDIAN_VAULT_PATH=/home/<user>/vault-mirror` 추가
> 3. hermes-gateway 재시작
> 4. 폰 봇에 "vault에서 X 검색" → 자동 발동
>
> 자세히: [`docs/15-obsidian-vault-integration.md`](../docs/15-obsidian-vault-integration.md)
>
> agent가 vault에 **write 필요**하면 Obsidian Local REST API plugin + MCP 추가 (TBD, 별도 셋업).

### 설치

1) Obsidian 열고 Settings → Community plugins → Browse → "Claude Code" 또는 "MCP" 검색 → 활성 유지 중인 플러그인 선택 → Install + Enable

   또는 BRAT(Beta Reviewers Auto-update Tool) 경유 GitHub 직접 설치:

   - Community plugins → BRAT 설치 → "Add Beta Plugin" → 본인이 검토 후 선택한 레포 입력

2) 플러그인 설정에서:

- Enable WebSocket server: ✅
- Port: 22360 (default)
- Auto-discovery: ✅
- Workspace context: ✅ (active file + structure 노출)

### Claude Code 측 연결

```bash
# Claude Code 안에서
claude
> /ide
# 리스트에서 "Obsidian" 선택
# WebSocket 자동 연결됨

# 또는 수동 등록 (다른 MCP 클라이언트용)
claude mcp add obsidian --scope user -- \
  npx -y mcp-remote http://localhost:22360/sse
```

### Hermes 측 연결

`~/.hermes/config.yaml` 에 추가:

```yaml
mcp_servers:
  # 기존 항목 유지...
  obsidian:
    transport: http
    url: http://localhost:22360/sse
    headers: {}
```

### Vault Daydream 스킬 추가

비명백한 노트 간 연결 발굴용:

```bash
mkdir -p ~/.claude/skills/daydream
git clone --depth=1 https://github.com/glebis/claude-skills /tmp/glebis-skills
cp -r /tmp/glebis-skills/daydream/* ~/.claude/skills/daydream/

# opencode 측에도 복사
mkdir -p ~/.config/opencode/skills/daydream
cp -r /tmp/glebis-skills/daydream/* ~/.config/opencode/skills/daydream/
```

활성화: Claude Code에서 `/daydream` 슬래시 명령.

### 토픽 → Vault 영역 매핑 (`~/.hermes/topic_map.yaml` 확장)

```yaml
topics:
  research:
    topic_id: 8
    workdir: "~/dev/research"
    vault_path: "/Users/<USER>/Documents/SecondBrain"
    vault_subfolder: "00-Research"
    skills_extra: ["web-research", "daydream", "obsidian"]
  scratch:
    topic_id: 9
    workdir: "~/scratch"
    vault_path: "/Users/<USER>/Documents/SecondBrain"
    vault_subfolder: "99-Scratch"
```

### 사용 시나리오

```
#research 토픽 (보이스 노트):
"지난주 RWA TCG 리서치 노트들이랑 <project-d> 설계 노트들 사이에
 비명백한 연결 있는지 찾아줘"

→ Hermes (Topic context: research, vault enabled)
→ Claude Code 위임
→ /daydream 자동 발동
→ obsidian MCP의 search_vault로 RWA/TCG 관련 노트 풀
→ obsidian MCP의 search_vault로 <project-d> 관련 노트 풀
→ multi-agent scoring으로 cross-topic connection 산출
→ 발견된 연결:
   - 노트 "<project-c> 공급 잠금 메커니즘" ↔ 노트 "<project-d> MM 인벤토리 모델"
     (둘 다 supply-pressure 곡선이 비슷한 형태)
   - 노트 "TCG scarcity 논리" ↔ 노트 "<project-d> perpetual funding"
     (희소성 → 프리미엄 변환 패턴)
→ #research 토픽에 요약 + 노트 링크 + 새 노트 생성 제안
```

### Vault 검색 패턴 표

| Hermes/CC 도구              | 동작                                              |
|-----------------------------|---------------------------------------------------|
| `obsidian_search_notes`     | 노트 이름 검색 (regex 지원)                      |
| `obsidian_read_notes`       | 다중 노트 읽기                                    |
| `obsidian_read_notes_dir`   | 디렉토리 구조 나열                                |
| `obsidian_write_note`       | 새 노트 생성 (frontmatter 보존)                   |
| Vault Daydream `/daydream`  | 비명백 연결 multi-agent scoring                  |

### 양방향 작업 흐름

폰에서 vault에 쓰기:

```
#scratch 토픽:
"방금 떠올린 아이디어 - <project-c> 위성 SBT를 KOL 등급 시스템에 연동.
 vault에 저장해줘. 태그는 #<project-c> #kol #idea"

→ Claude Code → obsidian_write_note
→ 경로: 99-Scratch/2026-05-27-<project-c>-kol-sbt.md
→ frontmatter: tags: [<project-c>, kol, idea], created: 2026-05-27
→ #scratch 토픽에 "저장됨: 99-Scratch/2026-05-27-<project-c>-kol-sbt.md"
```

vault에서 작업 끌어내기:

```
Obsidian 데스크탑에서 작업 중:
- 노트 "<project-a> V2 아키텍처" 열어두고
- /ide에서 Obsidian 연결 확인
- Claude Code 사이드바에서:
  "이 노트 기반으로 컴포넌트 구조 코드로 변환해줘"
- Claude Code가 현재 active file 인식 → 구현 시작
```

### 보안 주의 — Vault 분리 (v2.1 CRITICAL)

**민감 자료를 메인 vault에 두면 AI가 무의식적으로 답변에 포함시킬 수 있다.**  
실제 사고 예시: "내 세무 자료 어디 있더라?" 질문 → AI가 vault 검색 → 답변에 계좌번호/지갑주소 포함된 chunk 그대로 노출.

#### 권장 구조: 3개 분리 vault

```
~/Documents/
├── SecondBrain/                  ← 메인 vault (Hermes/CC가 access 가능)
│   ├── 00-Playbooks/
│   ├── 03-Daily-Reports/
│   ├── 04-Content-Drafts/
│   ├── 05-RE-Reports/            ← Phase 13 산출물
│   └── 99-Scratch/
│
├── SecondBrain-Private/          ← AI access 절대 금지
│   ├── 01-Tax/                   (계좌번호, 신고서)
│   ├── 02-Wallets/               (지갑 라벨, 시드 힌트)
│   └── 03-Personal/              (가족, 개인 자료)
│
└── SecondBrain-Work/             ← NDA 자산 (선택)
    └── (전 직장, 클라이언트)
```

#### 강제 분리 방법

```bash
# Obsidian 플러그인 설정에서 vault path를 SecondBrain만 지정
# SecondBrain-Private/ 는 별도 Obsidian 인스턴스로 (포트도 다르게)
# 또는 아예 Obsidian-Claude-Code 플러그인 미설치

# 추가 안전망: Hermes config의 exclude_paths
privacy:
  exclude_paths:
    - "~/Documents/SecondBrain-Private/**"
    - "~/Documents/SecondBrain-Work/**"
    - "~/Documents/**/01-Tax/**"
    - "~/Documents/**/02-Wallets/**"
```

#### 기타 보안 규칙

- WebSocket은 localhost only 바인딩 (외부 노출 금지)
- Tailscale로 다른 디바이스 접근 시: `tailscale serve` 사용, 직접 외부 노출 X
- `privacy.redact_pii` (Hermes config) → vault 검색 결과에도 적용됨
- 정기적 audit: 한 달에 한 번 메인 vault에서 grep으로 민감 패턴 검색

  ```bash
  grep -rE "(\b\d{3}-\d{2}-\d{4}\b|seed phrase|private key|api_key=)" \
    ~/Documents/SecondBrain/ | head -20
  ```

---

## 17. Phase 16 — Paperclip Agent Company

목적: heartbeat 기반 **장기 자율 운영** 에이전트 회사. 일일/주간/월간 routine으로 자동 실행. omo `ulw`는 명령 시점 폭발용이고, Paperclip은 항상 백그라운드에서 돌아감.

> 정책: 인프라만 깐다. 구체적 회사/에이전트 정의는 프로젝트별로 본인이 로컬에서 직접 결정.

### 핵심 컨셉 정리

| Paperclip 용어        | 의미                                                |
|-----------------------|-----------------------------------------------------|
| **Company**           | 에이전트 팀 + 미션 + 조직도. 멀티 컴퍼니 격리 가능. |
| **Agent**             | 역할 + 어댑터(LLM/CLI/HTTP) + 권한 + 예산           |
| **Adapter**           | Claude Code / Codex CLI / 임의 HTTP bot / stdio CLI |
| **Routine**           | cron/webhook/API 트리거 정기 작업                   |
| **Goal / Issue**      | Routine 실행 또는 수동 생성, 에이전트가 픽업       |
| **Board**             | 사용자 (이사회). 승인 워크플로 통과해야 액션 실행   |
| **Capability**        | 에이전트가 호출 가능한 도구 (확장 가능)            |
| **Clipmart**          | 회사 import/export 마켓플레이스                     |
| **Heartbeat**         | 에이전트 스케줄 주기 ping                          |

### Mission Control vs Paperclip vs omo (다시 정리)

| 도구              | 시간 범위        | 주체                | 트리거       |
|-------------------|------------------|---------------------|--------------|
| Mission Control   | 세션 (몇 시간)   | 너 (수동 운영)      | 너의 명령    |
| omo ulw           | 작업 (몇 분~몇 시간) | Sisyphus 오케스트레이터 | 키워드 진입 |
| **Paperclip**     | **영구**         | **회사 에이전트들** | **cron/webhook/board** |
| Hermes            | 메시지           | Hermes              | 사용자 메시지 |

세 개 다 다른 시간축. 충돌 안 함.

### 설치 (Mac Mini)

```bash
# 빠른 경로 (npx)
npx paperclipai onboard --yes

# 또는 소스 클론
cd $WORKDIR_ROOT/_tools
git clone https://github.com/paperclipai/paperclip
cd paperclip
pnpm install
pnpm dev

# API 서버: http://localhost:3100
# UI: http://localhost:3100 (React UI 통합)
# 임베디드 PostgreSQL 자동 생성
```

요구사항:

- Node.js 20+
- pnpm 9.15+ (`npm i -g pnpm`)
- 디스크 5GB+ (PostgreSQL 데이터)
- (옵션) 외부 PostgreSQL 연결도 가능 — 더 큰 규모면 권장

### launchd 등록 (상시 가동)

`~/Library/LaunchAgents/com.paperclipai.server.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.paperclipai.server</string>
  <key>WorkingDirectory</key>
  <string>$WORKDIR_ROOT/_tools/paperclip</string>
  <key>ProgramArguments</key>
  <array>
    <string>/opt/homebrew/bin/pnpm</string>
    <string>start</string>
  </array>
  <key>RunAtLoad</key><true/>
  <!-- [v2.1] KeepAlive 정밀화 — true만 쓰면 빠른 크래시 루프 위험 -->
  <key>KeepAlive</key>
  <dict>
    <key>SuccessfulExit</key><false/>
    <key>Crashed</key><true/>
  </dict>
  <key>ThrottleInterval</key><integer>30</integer>
  <key>StandardOutPath</key>
  <string>/Users/<USER>/.paperclip/logs/server.out</string>
  <key>StandardErrorPath</key>
  <string>/Users/<USER>/.paperclip/logs/server.err</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
    <key>NODE_ENV</key>
    <string>production</string>
  </dict>
</dict>
</plist>
```

```bash
launchctl load ~/Library/LaunchAgents/com.paperclipai.server.plist
```

### paperclip-mcp 설치 (Claude Code/Hermes 연결)

```bash
# darljed/paperclip-mcp 클론
cd $WORKDIR_ROOT/_tools
git clone https://github.com/darljed/paperclip-mcp
cd paperclip-mcp
pnpm install && pnpm build

# Board API Key 발급 (Paperclip UI → Settings → API Keys → "Board Automation")
# .env 설정
echo "PAPERCLIP_API_URL=http://localhost:3100" > ~/.paperclip-mcp.env
echo "PAPERCLIP_BOARD_API_KEY=<your_key>" >> ~/.paperclip-mcp.env
```

Claude Code 등록:

```bash
claude mcp add paperclip --scope user -- \
  node $WORKDIR_ROOT/_tools/paperclip-mcp/dist/index.js
```

Hermes 등록 (`~/.hermes/config.yaml`):

```yaml
mcp_servers:
  paperclip:
    command: node
    args:
      - $WORKDIR_ROOT/_tools/paperclip-mcp/dist/index.js
    env:
      PAPERCLIP_API_URL: http://localhost:3100
      PAPERCLIP_BOARD_API_KEY: ${PAPERCLIP_BOARD_API_KEY}
```

Claude Code 안에서 사용 가능한 도구:

- `mcp__paperclip__list_companies`
- `mcp__paperclip__list_agents`
- `mcp__paperclip__create_issue`
- `mcp__paperclip__list_routines`
- `mcp__paperclip__trigger_routine`
- `mcp__paperclip__get_audit_log`

### 회사 정의 (사용자 결정 영역)

> 이 섹션은 프로젝트별로 직접 작성. 아래는 **골격 가이드**.

Paperclip UI(localhost:3100)에서:

1. "Create New Company"
2. Company 미션 한 줄
3. 조직도 정의:
   - 역할 이름
   - 어댑터 선택 (Claude Code / Codex / HTTP / CLI)
   - 시스템 프롬프트
   - 권한 (read/write/board-approval-needed)
   - 월 예산 (USD or tokens)
4. Routine 정의:
   - 트리거 (cron / webhook / API)
   - 담당 에이전트
   - 입력/출력 명세
5. Board approval 정책:
   - 어떤 액션이 사용자 승인 필요한지
   - 자동 승인 가능한 액션

### 의사결정 트리 (회사 만들기 전 자문)

```
이 워크플로가...
 ├─ 매일 1회 이상 자동으로 돌아야 하나?
 │   └─ NO → Paperclip 불필요. omo ulw 또는 Hermes cron으로 충분.
 │   └─ YES → 다음 질문
 │
 ├─ 여러 역할이 협업해야 하나? (분석가 + 작성자 + 검토자)
 │   └─ NO (단일 작업) → Hermes routine으로 충분
 │   └─ YES → 다음 질문
 │
 ├─ 결과물이 외부로 나가나? (콘텐츠 게시, 자금 이동 등)
 │   └─ YES → Paperclip Board approval 필수 → 회사 정의
 │   └─ NO (내부 리서치/리포트) → 회사 만들되 approval 느슨하게
```

### 권장 회사 골격 (참고용 — 본인이 채울 것)

```
Company 예시: "<your-research-lab>"
미션: 멀티 도메인 (크립토/RWA/세무/시장) 리서치 자동화

조직도:
  ├─ Director (Claude Code, Anthropic 직접)
  │   역할: 일일 미션 분배, 결과 검토
  │   예산: $X/월
  │
  ├─ Crypto Analyst (Codex via opencode)
  │   역할: <project-a>/<project-e> 데이터 분석, 이상치 감지
  │   Routine: 매일 09:00 KST
  │
  ├─ Tax Auditor (Claude Code + xlsx skill)
  │   역할: 주간 거래 집계, CARF 호환성 체크
  │   Routine: 매주 월요일 10:00 KST
  │   Board approval: 5억원 초과 거래 시
  │
  ├─ Content Drafter (Claude Code + Korean style)
  │   역할: 도메인 콘텐츠 초안 (X, Telegram 등 외부 채널)
  │   Routine: 매일 22:00 KST
  │   Board approval: 모든 외부 게시
  │
  └─ Vault Curator (Claude Code + obsidian MCP)
      역할: 새 리서치를 Obsidian vault에 저장
      Routine: 다른 에이전트 결과 트리거
```

> 위는 예시 골격. 실제 회사는 본인이 Paperclip UI에서 직접 정의.

### Paperclip ↔ Obsidian ↔ Hermes 통합 흐름

```
[Paperclip Routine: 매일 09:00]
   ├─ Trigger → Crypto Analyst (Codex via opencode + omo)
   ├─ 데이터 페치: <project-e> DB, 거래소 API
   ├─ 분석 결과 생성
   ├─ Vault Curator에 위임:
   │     → obsidian_write_note
   │     → 03-Daily-Reports/2026-05-27.md
   ├─ Director가 검토 (Claude Code)
   └─ 완료 시 Hermes 통해 #ops 토픽에 push
        "오늘 09시 리포트 완료 - 신규 큰손 3, 이상거래 1건"
```

### 일일 운영 명령

```bash
# 상태 확인
curl -H "X-API-Key: $PAPERCLIP_BOARD_API_KEY" \
  http://localhost:3100/api/companies | jq

# 또는 Claude Code 안에서
> mcp__paperclip__list_companies

# 특정 routine 수동 트리거
> mcp__paperclip__trigger_routine(id="daily-crypto-analysis")

# Audit log
> mcp__paperclip__get_audit_log(company="<your-research-lab>", days=7)
```

### Budget hard-stop

- 회사별 / 에이전트별 / 모델별 월 한도 설정
- 한도 도달 시 자동 일시정지 + 큐 작업 취소
- 너의 정책 ("토큰 제약 없음")상 한도 매우 높게 또는 무한
- 그래도 sanity guard로 회사당 $5000/월 추천 (가스라이팅 방지)

### Clipmart로 템플릿 import

```bash
# Paperclip UI → Clipmart → "Research Lab Template" 검색
# Import → 회사 골격 + 에이전트 + routine 자동 생성
# 너 환경에 맞게 수정
```

### 디버깅 / 트러블슈팅

- 에이전트가 무한 루프 → Board에서 즉시 pause
- routine이 안 돔 → cron 표현식 검증 (`* * * * *` 5자리, 초 단위 없음)
- API key 권한 부족 (이슈 #1177 참조) → "Board Automation" 권한 명시적 부여 필요
- PostgreSQL 잠금 → `pnpm db:reset` (개발 단계만, 프로덕션에선 절대 X)

### 보안

- Board API key를 macOS Keychain에:

  ```bash
  security add-generic-password -a paperclip -s board-api-key -w "<KEY>"
  ```

- `~/.paperclip-mcp.env`는 600 권한 + .gitignore
- 외부 노출 시 Tailscale serve 또는 Cloudflare Tunnel만 (직접 노출 금지)
- 자금 이동 / 외부 게시 routine은 Board approval ALWAYS 필수

---

## 18. Phase 17 — 통합 검증

Phase 1~16 다 깐 후 풀스택 검증 시나리오.

### 시나리오 1: 폰 보이스 → 풀스택 동원

```
#research 토픽 (보이스):
"어제 <project-e>에서 신규로 추적된 큰손 지갑들 vault에 정리하고,
 ulw로 cross-chain 패턴 분석해서 내일 09시 routine에 input으로 넣어줘"

→ Hermes router:
   - "vault" → obsidian + 
   - "ulw" → opencode-omo +
   - "내일 09시 routine" → paperclip 통합
→ 1단계: paperclip의 daily routine input 슬롯에 데이터 미리 등록
→ 2단계: opencode + omo ulw로 분석 실행 (Sisyphus + Hephaestus 등)
→ 3단계: 결과를 obsidian vault에 저장 (03-Daily-Reports/2026-05-27.md)
→ 4단계: paperclip Vault Curator가 내일 routine에 input 페치 등록
→ #research 토픽에 "완료" + vault 노트 링크 + paperclip routine 링크
```

### 시나리오 2: Obsidian 내부 → 코드 작업

```
Mac Mini Obsidian에서:
- 노트 "<project-d> MM 리밸런싱 알고리즘 v2" 열고
- /ide → Obsidian 연결
- Claude Code에서:
  "이 노트 기반으로 forge test 작성하고 ulw로 기존 컨트랙트 호환성 검증"

→ Claude Code: 노트 컨텍스트 페치
→ 노트 → 테스트 케이스 생성 (Superpowers TDD)
→ "ulw" 트리거 → opencode 새 세션 spawn → omo 호출
→ 결과 → Obsidian 노트에 "구현 결과" 섹션 자동 추가
→ Paperclip audit log에도 기록 (이슈 자동 생성)
```

### 시나리오 3: 자율 routine만으로 가동

```
22:00 KST: Paperclip "Content Drafter" routine 자동 트리거
→ 오늘의 #<project-a> / #research vault 노트 읽기
→ 어제 X 포스트 engagement 데이터 페치
→ 도메인 톤으로 3개 포스트 초안
→ Vault Curator: 04-Content-Drafts/ 에 저장
→ Board approval 요청 → 너 폰에 Telegram 알림 (#ops 토픽)
→ 너가 폰에서 ✅/✏️/❌
   - ✅ → X 게시 + Telegram 채널 게시
   - ✏️ → Hermes로 수정 명령 → 재초안
   - ❌ → 폐기
```

---

## 19. 운영 가이드

### 일일 체크

```bash
# Mac Mini ssh 후
hermes status
launchctl list | grep hermes
claude mcp list
```

### 주간 체크

- `~/.hermes/skills/` 검토 (자동 생성된 스킬 품질)
- `~/.hermes/logs/gateway.err` 에러 로그
- Telegram 사용 패턴 (어느 토픽이 가장 활성인지)
- omo 토큰 사용 통계 (ChatGPT 사용량)

### 월간 체크

- Superpowers / omo / opencode 업데이트
- 새 스킬 카탈로그 (composio.dev, claudedirectory.org)
- 커스텀 스킬 promotion (자주 쓰는 패턴 → 정식 SKILL.md)

### 백업

```bash
# 디바이스 간 동기화 (개인 git)
cd ~/.claude && git init && git remote add origin <private>
cd ~/.hermes && git init && git remote add origin <private>
cd ~/.config/opencode && git init && git remote add origin <private>

# 보안: ~/.hermes/.env, 토큰 파일은 .gitignore에
echo ".env" >> ~/.hermes/.gitignore
echo "auth.json" >> ~/.hermes/.gitignore
echo "credentials.json" >> ~/.hermes/.gitignore
echo "*.token" >> ~/.hermes/.gitignore
```

### 업데이트

```bash
# opencode (안전 패턴: fetch → inspect → run)
curl -fsSL https://opencode.ai/install -o /tmp/opencode-install.sh && less /tmp/opencode-install.sh && bash /tmp/opencode-install.sh

# Codex CLI
npm i -g @openai/codex@latest

# Codex OAuth 플러그인
npx -y opencode-openai-codex-auth@latest

# Hermes
hermes update

# omo
cd ~/.config/opencode/plugins/oh-my-openagent && git pull
# 또는 opencode 안에서:
> Update oh-my-openagent to latest

# Superpowers
cd ~/.claude/skills/superpowers-source && git pull
cd ~/.config/opencode/plugins/superpowers && git pull
```

---

## 20. 트러블슈팅

### Hermes gateway가 launchd로 안 살아남음

```bash
# 로그 확인
tail -f ~/.hermes/logs/gateway.err

# launchctl 강제 재로딩
launchctl unload ~/Library/LaunchAgents/com.nousresearch.hermes.gateway.plist
launchctl load ~/Library/LaunchAgents/com.nousresearch.hermes.gateway.plist

# PATH 문제면 plist의 EnvironmentVariables PATH 확인
# Apple Silicon: /opt/homebrew/bin 추가 필수
```

### Telegram 봇이 토픽 메시지 못 받음

- 봇 privacy mode 비활성화 확인 (BotFather `/setprivacy` → Disable)
- 그룹에 Admin 권한 (메시지 읽기 권한)
- Forum mode 활성화 + 봇이 토픽 권한 가짐

### ulw가 단순 작업에서도 트리거됨

라우터의 complexity heuristic 임계값 조정 (`~/.hermes/skills/router/SKILL.md`):

```markdown
### 4. Complexity heuristic (강화)
- ulw 키워드 + (단어 수 >= 15 또는 "전체"/"모든"/"모듈"/"시스템" 포함) → 트리거
- 단순 "ulw test"는 그냥 Hermes self
```

### opencode + Codex OAuth 토큰 만료

```bash
codex login --device-auth   # 재로그인
# opencode 재시작
```

### Ghidra headless OOM

```bash
# JVM 힙 증가
vi $GHIDRA_INSTALL/support/launch.properties
# VMARGS=-Xmx16G

# Mac Mini / MBP (충분한 RAM 가정)에서는 -Xmx32G까지 OK
```

### Claude Code MCP에서 hermes 도구 안 보임

```bash
# Claude Code 완전 재시작 필요 (MCP는 세션 시작 시 로딩)
# /restart 또는 앱 종료 후 재실행

# 등록 확인
claude mcp list
# hermes ✓ Connected

# stdio 통신 테스트
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | hermes mcp serve
```

---

## 21. 디렉토리 구조 (최종)

```
~/.claude/
├── CLAUDE.md                       # 너의 playbook v5.5 (글로벌)
├── agents/                         # 6개 서브에이전트
│   ├── code-reviewer.md
│   ├── test-automator.md
│   ├── docs-architect.md
│   ├── architect-reviewer.md
│   ├── debugger.md
│   ├── error-detective.md
│   └── sql-pro.md                  # Phase 12에서 추가
├── skills/
│   ├── superpowers-source/         # obra/superpowers clone
│   ├── xlsx/                       # Phase 11
│   ├── database-designer/          # Phase 12
│   ├── postgres/                   # Phase 12
│   ├── ghidra-cli/                 # Phase 13
│   ├── ios-reverse-engineering/    # Phase 13
│   ├── daydream/                   # Phase 15 (Obsidian vault mining)
│   └── korean-crypto-tax/          # 커스텀
├── plugins/
│   └── reverse-engineering/        # wshobson
├── commands/                       # 슬래시 명령 (Superpowers + 커스텀)
└── .mcp.json                       # MCP 서버 등록 (obsidian, paperclip 포함)

~/.config/superpowers/skills/
└── playbook-override/SKILL.md           # personal override

~/.config/opencode/
├── opencode.jsonc                  # Phase 2
├── oh-my-openagent.jsonc           # Phase 10
├── skills/
│   ├── xlsx/
│   ├── ghidra-cli/
│   ├── daydream/                   # Phase 15
│   └── ...
└── plugins/
    ├── superpowers/
    └── oh-my-openagent/

~/.hermes/
├── config.yaml                     # Phase 3 (obsidian + paperclip MCP 포함)
├── topic_map.yaml                  # Phase 4 (vault_path 매핑 포함)
├── .env                            # 토큰들 (.gitignore)
├── skills/
│   ├── router/SKILL.md             # Phase 10
│   └── <auto-generated>/           # Hermes 자동 생성
├── state.db                        # SQLite 메모리
└── logs/
    ├── gateway.out
    └── gateway.err

~/.codex/
└── auth.json                       # Codex OAuth 토큰

~/.paperclip/
├── logs/                           # Phase 16
│   ├── server.out
│   └── server.err
└── (embedded postgres 데이터)

~/Documents/SecondBrain/            # Phase 15 — Obsidian vault
├── .obsidian/
│   └── plugins/<obsidian-claude-bridge>/  # 셋업 시점에 선택한 community plugin
├── 00-Research/
├── 01-Tax/                         # 민감, 별도 vault 권장
├── 02-Wallets/                     # 민감, 별도 vault 권장
├── 03-Daily-Reports/               # Paperclip routine 산출물
├── 04-Content-Drafts/              # KOL 콘텐츠 초안
└── 99-Scratch/

/Volumes/dev/
├── _ghidra_workspace/              # Ghidra 프로젝트들
├── _tools/                         # 빌드한 도구들
│   ├── ghidra-cli/
│   ├── paperclip/                  # Phase 16 — clone
│   └── paperclip-mcp/              # Phase 16 — MCP 노출
├── <project-d>/
├── <project-a>/
├── <project-b>/
├── <project-c>/
├── <project-e>/
├── ops/
└── research/
```

---

## 22. 참고 링크

### 공식

- Anthropic Skills (xlsx 포함): <https://github.com/anthropics/skills>
- Anthropic Skill 마켓플레이스 (superpowers): <https://claude.com/plugins>
- Codex CLI 인증: <https://developers.openai.com/codex/auth>
- opencode 공식: <https://opencode.ai/docs>

### 코어 도구

- Superpowers (obra): <https://github.com/obra/superpowers>
- oh-my-openagent (omo): <https://github.com/code-yeongyu/oh-my-openagent>
- Hermes Agent (Nous Research): <https://github.com/NousResearch/hermes-agent>
- opencode-openai-codex-auth: <https://github.com/numman-ali/opencode-openai-codex-auth>

### 스킬 카탈로그

- agentskills.io (공식 오픈 표준)
- claudedirectory.org (스킬 디렉토리)
- composio.dev (도구 통합)
- claudemarketplaces.com (planetscale 등)

### MCP 서버

- modelcontextprotocol/server-filesystem
- modelcontextprotocol/server-github
- mcp-server-git (uvx)
- mcp-server-postgres (uvx)
- @executeautomation/playwright-mcp-server

### 도메인

- ghidra-cli: <https://github.com/akiselev/ghidra-cli>
- iOS RE skill: <https://github.com/incogbyte/iOS-reverse-engineering-claude-skill>
- wshobson agents: <https://github.com/wshobson/agents>
- VoltAgent subagents: <https://github.com/VoltAgent/awesome-claude-code-subagents>

### Knowledge / Vault (Phase 15)

- **Hermes built-in obsidian skill** (~/.hermes/hermes-agent/skills/note-taking/obsidian/) — 채택. filesystem-first 패턴 (read_file/search_files/write_file)
- **`scripts/vault-mirror-sync.sh`** — Mac → Linux rsync mirror (5분 간격, read-only for agent)
- Obsidian Local REST API (옵션): <https://github.com/coddingtonbear/obsidian-local-rest-api> — agent가 vault에 직접 write 필요할 때만
- Vault Daydream skill: <https://github.com/glebis/claude-skills> (daydream)
- Obsidian MCP server (frstlvl): <https://github.com/frstlvl/obsidian-mcp-server>

### Long-running Agents / Companies (Phase 16)

- Paperclip 본가: <https://github.com/paperclipai/paperclip>
- Paperclip 공식 사이트: <https://paperclip.ing/>
- paperclip-mcp: <https://github.com/darljed/paperclip-mcp>
- Paperclip 셀프호스팅 가이드: <https://contabo.com/blog/how-to-self-host-paperclip-on-contabo-vps/>
- MindStudio Paperclip + Claude Code 가이드: <https://www.mindstudio.ai/blog/how-to-build-multi-agent-company-paperclip-claude-code>

---

## 23. 실행 체크리스트 (요약)

폰에서 한 번에 보고 끝낼 수 있게:

```
[Codex OAuth]
□ npm i -g @openai/codex
□ codex login --device-auth
□ codex login status (exit 0)

[opencode]
□ fetch → inspect → bash /tmp/opencode-install.sh (curl|bash 직행 X)
□ npx -y opencode-openai-codex-auth@latest (SHA/버전 핀 권장)
□ ~/.config/opencode/opencode.jsonc 검증
□ opencode run 테스트

[Hermes]
□ 공식 레포 README의 install 안내 따르기 (TBD: 가이드 작성 시점에 안정 URL은 사용자 확인)
□ hermes model (OpenAI + Codex auth reuse)
□ ~/.hermes/config.yaml 작성 (Phase 3)
□ hermes mcp test

[Telegram]
□ BotFather에서 봇 생성
□ privacy/joingroups 설정
□ 슈퍼그룹 + Forum Topics 활성화
□ 9개 토픽 생성
□ hermes gateway setup
□ topic_map.yaml 작성
□ #scratch에서 echo 테스트

[Claude Code MCP]
□ claude mcp add hermes -- hermes mcp serve
□ claude mcp list 확인
□ Claude Code 재시작

[상시 가동]
□ sudo pmset -a sleep 0
□ hermes gateway install
□ launchctl list | grep hermes
□ (옵션) Tailscale ACL

[Superpowers]
□ /plugin install superpowers (CC)
□ opencode INSTALL.md 자동 위임
□ ~/.config/superpowers/skills/playbook-override 작성
□ "let's make X" 테스트 → brainstorming 발동 확인

[omo]
□ opencode에서 자기 자신에게 설치 위임
□ ~/.config/opencode/oh-my-openagent.jsonc 작성
□ "ulw hello" Toast 확인

[Router]
□ ~/.hermes/skills/router/SKILL.md 작성
□ hermes chat에서 [router] status 확인

[도메인 스킬]
□ xlsx: anthropics/skills + openpyxl/pandas
□ database: postgres MCP + database-designer + postgres skill + sql-pro
□ RE: brew install ghidra + ghidra-cli + (iOS-skill 선택)

[Obsidian (Phase 15)]
□ Obsidian 데스크탑 + 셋업 시점에 활성 유지 중인 Obsidian↔Claude Code 브리지 plugin 설치
□ 플러그인 안내에 따른 포트/transport 확인
□ claude mcp add obsidian (또는 /ide 명령)
□ ~/.claude/skills/daydream + ~/.config/opencode/skills/daydream 설치
□ topic_map.yaml vault_path 추가
□ /daydream 슬래시 명령 테스트

[Paperclip (Phase 16)]
□ Mac Mini: npx paperclipai onboard --yes
□ localhost:3100 UI 접속 확인
□ launchd plist 등록 + KeepAlive 검증
□ paperclip-mcp 빌드 + Board API key 발급
□ claude mcp add paperclip
□ Hermes config mcp_servers.paperclip 등록
□ 의사결정 트리 기반 첫 회사 정의 (UI에서 직접)
□ 첫 routine 트리거 → audit log 확인

[검증]
□ 시나리오 A (텍스트) 통과
□ 시나리오 B (보이스) 통과
□ 시나리오 C (ulw 위임) 통과
□ 시나리오 D (SSH TUI) 통과
□ Phase 17 시나리오 1 (vault + ulw + paperclip) 통과
□ Phase 17 시나리오 2 (Obsidian active file → 코드) 통과
□ Phase 17 시나리오 3 (자율 routine + Board approval) 통과
```

---

## 부록 A — Anthropic harness 디자인 원리 (요약)

너의 playbook v5.5에 이미 통합된 내용 압축:

- **Tool budget**: 같은 모델도 tool 호출 예산이 다르면 결과 다름. omo는 ulw에서 무제한 가까운 budget.
- **Context engineering**: Just-in-time loading (skill 메타데이터만 보이고 본문은 on-demand). Superpowers/omo 둘 다 채택.
- **Sub-agent isolation**: 각 서브에이전트가 자기 컨텍스트만 본다. Claude Code native subagent + omo Hephaestus/Oracle 모두 이 패턴.
- **Verification loops**: 작성 → 테스트 → 리뷰 → 통과 강제. `verification-before-completion` 스킬이 강제.
- **Adversarial validation**: 같은 문제를 독립 분석 N개가 풀고 cross-attack. omo `hpp ulw`가 이걸 자동화.

## 부록 B — Karpathy LLM Wiki 패턴 적용

너의 playbook이 인용한 패턴 - 매 작업마다 다음 4개 노드 강제:

1. **WHY** (목적): brainstorming 스킬이 처리
2. **WHAT** (스펙): plan agent / Sisyphus가 처리
3. **HOW** (구현): Hephaestus / Claude Code main이 처리
4. **PROOF** (검증): verification-before-completion + code-reviewer가 처리

이 4단계가 빠진 상태로 코드 변경되는 걸 막는 게 Superpowers의 본질.

## 부록 C — 향후 확장 후보

크립토/DeFi 데이터:

- **Polymarket MCP**: 5분 BTC 전략 자동 실행 채널
- **Arkham/Nansen MCP**: <project-e> 추적 강화
- **DexScreener/GeckoTerminal MCP**: <project-a> 데이터 소스 자동화
- **Foundry MCP**: forge/anvil/cast 통합 (<project-d> 개발 가속)
- **Slither MCP**: 보안 자동 감사
- **Tenderly MCP**: 트랜잭션 시뮬레이션 + 디버깅

확장 도메인:

- **Claude Cowork 통합**: 비개발 자산 (Telegram KOL 채널, X 자동화)
- **Linear/Notion MCP**: 프로젝트 관리 통합 (Paperclip의 issue와 동기화)
- **Stripe/Toss MCP**: <project-b> 결제 자동화 (구독 운영 시)
- **DragonFly/Redis MCP**: Hermes state 캐시 외부화

Paperclip Clipmart 템플릿화:

- 너의 회사 정의가 안정되면 Clipmart에 export → 다른 KOL/개발자에게 판매 또는 OSS 공유

Hermes 자동 스킬 → Skill Hub 기여:

- agentskills.io 표준 호환이라 자동 생성된 좋은 스킬은 공개 기여 가능

Mission Control v2:

- 현재 자작 Mission Control을 Paperclip의 Multi-Company View와 합치는 방향
- 한 화면에서 회사들 + opencode 세션들 + Claude Code 세션들 통합 모니터링

---

*문서 끝. 업데이트 이력은 git log 사용. 이 문서 자체도 SKILL.md로 변환해서 `~/.claude/skills/agentic-harness-playbook/SKILL.md`에 두면 Claude Code가 직접 참조 가능.*
