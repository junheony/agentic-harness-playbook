# Changelog

All notable changes to this project are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
Versioning: [SemVer](https://semver.org/) — MAJOR.MINOR.PATCH

본 레포는 reference architecture. 버전은 외부 검토 / 외부 사용자 셋업 성공 사례가 누적되면 정식 태깅 예정.

## [Unreleased]

### Fixed — 외부 감사 후속 (2026-07)

2026-07 외부 감사 라운드에서 확인된 이슈 일괄 수정:

- **Linux secret-tool 통일** — 저장/조회 속성을 `service hermes account <secret-name>`으로 전 문서·스크립트 canonical화 (예: `secret-tool lookup service hermes account telegram-bot-token`). macOS는 기존 Keychain 패턴 유지.
- **CI 5종 녹색화** — shellcheck / markdownlint / link-check / install-smoke / router-tests 워크플로 전부 통과하도록 스크립트·문서 정리 + `hygiene-scan.yml` (개인정보 유출 게이트) 추가.
- **mini-router 견고화** — `bot.py` 방어 로직 보강 + `mini-router/tests/` unit test + `requirements.txt` (pinned) 추가. macOS launchd 예시 (`com.user.mini-router.plist.example`) 동봉.
- **개인정보 스크럽** — 실제 호스트명/프로젝트명/경로를 placeholder로 치환하고, 개인 오버레이 파일(`.omx/`, 개인 topic-map 등)을 `.gitignore` personal overlay 블록으로 차단. hygiene gate가 재유입 방지.
- **레포 메타 정비** — LICENSE 저작권자 기입 (2026 junheony), `SECURITY.md` (GHSA 비공개 제보), `CODE_OF_CONDUCT.md` (Contributor Covenant 2.1 요약), `.github/` issue/PR 템플릿 + dependabot 추가.
- **README 정합화** — clone URL 실제 레포 (`junheony/agentic-harness-playbook`)로, 폴더 트리 실물과 일치, 셋업 소요시간 단일 프레이밍 (자동 설치 ~80분 / 숙련 ~4시간 + 4주), OAuth off-policy 스탠스 모순 제거 (기본 OFF opt-in으로 일원화), CI 배지 5종, mini-router 진입 문서 링크, 한 줄 데모에 정직한 제약 주석 (보이스=Hermes 필요, mini-router는 v1 텍스트 전용 + 회신 미구현).
- **문서 앵커/링크 수정** — 깨진 상대 링크·앵커 정리, `docs/00-index.md` 인덱스 + `examples/README.md` 추가.
- **`scripts/restore-backup.sh` 추가** — `backup.sh` 산출물 복원 경로 제공 (백업만 있고 복원 스크립트가 없던 공백 해소).

### Added — new-project-bootstrap: Phase 0 Infra Bootstrap

- **`skills/new-project-bootstrap/SKILL.md` — Phase 0 추가** — Phase A 진입 전에 인프라 셋업 단계 삽입. GitHub repo 생성 (`gh repo create <github-user>/<slug> --private`), 양쪽 머신 clone (Linux SSH + Mac 로컬), Telegram 토픽 안내 + `topic-discover.sh` 연동, `topic_map.yaml` 업데이트, 초기 commit (`.gitignore` + `README.md`) 순서로 진행. 옵트아웃(`--skip-infra`, "로컬 only") 및 부분 실행(`--skip-clone-linux` 등) 지원. 워크플로 설명을 4-phase → 5-phase로 갱신.
- **`scripts/new-project-bootstrap-infra.sh` 신규** — Phase 0 스텝 0-1~0-5를 한 명령으로 자동화. `gh repo create`, SSH clone, `.gitignore` 범용 템플릿 생성, 초기 commit+push, Telegram 토픽 안내 출력. idempotent (이미 존재하는 repo/클론 skip). `bash -n` 문법 검사 통과.

### Added — install-all.sh 전면 리팩터 (Ubuntu/Debian 서버 zero-config 지원)

- **Phase 0 추가** — OS 의존성 자동 설치: Ubuntu/Debian `apt-get` (NodeSource PPA로 Node 20 보장, `libsecret-tools`, `age`, `pass`, `jq`, `tmux`, `python3-venv` 등) + macOS `brew`. `corepack`으로 `pnpm` 설치 (sudo 불필요). `uv`/`uvx` 설치 (`astral.sh` fetch→inspect→bash 패턴).
- **Phase 4b 추가 (mini-router)** — Python venv 자동 생성 (`mini-router/.venv`) + `python-telegram-bot==21.*` + `pyyaml` pip 설치. Linux: `mini-router.service.example` → `~/.config/systemd/user/mini-router.service` 자동 배포 (`YOUR_USERNAME` sed 치환). Hermes gateway가 active이면 충돌 회피 skip.
- **Phase 6b 추가 (omo_proxy, OFF-POLICY)** — `--enable-claude-proxy` 또는 `ENABLE_CLAUDE_PROXY=1` opt-in 시에만 활성. `winglock/omo_proxy` 클론 + `omo-proxy.service.example` 자동 배포 + `~/.claude/.credentials.json` 이전 안내. 기본 OFF.
- **PATH 보강** — 스크립트 최상단에서 `~/.local/bin:~/.opencode/bin:~/.npm-global/bin:~/.cargo/bin:/opt/homebrew/bin` 명시적 export. SSH non-interactive 환경에서 "이미 설치됨" early-return이 올바르게 작동.
- **Codex CLI Linux 설치 개선** — `npm prefix` → `~/.npm-global` 설정으로 sudo 없이 전역 설치.
- **Phase 7 개선** — `verify-phase7.sh --quick` 자동 호출 (스크립트 위치 자동 감지).
- **`--enable-claude-proxy` 옵션 추가** — OFF-POLICY omo_proxy 배포 opt-in 플래그.
- **Idempotency 강화** — 모든 설치 명령에 "이미 있음" early-return (`command -v`, 파일/디렉토리 존재 체크).
- **Phase 매핑 갱신** — `--help` 및 스크립트 헤더에 Phase 0~7 + 4b + 6b 전체 매핑 명시.
- **systemd linger 상태 체크** — Phase 6 Linux에서 `loginctl show-user` 로 이미 활성화됐는지 확인 후 skip.

### Changed — install-all.sh

- **START_PHASE 기본값 0으로 변경** — 기존 1 → 0 (Phase 0이 추가됐으므로).
- **ONLY_PHASE 기본값 빈 문자열로 변경** — 기존 `0` (not set sentinel) → `""`. `--only-phase=0`이 이제 Phase 0만 실행함.
- **README 빠른 시작** — Phase 매핑 표 추가, 사전 준비 단순화 (git+curl만 있으면 나머지는 Phase 0이 설치), `--enable-claude-proxy` 옵션 명시.
- **README 폴더 트리** — `mini-router.service.example`, `omo-proxy.service.example`, `agent-registry.example.yaml` 항목 추가.

### Added — Agent instrumentation (역할 / 할당 가시화)

- **`examples/configs/agent-registry.example.yaml`** — 정적 agent 카탈로그. omo 7 specialists (Sisyphus / Hephaestus / Oracle / Librarian / Explore / Artistry / Adversary) + Claude Code 6 subagents + Hermes self. 각 agent의 role / icon / 모델 / trigger / 호출 관계 + task_routing 매트릭스
- **`scripts/agents-state.sh`** — 동적 collector. JSONL 훅 데이터 (1순위) + opencode log 파싱 (best-effort fallback) + router log → `~/.hermes/agents-state.json`. bash 3.2 호환 (jq group-by 사용). ACTIVE_WINDOW_MIN으로 stale agent 자동 cull
- **`examples/hooks/cc-subagent-trace.sh`** + **`claude-settings-snippet.example.json`** — Claude Code PreToolUse/SubagentStop/PostToolUse 훅으로 subagent lifecycle (start/stop/fail) 자동 캡처
- **`docs/09-agent-instrumentation.md`** — 정적 registry + 동적 state 데이터 흐름 + 훅 설치 가이드 + 칸반 표시 방식
- **`scripts/dashboard-tick.sh`** — agents-state → canvas + markdown 통합 wrapper (launchd/systemd가 호출)

### Changed — Canvas + markdown dashboard에 agent 정보 통합

- **`scripts/canvas-render.sh`**: 각 tmux 세션 카드에 inline "Active roles" 추가 + In Progress 컬럼 상단에 종합 "Agent Roster" 카드 (harness별 그룹핑, task 일부 표기)
- **`scripts/dashboard-render.sh`**: 새 섹션 "🤖 Active Agents" 추가 (harness별 그룹 + task)
- **`examples/configs/dashboard-render.plist.example`** / **`.service.example`**: ExecStart를 `dashboard-tick.sh`로 (개별 호출 X)

### Added — 연속 운영 시스템 + 부트스트랩 + 대시보드

- **`skills/new-project-bootstrap/`** — DDD + Clean Architecture를 강제하는 4-phase 부트스트랩 스킬 (Discovery → DDD → Skeleton → Walking Skeleton). 라우터에 트리거 추가
- **`examples/paperclip-companies/quant-research-action-loop.example.md`** — 매일 ingest → review → approval → execute → rollup 5-routine 회사 정의. state machine + 실패 모드 + 보안 게이트 명시
- **`scripts/dashboard-render.sh`** — 1분마다 vault `00-Mission-Control/dashboard.md` 마크다운 롤업
- **`scripts/canvas-render.sh`** — Obsidian Canvas 라이브 칸반 대시보드. **4-컬럼** (Pending / In Progress / Blocked / Done Today). 카드가 실제 상태에 따라 컬럼 사이를 이동 (예: routine이 running→done 되면 컬럼 이동). deterministic node id로 위치 안정. 색상 코드: red=approval needed, cyan=in progress, yellow=blocked, green=done. 카드 type=file은 Obsidian에서 직접 드릴다운.
- **`scripts/tmux-overview.sh`** — TUI session aggregator (idle 색상 코드)
- **`scripts/hermes-feedback.sh`** — 사이클 회고를 Hermes Memory Feedback Loop에 append + 80% 자동 consolidate trigger
- **`docs/08-memory-feedback-pattern.md`** — 자기 개선 사이클 패턴 문서
- **`examples/configs/dashboard-render.{plist,service,timer}.example`** — macOS + Linux 60초 trigger 예시

### Changed — Linux server 1급 지원

- **`scripts/install-all.sh`**: Phase 6 Linux systemd 분기 추가 (`loginctl enable-linger`, user unit, `systemctl --user enable`, sleep mask). Phase 4 시크릿 저장에 `secret-tool` → `pass` → `.env` fallback 추상화
- **`scripts/healthcheck.sh`**: Linux 서비스 체크 + Tailscale 확인 강화
- **`docs/02-architecture.md`**: 보안 모델에 Linux 시크릿 옵션 (secret-tool / pass / age) 명시
- **`docs/01-overview.md`, `playbook/PLAYBOOK.md`**: "Mac Mini" → "워크호스 서버 (Mac Mini 또는 Linux)" 일반화. Phase 6에 Linux systemd unit 예시 추가
- **`README.md`**: 사전 준비/빠른 시작을 macOS/Linux 양립으로
- **`skills/router/SKILL.md`**: 신규 프로젝트 / 대시보드 키워드 트리거 추가

### Changed — 공개 준비 (P0 fixes)

- **모델명 placeholder화**: `${MODEL_LARGE}` / `${MODEL_BALANCED}` / `${MODEL_SMALL}` 패턴으로 통일 — 사용자가 자기 환경의 실제 모델 ID로 직접 치환
- **개인정보 익명화**: 실명 / 실제 프로젝트명 / 호스트명 → placeholder (`<USER_NAME>`, `<project-a>` 등)
- **6-agent verification 재프레이밍**: "Verified" badge → "Self-reviewed (6-perspective audit)". 외부 독립 검토가 아님을 명시
- **외부 URL 검증**: 깨진 링크 제거, `curl|bash` 직행 패턴을 fetch→inspect→run 패턴으로 변경
- **install-all.sh 결함 수정**:
  - `--phase=N` 방향 버그 → `--start-phase=N` / `--only-phase=N` 분리 (의도 명확화)
  - 시크릿 입력을 `read -rsp` (무에코)로
  - `eval` 제거 (명령 주입 방지)
  - `--dry-run` 진짜 완전 short-circuit (이전엔 절반만 작동)
  - macOS Keychain 1순위 + .env fallback 강제
  - 하드코딩 `/Volumes/dev/_tools` 제거 → `WORKDIR_ROOT` 환경변수
- **healthcheck.sh / backup.sh 크로스 플랫폼화**: `stat -f`/`stat -c` 분기, Linux fallback 경로 명시
- **opencode permission 디폴트**: `bash.allow: ["*"]` → 화이트리스트 (CI 안전)
- **CI workflows 추가**: shellcheck, markdownlint, link checker
- **stub 테스트 스크립트 추가**: `verify-phase7.sh`, `test-router.sh` (TODO 명시)

### Planned for v3

- Korean Crypto Tax SKILL.md full version (한국 가상자산 세무 자동화)
- Mission Control v2 (Paperclip 회사들과 통합 콘솔)
- Hermes 자동 스킬 promotion workflow (trial → promote)
- 분산 tracing (OpenTelemetry style, cross-component trace_id)
- 멀티 머신 동기화 (MBP ↔ Mac Mini ↔ Linux devserver)
- 영어 README 병기

---

## Pre-release iterations

### v2.1 (self-review draft, 2026-05)

self-review (6-perspective audit) 반영:

- **Phase 3 Hermes**: 단순 게이트웨이 설명에서 **5 pillar self-improving AI core** 로 전면 재서술
  - Soul/Memory/User/Skills/Crons 5개 컴포넌트 풀어서 설명
  - 메모리 동작 메커니즘 (frozen snapshot, consolidation at 80%) 문서화
  - Skill auto-creation/improvement loop 동작 명시
- **Phase 4 Telegram**: `TELEGRAM_ALLOWED_CHATS` 화이트리스트 추가 (allowed_users만으론 부족)
- **Phase 6 launchd**: Apple Silicon PATH 우선순위 정정, KeepAlive 정밀화
- **Phase 9 omo**: agent별 timeout + abort_on_repeated_failures + sanity 알람
- **Phase 12 Postgres**: `.pgpass` 또는 macOS Keychain 강제
- **Phase 13 RE**: Docker 격리 강제
- **Phase 15 Obsidian**: 3-vault 분리 (Public/Private/Work) + privacy.exclude_paths

Added:

- `docs/05-verification-report.md` — self-review 보고서
- `examples/soul/{SOUL,USER,MEMORY}.example.md` — 5 pillar 템플릿
- `scripts/install-all.sh`, `scripts/healthcheck.sh`, `scripts/backup.sh`
- `.gitignore` — 시크릿/PII leak 방지

### v2.0 (이전 reference draft) (날짜 미기록 — 태깅 전 이력)

- Phase 15: Obsidian Vault 통합
- Phase 16: Paperclip Agent Company 인프라
- Phase 17: 통합 검증 시나리오 3개
- Daydream 스킬 (cross-note connection mining)
- Paperclip companies 의사결정 트리
- 레이어 스택 7단계로 확장 (L0~L4)
- 라우터 룰 9개로 정리

### v1.0 (초기 draft) (날짜 미기록 — 태깅 전 이력)

- Phase 1~14 기본 인프라
- Claude Code (Anthropic) + opencode (Codex) 듀얼 하네스
- Hermes 게이트웨이 (메모리/메시징 레벨만)
- Telegram Forum Topics 기반 모바일 진입점
- Superpowers 메서돌로지
- omo `ulw` 멀티 에이전트 폭발 모드
- 도메인 스킬: xlsx, postgres, ghidra, ios-reverse-engineering
