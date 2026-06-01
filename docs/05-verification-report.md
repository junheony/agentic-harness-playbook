# Phase 1~17 Self-Review (6-Perspective Audit)

> ⚠️ **이것은 외부 독립 검토가 아닙니다.**
> 동일 저자가 Claude Code의 subagent를 6개 페르소나 (code-reviewer / test-automator / docs-architect / architect-reviewer / debugger / error-detective)로 실행하여 17개 Phase를 각자 관점에서 점검한 결과입니다. 시각 다각화는 되었지만, 외부 시각(다른 사용자가 실제로 셋업을 시도)은 아직 들어와 있지 않습니다.
>
> 발견된 issues는 본 PLAYBOOK 본문에 피드백되어 v2.1에서 반영됨.
>
> **외부 검토 환영** — Issue 또는 PR로 받음.

## 검토 페르소나 (subagent)

| 페르소나            | 검토 관점                                                  |
|---------------------|-------------------------------------------------------------|
| `architect-reviewer`| 시스템 아키텍처, 의존성, 기술 부채, 확장성                 |
| `code-reviewer`     | 코드 품질, 보안, 시크릿 관리, 유지보수성                   |
| `test-automator`    | 검증 가능성, 자동화 cover, 테스트 결정성                   |
| `docs-architect`    | 문서 명확성, API/명령 일관성, 신규 사용자 진입 장벽         |
| `debugger`          | 실패 모드, 복구 경로, 에러 핸들링                          |
| `error-detective`   | 로그 위치/형식, 근본 원인 추적 가능성, 관측성              |

## 평가 척도

- ✅ **PASS** — 현재 설계 그대로 OK
- ⚠️ **CONCERN** — 작동은 하지만 개선 권장
- 🔥 **CRITICAL** — 수정 없이 진행 시 실제 문제 발생 가능

---

## Phase 1 — Codex OAuth 라인 확보

### architect-reviewer

- ⚠️ **CONCERN**: OAuth 토큰은 `~/.codex/auth.json` 단일 파일에 저장. 다른 머신 (MBP, Linux devserver)과의 동기화 정책 미명시.
- **권장**: `~/.codex/auth.json`을 디바이스별로 독립 발급 (토큰 회전 시 한 머신만 영향).
- ⚠️ **CONCERN**: Codex CLI에 대한 의존성이 너무 강함. OpenAI가 정책 바꾸면 전체 스택 영향.
- **권장**: `OPENAI_API_KEY` 폴백 경로를 모든 컴포넌트(opencode, Hermes, omo)에 명시.

### code-reviewer

- ⚠️ **CONCERN**: `~/.codex/auth.json` 권한 체크 누락.
- **수정**: 설치 후 `chmod 600 ~/.codex/auth.json` 강제 + 헬스체크 스크립트에 포함.
- ✅ **PASS**: device-auth flow는 자격증명을 명령줄에 노출 안 함 (env vars/stdin 미사용).

### test-automator

- ⚠️ **CONCERN**: `codex login status` exit code만 체크. 실제 응답 품질 검증 없음.
- **권장**: 검증 명령 강화:

  ```bash
  result=$(echo "Reply only with the word OK" | codex exec --json | jq -r '.text')
  [[ "$result" == "OK" ]] || exit 1
  ```

### docs-architect

- ✅ **PASS**: 명령 예시 명확, 트러블슈팅 4가지 케이스 cover.
- 💡 **개선**: 디바이스 코드 입력 화면 스크린샷 추가 권장 (모바일에서 처음 시도하는 사용자용).

### debugger

- 🔥 **CRITICAL**: device-auth 코드 5분 타임아웃 시 사용자가 어디서 막혔는지 모름. 현재 가이드는 "재시도"만 안내.
- **수정 필요**: 타임아웃 시 출력 캡처 명시 + `codex logout && rm -f ~/.codex/auth.json` 클린업 명령 추가.

### error-detective

- ⚠️ **CONCERN**: Codex CLI 로그 위치가 문서화되지 않음. 디버깅 시 어디 봐야 할지 모름.
- **권장**: `CODEX_LOG_LEVEL=debug` 환경변수와 stderr 리다이렉트 패턴 명시:

  ```bash
  CODEX_LOG_LEVEL=debug codex exec "test" 2>~/codex-debug.log
  ```

---

## Phase 2 — opencode + Codex OAuth 플러그인

### architect-reviewer

- ⚠️ **CONCERN**: `opencode-openai-codex-auth` 플러그인은 3rd-party. 메인테이너가 정책 바뀌면 전체 트랙 위험.
- **권장**: 플러그인 commit SHA 고정 (`@v1.2.3` 또는 `@<sha>` 명시)

  ```jsonc
  "plugin": ["opencode-openai-codex-auth@1.2.3"]
  ```

### code-reviewer

- ⚠️ **CONCERN**: `permission` 섹션이 `"allow"` 통째로. CI/원격 환경에서는 위험.
- **권장**: 프로덕션-유사 환경에서는 `"ask"` 또는 화이트리스트 패턴:

  ```jsonc
  "permission": {
    "edit": "ask",
    "bash": { "allow": ["pnpm *", "git *", "forge *"], "ask": ["*"] },
    "webfetch": "ask"
  }
  ```

### test-automator

- ✅ **PASS**: `opencode run` 단일 명령 테스트 충분.
- 💡 **개선**: 변형(variant) 별 테스트도 권장 (`max`, `high`, `medium` 각각 동작 확인).

### docs-architect

- ⚠️ **CONCERN**: opencode 본가가 `sst/opencode` → `anomalyco/opencode`로 이전됐는데 본문 일부에 옛 경로 잔존.
- **수정**: 모든 URL을 `anomalyco/opencode`로 통일 + 호환성 노트 추가.

### debugger

- ⚠️ **CONCERN**: 인터랙티브 모드에서 freeze 시 복구 방법 없음.
- **권장**: 별도 트러블슈팅 케이스 추가 — `Ctrl+C` 안 먹으면 `pkill -9 opencode`.

### error-detective

- ⚠️ **CONCERN**: opencode 로그가 stdout으로만 — 백그라운드 실행 시 추적 어려움.
- **권장**: `opencode run --log-file ~/.opencode/logs/$(date +%Y%m%d).log ...` 패턴 표준화.

---

## Phase 3 — Hermes 설치 + Codex provider

> **⚠️ 이 Phase는 본문 v2에서 가장 큰 정정이 필요했음.** Hermes의 5 pillar 아키텍처가 충분히 풀리지 않았었음. v2.1에서 대수술됨 (별도 § Phase 3 확장 참조).

### architect-reviewer

- 🔥 **CRITICAL** (v2): Hermes를 "메모리 + 메시징 게이트웨이"로만 다룸. 실제로는 **5 pillar self-improving agent core** (Memory/Skills/Soul/Crons/Self-improvement).
- **수정 완료 (v2.1)**: Phase 3 본문 재작성. SOUL.md / USER.md / MEMORY.md 3-layer 메모리, autonomous skill creation, 6시간 cron heartbeat, FTS5 cross-session recall, Honcho dialectic user modeling 명시.

### code-reviewer

- ⚠️ **CONCERN**: `~/.hermes/.env` 의 모든 시크릿이 plaintext.
- **권장**: macOS Keychain 사용 강제 (`security add-generic-password`)
- **추가 발견**: SOUL.md / MEMORY.md / USER.md는 그 자체가 민감 정보 (개인 프로필, 환경, 자격증명 단서). vault git 공유 시 주의 필요.
- **수정 필요**: `.gitignore`에 `**/SOUL.md`, `**/USER.md`, `**/MEMORY.md` 명시.

### test-automator

- ⚠️ **CONCERN**: `hermes mcp test`만 검증. 실제 5 pillar 동작 검증 없음.
- **권장 추가 검증**:

  ```bash
  # Soul 적용 확인
  hermes chat -p "What's your name and role?"  # SOUL.md의 정체성으로 답해야 함
  
  # Memory 작동 확인 (세션 1)
  hermes chat -p "My favorite color is blue"
  # → 새 세션에서
  hermes chat -p "What's my favorite color?"
  # 응답에 "blue" 포함되어야 (USER.md에 자동 기록됨)
  
  # Skill creation trigger
  for i in {1..3}; do hermes chat -p "Convert 2026-${i}-15 to KST"; done
  # → ~/.hermes/skills/ 에 date-conversion 류 스킬이 생성되어야
  ```

### docs-architect

- 🔥 **CRITICAL** (v2): 문서가 SOUL.md/USER.md/MEMORY.md를 처음 보는 사용자에게 충분히 설명 못 함.
- **수정 완료 (v2.1)**: 각 파일의 목적/용량/주입 시점/consolidation 트리거 표로 명시 + 예시 파일을 `examples/soul/`에 추가.

### debugger

- ⚠️ **CONCERN**: 메모리 80% 도달 시 consolidation 트리거되는데, consolidation 실패 시 어떻게 되는지 미명시.
- **수정 필요**: 트러블슈팅에 케이스 추가:

  ```
  증상: 시스템 프롬프트 헤더에 "MEMORY 95%" + 응답 느림
  원인: consolidation이 실패 또는 미실행
  해결: hermes consolidate --force (또는 manually edit MEMORY.md)
  ```

### error-detective

- ✅ **PASS**: `~/.hermes/logs/` 경로 명시됨.
- ⚠️ **CONCERN**: 자동 스킬 생성 실패 케이스 (잘못된 frontmatter, 충돌 등) 로깅 정책 미명시.
- **권장**: `~/.hermes/logs/skill-creation.log` 분리 + 실패 시 사용자 알람.

---

## Phase 4 — Telegram bot + Forum Topics

### architect-reviewer

- ✅ **PASS**: Forum Topics 활용은 멀티 프로젝트 분리에 최적.
- 💡 **개선**: 토픽 추가/삭제 시 `topic_map.yaml` 동기화 자동화 (Hermes의 self-improving cron 활용 가능).

### code-reviewer

- ⚠️ **CONCERN**: 봇 토큰이 `~/.hermes/.env` plaintext (Phase 3 concern과 중복).
- 🔥 **CRITICAL**: `TELEGRAM_ALLOWED_USERS`만으로는 부족. 다른 사람이 봇을 그룹에 초대하면 그 그룹의 모든 메시지가 Hermes로 흘러감.
- **수정 필요**: `TELEGRAM_ALLOWED_CHATS` (특정 chat_id 화이트리스트) 추가:

  ```yaml
  telegram:
    allowed_users: [<id>]
    allowed_chats: [<your_supergroup_chat_id>]  # ← 추가
  ```

### test-automator

- ⚠️ **CONCERN**: 검증이 "echo test" 수동 입력. 자동화 안 됨.
- **권장**: Telegram Bot API의 sendMessage 직접 호출하는 e2e 테스트 스크립트:

  ```bash
  curl -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
       -d "chat_id=${CHAT}&message_thread_id=${SCRATCH_TOPIC}&text=auto-test"
  # → 30초 내에 봇 응답 폴링
  ```

### docs-architect

- ⚠️ **CONCERN**: 9개 토픽 이름이 본문에 흩어져 있음. 단일 표 부재.
- **수정 필요**: 토픽 한눈에 보는 표 + 각 토픽의 default workdir/skills 매핑.

### debugger

- ⚠️ **CONCERN**: 봇이 토픽 메시지 못 받는 경우 4가지 원인 있는데 분기 진단 가이드 부재.
- **수정 필요**: 단계별 진단 트리:

  ```
  봇 응답 없음
  ├── /setprivacy Disabled? 
  │   YES → 다음
  │   NO  → BotFather에서 변경
  ├── 봇 Admin 권한? → 그룹 설정 확인
  ├── allowed_users/allowed_chats 매칭?
  └── hermes gateway 실행 중? → launchctl list | grep hermes
  ```

### error-detective

- ⚠️ **CONCERN**: Telegram API 에러 (rate limit, network) 시 사용자가 모름.
- **권장**: `~/.hermes/logs/telegram.err` 분리 + 봇 healthcheck cron (5분마다 self-ping).

---

## Phase 5 — Claude Code ↔ Hermes MCP 브리지

### architect-reviewer

- ✅ **PASS**: stdio MCP는 표준 패턴.
- ⚠️ **CONCERN**: Claude Code 재시작 필요한 이유 (MCP는 세션 시작 시 로딩)가 본문에 한 줄 언급만. 신규 사용자가 놓치기 쉬움.

### code-reviewer

- ✅ **PASS**: `mcp__hermes__*` 도구는 권한 분리 잘됨.
- ⚠️ **CONCERN**: `messages_send` 가 어느 토픽으로든 보낼 수 있음. 의도치 않은 토픽으로 결과 푸시 가능성.
- **권장**: Claude Code 측 system prompt에 "토픽 명시 없으면 묻는다" 규칙 추가.

### test-automator

- ⚠️ **CONCERN**: MCP 도구 호출 검증을 사용자 수동에 의존.
- **권장**: `claude` CLI의 `-p` 모드로 자동 테스트:

  ```bash
  claude -p "List my Telegram conversations using hermes MCP" --max-turns 1
  ```

### docs-architect

- ✅ **PASS**: 도구 목록 명확.
- 💡 **개선**: 각 MCP 도구의 input/output 스키마 예시 추가.

### debugger

- ⚠️ **CONCERN**: MCP 연결 끊김 시 자동 재연결 정책 미명시.
- **권장**: `claude mcp restart hermes` 명령 안내 + 자동 재시도 설정.

### error-detective

- ✅ **PASS**: stdio 통신 테스트 명령 (`echo '{...}' | hermes mcp serve`) 명시됨.
- 💡 **개선**: JSON 응답 패턴 예시 추가 (사용자가 어떤 응답이 정상인지 알 수 있게).

---

## Phase 6 — Mac Mini 상시 가동

### architect-reviewer

- ⚠️ **CONCERN**: launchd 의존성 순서 미명시. Hermes는 Codex auth 살아있어야 동작하는데, 부팅 직후 Codex 토큰 로딩 실패 시 Hermes도 죽을 수 있음.
- **수정 필요**: plist에 의존성 명시 또는 retry 로직 안내.

### code-reviewer

- 🔥 **CRITICAL**: plist의 PATH에 `/opt/homebrew/bin` 누락 시 Apple Silicon에서 hermes 명령 못 찾음. 본문에 노트는 있지만 plist 예시에 이미 포함되어 있어야 함.
- **수정 필요**: 모든 plist 예시에 `/opt/homebrew/bin` 우선 포함.

### test-automator

- ⚠️ **CONCERN**: 재부팅 후 검증을 수동에 의존.
- **권장**: 부팅 후 헬스체크 cron 추가:

  ```bash
  # ~/Library/LaunchAgents/com.user.healthcheck.plist
  # 부팅 후 60초 대기 → hermes status, codex login status, claude mcp list 검증
  # 실패 시 #ops 토픽에 알람
  ```

### docs-architect

- ⚠️ **CONCERN**: `pmset` 명령들의 영향 (디스플레이 깜빡임, USB 디바이스) 미명시.
- **수정 필요**: 헤드리스 Mac Mini와 모니터 연결된 케이스 분리 설명.

### debugger

- 🔥 **CRITICAL**: `KeepAlive: true` 가 무한 재시작 루프 위험. 잘못된 설정이면 영원히 죽고 살리는 사이클.
- **수정 필요**: `KeepAlive: { SuccessfulExit: false, Crashed: true }` 구체화 + 재시작 빈도 가드.

### error-detective

- ✅ **PASS**: `StandardOutPath`, `StandardErrorPath` 명시됨.
- ⚠️ **CONCERN**: 로그 로테이션 정책 없음. 장기 운영 시 디스크 가득 참 가능.
- **권장**: `newsyslog.conf` 또는 매주 로그 회전 스크립트.

---

## Phase 7 — 폰에서 검증 시나리오

### architect-reviewer

- ✅ **PASS**: 시나리오 A/B/C/D 점진적 복잡도.
- 💡 **개선**: Cold start (재부팅 후 첫 요청)과 Warm 시나리오 분리.

### code-reviewer

- ⚠️ **CONCERN**: 시나리오 C의 `cc>` prefix 강제 — 보안상 디폴트가 너무 강력. 의도치 않은 위임 위험.
- **권장**: 첫 위임 시 confirmation 한 번 강제.

### test-automator

- ⚠️ **CONCERN**: 4개 시나리오가 수동 검증. 자동화 부재.
- **권장**: `scripts/verify-phase7.sh` 자동 시나리오 (Telegram Bot API + tmux assertion).

### docs-architect

- ✅ **PASS**: 기대 흐름 명확.

### debugger

- ⚠️ **CONCERN**: 보이스 노트 STT 실패 시 사용자 피드백 없음.
- **수정 필요**: STT confidence < 0.7 시 트랜스크립트를 토픽에 먼저 표시하고 confirm 받기.

### error-detective

- ✅ **PASS**: 시나리오별 검증 위치 명시.

---

## Phase 8 — Superpowers 설치

### architect-reviewer

- ✅ **PASS**: cross-harness 메서돌로지로 적절.
- ⚠️ **CONCERN**: Superpowers 7-step (brainstorm → worktree → plan → TDD → subagent → review → done) 강제는 일부 작업(quick fix, prototype)에 오버킬.
- **권장**: `playbook-override`의 TDD 예외 규정처럼 quick-fix 모드 명시.

### code-reviewer

- ⚠️ **CONCERN**: Superpowers는 셸 명령 실행 권한 광범위. 신뢰할 수 있는 마켓플레이스인가 확인 필요.
- **검증**: Anthropic 공식 marketplace 등재 — 신뢰도 높음 (Jesse Vincent maintainer).

### test-automator

- ✅ **PASS**: Superpowers 자체에 `verification-before-completion` 스킬 내장.
- 💡 **개선**: 신규 SKILL.md 작성 시 Superpowers의 `writing-skills` 스킬로 TDD 적용 권장.

### docs-architect

- ⚠️ **CONCERN**: 양쪽 하네스 설치 명령이 다름 (CC는 `/plugin install`, opencode는 자체 위임).
- **수정 필요**: 두 명령의 동등성/차이 명시 표.

### debugger

- ⚠️ **CONCERN**: playbook-override가 Superpowers 디폴트와 충돌 시 어느 게 이기는지 사용자가 추적하기 어려움.
- **수정 필요**: `priority` 필드 동작 명시 + 충돌 디버깅 명령 (`hermes skill resolve <task>`).

### error-detective

- ⚠️ **CONCERN**: 자동 스킬 로딩 실패 (frontmatter 에러, dependency 누락) 로깅 부재.
- **권장**: Superpowers와 Hermes 둘 다 skill-load 에러 별도 로그.

---

## Phase 9 — oh-my-openagent (omo) + ulw

### architect-reviewer

- ⚠️ **CONCERN**: omo의 agent들 (Sisyphus, Hephaestus, Oracle, Librarian, Explore, Artistry, Prometheus)이 Hermes의 자체 5 pillar와 개념적으로 겹침.
- **명확화 필요**: omo는 **opencode 세션 내부 멀티 에이전트** (단발성), Hermes는 **영구 학습 코어** (영구). 시간축 다름.
- **수정 완료 (v2.1)**: 비교 표 강화.

### code-reviewer

- ⚠️ **CONCERN**: omo의 `budget_guard.enabled: false` 디폴트 → 잘못 트리거되면 토큰 폭주.
- 사용자 정책: "토큰 제약 없음" 이지만 sanity guard는 있어야.
- **권장**: monthly_token_limit 매우 높게 (예: 50M) + 7일 추세 알람.

### test-automator

- ⚠️ **CONCERN**: `ulw hello` 외 검증 시나리오 없음.
- **권장**: 중간 복잡도 시나리오 추가:

  ```
  # opencode 세션에서
  > ulw 이 디렉토리의 Python 파일에 type hints 추가하고 mypy 통과시켜
  
  # 검증:
  # 1. Sisyphus가 plan 생성 (5개 이상 step)
  # 2. Hephaestus가 실제 코드 수정
  # 3. mypy 통과
  # 4. 작업 시간 < 30분
  ```

### docs-architect

- ✅ **PASS**: 사용 패턴 예시 명확.
- 💡 **개선**: `hpp ulw` (adversarial) 트리거 조건 더 자세히.

### debugger

- 🔥 **CRITICAL**: omo의 specialist agent 중 하나가 무한 루프 시 전체 세션 멈춤 가능.
- **수정 필요**: agent별 timeout 설정 + 사용자 abort 패턴 명시.

### error-detective

- ⚠️ **CONCERN**: omo의 plan agent가 잘못된 plan 생성 시 추적 어려움.
- **권장**: opencode TUI에서 plan 시각화 + 사용자가 plan에 거부 가능한 인터랙션.

---

## Phase 10 — Hermes 라우터 SKILL.md

### architect-reviewer

- ✅ **PASS**: 9개 Rule의 우선순위 명확.
- ⚠️ **CONCERN**: Rule 9 (Multi-Step Composition)의 자동 분기 로직이 복잡함. 사용자가 결과 예측 어려울 수 있음.
- **권장**: dry-run 모드 (`[router] explain "..."`) 추가.

### code-reviewer

- ⚠️ **CONCERN**: Rule 1 (명시 prefix `cc>`, `oc>` 등)이 메시지 본문에 그대로 들어가면 prompt injection 위험.
- **권장**: prefix 파싱 후 본문에서 strip + sanitize.

### test-automator

- ✅ **PASS**: 라우팅 결정을 로깅하는 패턴 명시.
- 💡 **개선**: 라우터 자체에 대한 unit test (입력 → 기대 라우팅 결과)를 `scripts/test-router.sh`로.

### docs-architect

- ✅ **PASS**: Rule 1-9 + execution logic + failure modes 모두 cover.

### debugger

- ⚠️ **CONCERN**: `learned-rules.yaml` 자동 학습 시 잘못된 패턴이 영구화될 수 있음.
- **권장**: 학습된 규칙은 7일간 "trial" 상태 → 사용자 명시 승인 후 promotion.

### error-detective

- ✅ **PASS**: `router.log` 형식 명확.
- 💡 **개선**: 로그를 SQLite로 저장하면 시간/패턴별 쿼리 가능.

---

## Phase 11 — Excel/xlsx 스킬

### architect-reviewer

- ✅ **PASS**: openpyxl + pandas 조합 표준.
- ⚠️ **CONCERN**: LibreOffice headless 의존성 → Mac Mini에 추가 설치 부담.
- **대안**: `xlwings` (Excel 직접 호출, macOS 한정) 또는 순수 openpyxl recalc.

### code-reviewer

- ⚠️ **CONCERN**: 세무 시트 작성 시 거래소 CSV의 시크릿 (API key, account number) 의도치 않게 들어갈 가능성.
- **수정 필요**: CSV 입력 시 자동 PII redaction (privacy.redact_pii 와 별개로).

### test-automator

- ⚠️ **CONCERN**: 공식 ZERO-ERROR 강제는 좋지만 실제 검증 명령 없음.
- **권장**: 산출물 검증 스크립트:

  ```python
  from openpyxl import load_workbook
  wb = load_workbook("output.xlsx", data_only=True)
  for sheet in wb.sheetnames:
      for row in wb[sheet].iter_rows(values_only=True):
          for cell in row:
              assert "#" not in str(cell), f"Formula error in {sheet}: {cell}"
  ```

### docs-architect

- ✅ **PASS**: 색상 컨벤션 (파란/검정/녹색) 명확.
- 💡 **개선**: 한국 세무용 시트 템플릿 예시 추가.

### debugger

- ⚠️ **CONCERN**: 대용량 파일 (100MB+) 처리 시 메모리 부족.
- **수정 필요**: read_only 모드 + 청크 처리 가이드 강화.

### error-detective

- ✅ **PASS**: 일반적 에러 케이스 cover.

---

## Phase 12 — Database 스킬

### architect-reviewer

- ✅ **PASS**: Postgres MCP + database-designer + postgres skill + sql-pro 4중 조합 견고.
- ⚠️ **CONCERN**: 4개 도구 간 책임 분리가 사용자에게 모호.
- **수정 필요**: 어떤 작업에 어떤 도구를 쓸지 결정 트리.

### code-reviewer

- 🔥 **CRITICAL**: `POSTGRES_URL` 환경변수에 비밀번호 plaintext.
- **수정 필요**:
  - `.pgpass` 파일 사용 (`~/.pgpass`, 권한 600)
  - 또는 Postgres SSL + cert auth
  - 또는 macOS Keychain integration (`security` CLI)

### test-automator

- ⚠️ **CONCERN**: 쿼리 정확성 검증 부재. AI가 잘못된 쿼리 생성 가능.
- **권장**: EXPLAIN 결과 자동 검증 + dry-run 모드 강제.

### docs-architect

- ⚠️ **CONCERN**: dbt 스킬 섹션이 "커뮤니티 검색 필요"로 끝남.
- **수정 필요**: 명시적 대체 (manual setup 가이드 또는 제거).

### debugger

- ⚠️ **CONCERN**: 마이그레이션 실패 시 롤백 정책 미명시.
- **수정 필요**: 마이그레이션 전 자동 백업 + 실패 시 자동 롤백 스크립트.

### error-detective

- ✅ **PASS**: EXPLAIN 결과를 표준으로 사용.
- 💡 **개선**: 슬로우 쿼리 로깅 활성화 가이드 (`log_min_duration_statement`).

---

## Phase 13 — Reverse Engineering 스킬

### architect-reviewer

- ✅ **PASS**: Ghidra + radare2 + ipsw 표준 RE 툴체인.
- ⚠️ **CONCERN**: 분석 결과물의 저장 위치가 모호 (Ghidra workspace vs vault).

### code-reviewer

- 🔥 **CRITICAL**: 악성 바이너리 분석 시 격리 부재. Mac Mini에 직접 import 시 위험.
- **수정 필요**: Docker 또는 VM 격리 환경 강제. macOS 격리:

  ```bash
  # Docker desktop으로 컨테이너 실행
  docker run -it --rm \
    -v $(pwd)/binary:/sample:ro \
    ghidra/headless analyze /sample
  ```

### test-automator

- ⚠️ **CONCERN**: RE 결과의 정확성 검증 어려움.
- **권장**: cross-tool validation (Ghidra + radare2 결과 비교).

### docs-architect

- ✅ **PASS**: 3개 케이스 (dylib, IPA, smart contract bytecode) 명확.
- 💡 **개선**: 합법성/NDA 경계 가이드 강화.

### debugger

- ⚠️ **CONCERN**: Ghidra headless OOM 외 다른 실패 모드 (corrupt binary, encrypted, packed) cover 부족.
- **수정 필요**: 사전 분석 단계 추가 (`file`, `strings`, packer detect).

### error-detective

- ✅ **PASS**: Ghidra 로그 위치 명시됨.

---

## Phase 14 — 추가 스킬 카탈로그

### architect-reviewer

- ✅ **PASS**: Optional 명시됨.

### code-reviewer

- 💡 **개선**: 각 스킬의 라이센스 명시 권장 (공개 레포 사용 시 필수).

### 기타 에이전트

- ✅ **PASS**: Optional 섹션이라 critical issue 없음.

---

## Phase 15 — Obsidian Vault 통합

### architect-reviewer

- ✅ **PASS**: WebSocket(CC) + HTTP/SSE(Hermes) 듀얼 transport 적절.
- ⚠️ **CONCERN**: 포트 22360 디폴트 — 충돌 시 변경 가이드 부재.

### code-reviewer

- 🔥 **CRITICAL**: vault 내부의 민감 파일 (`01-Tax/`, `02-Wallets/`)이 검색 인덱스에 들어가면 AI가 무의식적으로 참조해 답변에 포함시킬 수 있음.
- **수정 필요**:
  - 별도 vault 분리 (`Obsidian Vault-Public/`, `Obsidian Vault-Private/`)
  - 또는 `.obsidianignore` 활용 (있다면) / Obsidian search exclusion

### test-automator

- ⚠️ **CONCERN**: vault 검색 정확도 검증 부재.
- **권장**: 알려진 노트로 query → expected note ID 비교 테스트.

### docs-architect

- ✅ **PASS**: 옵션 A/B/C 비교 명확.

### debugger

- ⚠️ **CONCERN**: Obsidian 데스크탑 종료 시 MCP 끊김. 모바일 Obsidian만 켜져 있으면 작동 안 함.
- **명시 필요**: "데스크탑 Obsidian이 항상 켜져 있어야 함" → Mac Mini에서 Obsidian launch-on-boot 가이드 추가.

### error-detective

- ⚠️ **CONCERN**: Obsidian MCP 연결 실패 시 로그 위치 모호.
- **권장**: 플러그인 설정에서 verbose logging 활성화 + 위치 명시.

---

## Phase 16 — Paperclip Agent Company

### architect-reviewer

- ✅ **PASS**: Hermes/omo/Mission Control과의 레이어 분리 명확 (시간축 다름).
- ⚠️ **CONCERN**: Paperclip의 board approval workflow와 Hermes의 confirm gate가 중복 가능.
- **명시 필요**: 어느 게이트가 어디서 작동하는지 표.

### code-reviewer

- ⚠️ **CONCERN**: Paperclip Board API Key는 강력한 권한. plaintext 저장 시 위험.
- **수정 필요**: macOS Keychain 사용 + paperclip-mcp가 키 회전 지원하는지 확인.

### test-automator

- 🔥 **CRITICAL**: 실제 회사 정의 후 동작 검증 시나리오 없음 (사용자 결정 영역이라 그렇지만, 최소 smoke test 필요).
- **권장**: `scripts/paperclip-smoke-test.sh` — 더미 회사 생성/routine 트리거/audit log 확인. **(미구현 — 향후 과제. 레포에 아직 없음)**

### docs-architect

- ✅ **PASS**: 의사결정 트리 + 7개 회사 골격 cover.
- 💡 **개선**: Paperclip UI 스크린샷 (회사 생성 화면) 첨부.

### debugger

- ⚠️ **CONCERN**: routine이 안 돌 때 진단 trail 부재 (cron 표현식 / agent stuck / API key 만료 / DB lock).
- **수정 필요**: 분기 진단 스크립트.

### error-detective

- ✅ **PASS**: audit log + Tool-call tracing 내장.
- 💡 **개선**: audit log를 외부 SIEM (예: Loki)에 export하는 가이드.

---

## Phase 17 — 통합 검증

### architect-reviewer

- ✅ **PASS**: 3개 시나리오가 cross-stack 동작 검증.

### code-reviewer

- ✅ **PASS**: Board approval 게이트 활용.

### test-automator

- 🔥 **CRITICAL**: 모든 시나리오가 수동. 자동 E2E test framework 부재.
- **권장**: `scripts/e2e-full-stack.sh` — Telegram bot API + tmux assertion + Postgres state check + vault diff. **(미구현 — 향후 과제. 레포에 아직 없음)**

### docs-architect

- ✅ **PASS**: 시나리오 명확.

### debugger

- ⚠️ **CONCERN**: 시나리오 1 (vault + ulw + paperclip)이 4단계 chain. 어느 단계에서 실패해도 추적 어려움.
- **수정 필요**: 각 단계 종료 후 ack 표시 (#ops 토픽).

### error-detective

- ⚠️ **CONCERN**: 멀티 컴포넌트 협업 시 root cause 추적 어려움.
- **권장**: 분산 tracing (OpenTelemetry style) — 각 요청에 trace_id, 모든 컴포넌트 로그에 trace_id 포함.

---

## 요약 — 발견된 Critical Issues (🔥)

본문 v2 → v2.1 정정 작업으로 반영:

1. **Phase 1 debugger**: device-auth 타임아웃 복구 명령 추가
2. **Phase 3 architect-reviewer**: Hermes 5 pillar 전면 재서술 (이게 가장 큰 정정)
3. **Phase 3 docs-architect**: SOUL/USER/MEMORY 설명 추가 + examples 폴더 추가
4. **Phase 4 code-reviewer**: `TELEGRAM_ALLOWED_CHATS` 추가
5. **Phase 6 code-reviewer**: plist PATH에 Apple Silicon 경로 강제 포함
6. **Phase 6 debugger**: KeepAlive 정밀화
7. **Phase 9 debugger**: omo agent timeout + abort 명시
8. **Phase 12 code-reviewer**: Postgres 자격증명 저장 정책 강화
9. **Phase 13 code-reviewer**: 악성 바이너리 격리 강제
10. **Phase 15 code-reviewer**: vault 민감 폴더 분리 강제
11. **Phase 16 test-automator**: Paperclip smoke test 스크립트 (미구현 — 향후 과제)
12. **Phase 17 test-automator**: E2E test framework (미구현 — 향후 과제. `scripts/verify-phase7.sh`만 우선 반영)

## 발견된 주요 Concerns (⚠️) — 차후 개선

1. 멀티 머신 동기화 정책 미명시 (Phase 1)
2. 디바이스별 토큰 회전 가이드 없음 (Phase 1, 4)
3. 로그 로테이션 정책 부재 (Phase 6)
4. STT confidence < 0.7 처리 (Phase 7)
5. 자동 학습 규칙의 검토 정책 (Phase 10)
6. RE 결과 cross-tool validation (Phase 13)
7. 멀티 컴포넌트 분산 tracing (Phase 17)

## 개선 우선순위 (Top 5)

1. **Hermes 5 pillar 재서술** ✅ 완료 (v2.1)
2. **Telegram 봇 보안 강화** (`allowed_chats`)
3. **자격증명 통합 관리** (모든 시크릿을 Keychain으로)
4. **자동 헬스체크 + 알람** (Phase 6 + cron)
5. **E2E 테스트 스크립트** (Phase 7, 17)

반영 상태:

- **1~4번 반영됨** — v2.1 본문 + `scripts/` 폴더 (예: `scripts/healthcheck.sh`, allowed_chats/Keychain 패턴은 PLAYBOOK 본문)
- **5번은 부분 반영** — Phase 7 자동 검증(`scripts/verify-phase7.sh`)과 라우터 테스트(`scripts/test-router.sh`)는 있으나, `scripts/paperclip-smoke-test.sh` / `scripts/e2e-full-stack.sh`는 **미구현 (향후 과제)**

---

## Multi-Agent 검증의 본질적 발견

여러 에이전트가 다른 관점에서 동시에 본 결과:

- **architect-reviewer**: "시스템이 학습할수록 복잡해지는데 사용자가 모든 학습을 추적하기 어렵다" → Hermes의 self-improving이 양날의 검
- **code-reviewer**: "시크릿이 너무 많은 위치에 분산되어 있다" → 단일 시크릿 관리 (Keychain) 필요
- **test-automator**: "전체적으로 자동화된 검증 부재" → CI/CD 부재
- **docs-architect**: "문서가 사용자의 cognitive load를 충분히 고려하지 않음" → 점진적 진입 가이드 필요
- **debugger**: "실패 시 사용자가 어디로 가야 할지 모르는 케이스가 많다" → 분기 진단 가이드 필요
- **error-detective**: "관측성(observability)이 불균질" → 통일된 logging/tracing 표준 필요

이 6가지 메타 발견은 향후 v3 방향성으로 권장.
