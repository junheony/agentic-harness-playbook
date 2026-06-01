# 📱 Agentic Harness — Mobile-First AI Coding Stack

> 폰 하나로 멀티 프로젝트 agentic coding을 굴리는 통합 인프라.  
> Mac Mini 또는 Linux 서버가 24/7 워크호스, Telegram이 컨트롤 룸.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Playbook: 2,400+ lines](https://img.shields.io/badge/Playbook-2%2C400%2B%20lines-blue)](playbook/PLAYBOOK.md)
[![Self-reviewed: 6-perspective audit](https://img.shields.io/badge/Self--reviewed-6--perspective%20audit-yellow)](docs/05-verification-report.md)
[![Korean](https://img.shields.io/badge/Lang-한국어-orange)](README.md)

[![shellcheck](https://github.com/junheony/agentic-harness-playbook/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/junheony/agentic-harness-playbook/actions/workflows/shellcheck.yml)
[![markdownlint](https://github.com/junheony/agentic-harness-playbook/actions/workflows/markdownlint.yml/badge.svg)](https://github.com/junheony/agentic-harness-playbook/actions/workflows/markdownlint.yml)
[![link-check](https://github.com/junheony/agentic-harness-playbook/actions/workflows/link-check.yml/badge.svg)](https://github.com/junheony/agentic-harness-playbook/actions/workflows/link-check.yml)
[![install-smoke](https://github.com/junheony/agentic-harness-playbook/actions/workflows/install-smoke.yml/badge.svg)](https://github.com/junheony/agentic-harness-playbook/actions/workflows/install-smoke.yml)
[![router-tests](https://github.com/junheony/agentic-harness-playbook/actions/workflows/router-tests.yml/badge.svg)](https://github.com/junheony/agentic-harness-playbook/actions/workflows/router-tests.yml)

---

## 무엇이고 누구를 위한 건가

**무엇**: iPhone Telegram → 워크호스 서버(Mac Mini 또는 Linux)의 Claude Code + opencode + Hermes + Paperclip → Obsidian vault를 하나의 일관된 흐름으로 묶는 reference architecture. 모든 인프라가 self-hosted, 기본 구성은 모든 OAuth가 공식 채널 (off-policy 경로는 명시적 opt-in).

**누구를 위해**:

- 멀티 프로젝트를 동시에 굴리는 인디 개발자 / KOL / quant trader
- 폰에서 보이스로 "ulw 이 모듈 가스 최적화" 같은 명령을 내리고 백그라운드에서 작업이 완성되길 원하는 사람
- Claude Code는 좋지만 폰에서 답답하다고 느낀 사람
- Cursor + Linear + Slack 조합이 무겁다고 느낀 사람
- 본인의 도구를 본인이 통제하고 싶은 사람

**무엇이 아닌가**:

- SaaS도 아니고, 회원가입도 없고, 클라우드 종속도 없음
- 누구나 1분 안에 셋업되는 toy도 아님 — 자동 설치(Phase 0~7) 약 80분, 전체 스택 숙련까지 ~4시간 + 4주 점진
- "AGI" 같은 거 약속 안 함. 그냥 잘 짜인 인프라

---

## 한 줄 데모

```text
[iPhone Telegram #<your-project> 토픽 → 보이스 노트]
"이 모듈 가스 최적화 + EIP-7702 호환 검증해줘"

         ↓ (Hermes STT → 라우터 → opencode + omo)

[Mac Mini tmux]
Sisyphus 활성화 → 병렬 specialist 디스패치
Hephaestus (구현) + Oracle (감사) + Librarian (EIP spec) + ...

         ↓ (n분 후)

[Telegram #<your-project> 토픽]
✅ 가스 X% 절감 (실제 수치는 workload 의존), EIP-7702 호환 검증, 테스트 결과 N/M pass
PR 준비됨. vault에 분석 노트 저장.
```

> 위 데모는 워크플로의 한 예. 실제 절감률/소요시간/테스트 통과율은 코드/모델/환경에 따라 다름.
>
> **정직한 주의**: 위의 **보이스 경로(STT)는 Hermes가 있어야** 동작함. Hermes 없이 쓰는 fallback인 [mini-router](mini-router/README.md)는 **v1 기준 텍스트 전용**이고, 작업 결과를 Telegram으로 되돌려주는 회신 기능은 아직 미구현 — 결과는 `ssh` + `tmux attach`로 직접 확인해야 함.

---

## 핵심 아키텍처

7-레이어 스택, 각각 다른 시간축에서 다른 일을 함.

```text
┌─────────────────────────────────────────────────────────────────┐
│ L4  진입점          : iPhone Telegram Topics / SSH               │
│ L3  학습/메모리/    : Hermes 5 Pillar Core                       │
│     메시징            (Soul/Memory/User/Skills/Crons + Gateway)  │
│ L3' 지식베이스      : Obsidian Vault (CC + Daydream)             │
│ L3" 장기 자율운영   : Paperclip Companies (routines + board)     │
│ L2  오케스트레이션  : CC native subagents | omo ulw              │
│ L1  하네스          : Claude Code (Anthropic) ⊕ opencode (Codex) │
│ L0  메서돌로지/스킬 : Superpowers + 도메인 (xlsx/db/RE/vault)    │
└─────────────────────────────────────────────────────────────────┘
```

| 도구             | 시간축          | 역할                                             |
|------------------|-----------------|--------------------------------------------------|
| **Hermes**       | 영구 (다년)     | 너에 대해 학습하는 AI 코어 (Soul/Memory/Skills/Crons) |
| **Claude Code**  | 세션 (시간)     | 본진 코딩 하네스 (Anthropic 모델)                |
| **opencode**     | 세션 (시간)     | 확장 트랙 (Codex OAuth, multi-provider)          |
| **omo `ulw`**    | 작업 (분~시간)  | opencode 안의 멀티 에이전트 폭발 모드            |
| **Paperclip**    | 영구            | cron 기반 자율 회사 (routine + board approval)   |
| **Obsidian**     | 영구            | 지식베이스 (cross-link mining via Daydream)      |

자세한 구성: [`docs/02-architecture.md`](docs/02-architecture.md)

### 모델 배치 (주축 2 + 용도별)

라우터(Rule 0)가 의도를 분석해 작업별로 모델을 자동 선택. 사용자가 명시하면(`opus로`, `haiku로 빠르게`) override.

| 용도                          | 모델              | 위치                                  |
|-------------------------------|-------------------|---------------------------------------|
| 도구 실행·대화·라우팅 (상시)  | **gpt-5.5**       | Hermes 본체 (tool_use 안정)           |
| 깊은 구현·리뷰·계획 (deep)    | **Opus 4.8** (fallback 4.7) | omo sisyphus·oracle·prometheus·momus  |
| 균형 (중간 복잡도)            | Sonnet 4.6        | omo metis·atlas·sisyphus-junior       |
| 빠른 탐색·대량 조회           | Haiku 4.5         | omo explore·quick                     |
| 멀티모달 (이미지)             | gpt-5-nano        | omo multimodal-looker                 |

> 모델 ID는 본인 구독/환경에 맞게 교체. 위는 운영 중인 배치 예시.

---

## OAuth 정책 (반드시 지킬 것)

- **Anthropic OAuth (Claude Pro/Max)** → 기본 구성에서는 Claude Code 안에서만. 3rd-party 도구에 꽂으면 ToS 위반 + 정지 위험 (2026-04 발효, 출처: The Register / VentureBeat 보도).
- **OpenAI Codex OAuth (ChatGPT Plus/Pro)** → opencode + Hermes 사용은 현재 **grey area**. OpenAI device-auth는 공식 지원이지만 3rd-party CLI 도구에서의 재사용은 명시적 sanction 받은 상태 아님. Anthropic이 2026-04에 동일 패턴을 차단한 사례 있음. 실제 차단이 일어나면 즉시 API 키 폴백.
- **off-policy 우회 (omo_proxy)** → 이 레포는 권장하지 않지만, 위험 고지와 함께 **기본 OFF, 명시적 opt-in** (`--enable-claude-proxy`)으로 문서화해 동봉함 ([`docs/10-claude-oauth-proxy.md`](docs/10-claude-oauth-proxy.md)). 사용 시 계정 정지 위험은 **전액 본인 부담**이며, 문제 발생 시 즉시 API 키 폴백으로 전환할 것.
- 의심 시 API 키 폴백 (`OPENAI_API_KEY` / `ANTHROPIC_API_KEY` 환경변수).

이게 이 레포의 가장 중요한 제약. 기본 구성의 모든 설계가 이걸 지키도록 짜여있고, off-policy 경로는 켜지 않는 한 어떤 Phase에서도 활성화되지 않음.

---

## 첫 5분 (최소 viable 검증)

전체 셋업 전에 "Codex OAuth + opencode 트랙 하나만 살아있는가" 빠르게 확인:

```bash
# 1. Codex CLI
npm i -g @openai/codex
codex login --device-auth      # 폰에서 코드 입력
codex login status              # exit 0 이면 OK

# 2. opencode (안전 패턴)
curl -fsSL https://opencode.ai/install -o /tmp/opencode-install.sh
less /tmp/opencode-install.sh   # 내용 확인
bash /tmp/opencode-install.sh

# 3. round-trip
echo "hello" | codex exec "echo this back"
opencode --version
```

세 단계가 통과하면 Codex OAuth 트랙은 살아있음. 나머지(Telegram / Hermes / Paperclip / Obsidian)는 점진 추가.

---

## 빠른 시작 (Mac Mini 또는 Linux 서버 권장 — 자동 설치 Phase 0~7 약 80분)

### 0. 사전 준비

- **macOS** (Apple Silicon 권장) 또는 **Linux 서버** (Ubuntu 24.04+ / Debian 12+ 권장)
  - macOS: `pmset` + `launchd` + Keychain 기본 지원
  - Linux: `systemd` user unit + `secret-tool` (libsecret) / `pass` / `.env` fallback 사용
- iPhone with Telegram
- ChatGPT Plus/Pro 구독 + Claude Pro/Max 구독
- Tailscale (외부 SSH 안전 진입용, 무료 — macOS/Linux 둘 다 지원)
- git + curl (나머지 의존성은 Phase 0에서 자동 설치: Node 20 / pnpm / uv / tmux / jq / python3 등)
- Termius (옵션, 모바일 SSH 클라이언트)

> **Phase 6 (상시 가동)**: macOS는 `launchd` plist, Linux는 `systemd` user unit으로 자동 구성 (`loginctl enable-linger` 포함). 자세한 가이드는 `playbook/PLAYBOOK.md §7` 참조.

### 1. Phase 0~7 — 인프라 베이스

```bash
git clone https://github.com/junheony/agentic-harness-playbook.git
cd agentic-harness-playbook

# 자동 설치 스크립트 (대화형, 안전)
./scripts/install-all.sh                       # Phase 0부터 전체
./scripts/install-all.sh --dry-run             # 명령만 출력 (실행 X)
./scripts/install-all.sh --only-phase=0        # OS 의존성만 (Node/pnpm/uv)
./scripts/install-all.sh --start-phase=3       # Phase 3부터
./scripts/install-all.sh --only-phase=4        # Phase 4만
./scripts/install-all.sh --enable-claude-proxy # Phase 6b: omo_proxy (OFF-POLICY)
```

**Phase 매핑**:

| Phase | 내용 |
|-------|------|
| 0 | OS 의존성 (apt/brew) + Node 20 + pnpm + uv |
| 1 | Codex OAuth |
| 2 | opencode |
| 3 | Hermes (감지 + 활용 / 없으면 skip) |
| 4 | Telegram bot + secret |
| 4b | [mini-router](mini-router/README.md) (Hermes 없거나 사용자 명시 시 — Hermes 없이 시작한다면 이 문서가 실전 진입점) |
| 5 | Claude Code MCP (조건부) |
| 6 | systemd 상시 가동 + linger (Linux) / launchd (macOS) |
| 6b | omo_proxy (--enable-claude-proxy 명시 시, OFF-POLICY) |
| 7 | verify-phase7.sh 자동 호출 |

수동으로 따라가고 싶다면: [`docs/03-execution-phase1-7.md`](docs/03-execution-phase1-7.md) (단계별 명령, 예상 출력, 트러블슈팅 포함)

### 2. Phase 8~17 — 메서돌로지 + 도메인 스킬

[`docs/04-execution-phase8-17.md`](docs/04-execution-phase8-17.md) 가 PLAYBOOK 해당 섹션으로 라우팅함. 4주 진행 권장.

### 3. 검증

```bash
./scripts/healthcheck.sh            # 컴포넌트 상태
./scripts/verify-phase7.sh          # Phase 1~7 round-trip 검증
./scripts/test-router.sh            # 라우터 룰 unit test
```

모든 컴포넌트의 상태를 출력. 폰의 `#ops` 토픽에 자동 알람 설정 가능 (`ALERT_ON_FAILURE=true`).

---

## 폴더 구조

```text
.
├── README.md                      ← 지금 보는 파일
├── LICENSE                        ← MIT
├── CONTRIBUTING.md                ← 기여 가이드
├── CHANGELOG.md
├── SECURITY.md                    ← 취약점 제보 정책 (GitHub Security Advisories)
├── CODE_OF_CONDUCT.md             ← 행동 강령 (Contributor Covenant 2.1 요약)
├── .gitignore
├── .markdownlint.json             ← markdownlint 규칙 (CI와 동일)
│
├── playbook/
│   └── PLAYBOOK.md                ← 메인 가이드 (2,400+ 줄)
│
├── docs/
│   ├── 00-index.md                ← 문서 전체 인덱스
│   ├── 01-overview.md             ← 한 페이지 요약
│   ├── 02-architecture.md         ← 레이어 + Hermes 5 pillar 디테일
│   ├── 03-execution-phase1-7.md   ← 인프라 셋업 단계별
│   ├── 04-execution-phase8-17.md  ← PLAYBOOK §9-18로 라우팅 (stub)
│   ├── 05-verification-report.md  ← 6-perspective self-review 결과
│   ├── 06-troubleshooting.md      ← 트러블슈팅 모음
│   ├── 07-faq.md                  ← 자주 묻는 질문
│   ├── 08-memory-feedback-pattern.md   ← Hermes MEMORY 자기개선 루프
│   ├── 09-agent-instrumentation.md     ← subagent 추적 + 상태 수집
│   ├── 10-claude-oauth-proxy.md        ← omo_proxy (⚠️ OFF-POLICY, 본인 책임)
│   ├── 11-mac-linux-sync-git.md        ← Mac↔Linux git-centric 동기화
│   ├── 12-agent-push-automation.md     ← agent/<task> 브랜치 자동 커밋·푸시
│   ├── 13-mission-control-operations.md← 대시보드 운영 (Hermes 네이티브 9119)
│   ├── 14-mobile-vault-sync.md         ← 폰 ↔ Obsidian vault 동기화
│   ├── 15-obsidian-vault-integration.md← vault-mirror 단방향 read
│   ├── 16-obsidian-rest-api-write.md   ← agent vault write (Local REST API)
│   └── 17-external-workflow-delegation.md ← 외부 워크플로우 엔진 호출 매핑
│
├── mini-router/                   ← Hermes 없이 쓰는 Telegram→tmux 폴백 라우터
│   ├── README.md                  ← mini-router 단독 셋업 가이드 (실전 진입 문서)
│   ├── bot.py                     ← 봇 본체 (python-telegram-bot, v1 텍스트 전용)
│   ├── env.example                ← 환경변수 템플릿
│   ├── requirements.txt           ← pinned 의존성
│   └── tests/                     ← bot.py unit tests
│
├── skills/                        ← 로컬 배포용 SKILL.md들
│   ├── playbook-override/         ← 응답 스타일 규약 (6-7 step, 신뢰도 태깅, ToT)
│   ├── router/                    ← Hermes 라우터 (agentic-router, Rule 0 맥락 자동매핑)
│   ├── new-project-bootstrap/     ← 신규 프로젝트 5단계 (Phase 0 + DDD + Clean Arch)
│   ├── auto-commit-push/          ← agent 작업 자동 커밋·푸시
│   ├── daydream/                  ← cross-note connection mining
│   └── agentic-harness-playbook/  ← 메타 스킬 (loader)
│
├── examples/
│   ├── README.md                  ← examples 디렉토리 안내
│   ├── soul/
│   │   ├── SOUL.example.md        ← Hermes 페르소나 예시
│   │   ├── USER.example.md        ← 사용자 프로필 예시
│   │   └── MEMORY.example.md      ← 환경 메모리 예시
│   ├── configs/
│   │   ├── hermes-config.example.yaml
│   │   ├── opencode.example.jsonc
│   │   ├── oh-my-openagent.example.jsonc     ← 모델 매핑 (gpt-5.5 + Opus 4.8 주축)
│   │   ├── topic-map.example.yaml
│   │   ├── agent-registry.example.yaml
│   │   ├── hermes-gateway.override.conf.example ← systemd drop-in (update 후에도 생존)
│   │   ├── hermes-dashboard.service.example  ← Hermes 네이티브 대시보드 (localhost:9119)
│   │   ├── mini-router.service.example       ← systemd user unit (Linux, mini-router)
│   │   ├── com.user.mini-router.plist.example ← launchd (macOS, mini-router)
│   │   ├── omo-proxy.service.example         ← systemd user unit (Linux, omo_proxy OFF-POLICY)
│   │   ├── hermes-daily-rollup.{service,timer}.example ← 일일 메모리 롤업
│   │   ├── quant-{ingest,rollup}.{service,timer}.example ← 리서치-액션 루프 cron
│   │   ├── dashboard-render.{plist,service,timer}.example ← 대시보드 렌더 트리거
│   │   ├── dashboard-tick.{service,timer}.example ← (deprecated, Hermes 네이티브로 대체)
│   │   └── com.user.*.plist.example          ← launchd (macOS: creds/vault/dashboard sync)
│   ├── hooks/
│   │   ├── cc-subagent-trace.sh              ← Claude Code subagent lifecycle 훅
│   │   └── claude-settings-snippet.example.json ← 훅 등록 settings 스니펫
│   ├── routines/
│   │   └── quant-{ingest,rollup}.sh.example  ← Paperclip routine 예시
│   └── paperclip-companies/       ← 회사 정의 예시 (Tier 1)
│
├── scripts/
│   ├── install-all.sh             ← Phase 0~7 + 4b + 6b 자동 설치 (--dry-run / --start-phase / --only-phase / --enable-claude-proxy)
│   ├── healthcheck.sh             ← 전체 컴포넌트 상태 점검
│   ├── verify-phase7.sh           ← Phase 1~7 round-trip 검증
│   ├── test-router.sh             ← 라우터 룰 unit test
│   ├── test_cases.txt             ← test-router.sh 케이스 정의
│   ├── backup.sh                  ← 일일 백업 + 5 pillar age/gpg 암호화
│   ├── restore-backup.sh          ← backup.sh 산출물 복원
│   ├── new-project-bootstrap-infra.sh ← GitHub repo + 토픽 + 서버 clone 일괄
│   ├── agent-commit-push.sh       ← agent/<task>-<ts> 브랜치 커밋·푸시
│   ├── hermes-feedback.sh         ← MEMORY.md Feedback Loop 한 줄 retro
│   ├── hermes-daily-rollup.sh     ← 일일 세션 요약 롤업
│   ├── topic-discover.sh          ← Telegram forum 토픽 ID 탐색
│   ├── telegram-bootstrap-allowlist.sh ← 봇 allowlist 초기 세팅
│   ├── install-mini-router-macos.sh ← mini-router macOS 설치
│   ├── mini-router-launchd.sh     ← mini-router launchd 등록
│   ├── mini-router-diagnose.sh    ← mini-router 진단
│   ├── sync-claude-creds.sh       ← Mac→Linux credentials watch-sync
│   ├── vault-mirror-sync.sh       ← Mac→Linux vault rsync (read 미러)
│   ├── obsidian-write.sh          ← agent → vault write (Local REST API)
│   ├── dashboard-sync.sh / dashboard-render.sh / canvas-render.sh / agents-state.sh / dashboard-tick.sh ← 대시보드 (deprecated, Hermes 네이티브 권장)
│   └── tmux-overview.sh           ← tmux 세션 TUI 집계 (--watch 플래그로 viddy 연동)
│
└── .github/
    ├── workflows/                 ← CI (shellcheck / markdownlint / link-check / install-smoke / router-tests / hygiene-scan)
    ├── ISSUE_TEMPLATE/            ← 버그/기능 요청 템플릿
    ├── PULL_REQUEST_TEMPLATE.md
    ├── dependabot.yml
    └── link-check-config.json
```

> Hermes 없이 시작한다면 [`mini-router/README.md`](mini-router/README.md)가 실전 진입 문서 — Telegram 토픽 → tmux 세션 라우팅을 mini-router만으로 굴리는 방법을 다룸.

---

## 자체 검토 (6-perspective audit)

> **주의**: 본 보고서는 **외부 독립 검토가 아니라 self-review** — `code-reviewer` / `test-automator` / `docs-architect` / `architect-reviewer` / `debugger` / `error-detective` 6가지 페르소나를 Claude Code subagent로 동일 저자가 실행하여 17개 Phase를 검토. 시각 다각화는 되었으나 외부 시각 부재.

이 단계에서 12개 critical issue를 발견하여 본문에 반영. 이후 **2026-07 외부 감사 라운드**에서 CI 워크플로 / 설치 경로 / 익명화 관련 이슈를 추가로 수정함 ([`CHANGELOG.md`](CHANGELOG.md) 참조). 외부 검토는 계속 환영. 자세히: [`docs/05-verification-report.md`](docs/05-verification-report.md)

주요 발견 (요약):

1. **Hermes를 단순 게이트웨이로 다루지 말 것** — 5 pillar (Soul/Memory/User/Skills/Crons) 자기개선 코어
2. **시크릿 관리 통합** — `.env` plaintext 금지, macOS Keychain 또는 `.pgpass`
3. **격리 분석** — RE 시 Docker 강제
4. **vault 3분리** — Public / Private / Work 별도 vault
5. **launchd PATH** — Apple Silicon `/opt/homebrew/bin` 우선
6. **Telegram allowed_chats** — `allowed_users`만으론 부족
7. **omo timeout** — specialist agent 무한 루프 방지
8. **자동 헬스체크** — 부팅 후 self-ping 필수

---

## 자주 묻는 질문

**Q: 왜 Hermes 위에 Paperclip을 또?**  
A: 다른 시간축. Hermes는 *너* 에 대한 학습 (영구), Paperclip은 *비즈니스 워크플로* 자동화 (cron). 둘 다 영구지만 다루는 게 다름.

**Q: Codex OAuth가 정책 바뀌면?**  
A: API 키 폴백 경로가 모든 컴포넌트에 명시되어 있음. `OPENAI_API_KEY` 환경변수 추가하면 즉시 전환 가능.

**Q: Anthropic OAuth를 opencode에 꽂는 우회 방법이 있다는데?**  
A: 있음 (omo_proxy). 이 레포는 이 경로를 권장하지 않지만, 위험 고지와 함께 기본 OFF opt-in(`--enable-claude-proxy`)으로 문서화해 동봉함 ([`docs/10-claude-oauth-proxy.md`](docs/10-claude-oauth-proxy.md)). ToS 위반으로 인한 계정 정지 위험은 전액 본인 부담 — Claude Pro/Max 구독을 잃으면 매몰비용 큼. 문제 발생 시 즉시 API 키 폴백으로 전환.

**Q: 토큰 비용은?**  
A: ChatGPT Plus ($20/월) + Claude Pro/Max ($20~$100/월) 구독 한도 안에서 운영 가능. 풀스로틀 사용자라면 ChatGPT Pro ($200) 권장.

**Q: 윈도우에서도 되나?**  
A: WSL2로 부분적 가능. 단 launchd 대신 systemd, macOS Keychain 대신 secret manager 필요. 가이드는 macOS 기준.

자세히: [`docs/07-faq.md`](docs/07-faq.md)

---

## 시작 전 알아둘 점

자동 설치(Phase 0~7)는 약 80분이면 돌고, 전체 스택을 손에 익히는 데는 ~4시간 + 4주 점진 확장이 걸림. 일주일 정도 익숙해지면 폰에서 보이스로 PR 만들기까지 가능.

다만:

- "모든 코드를 AI가 짠다"는 약속이 아님. 너의 판단이 여전히 중심.
- Hermes의 자기개선 loop는 강력하지만 시간이 걸림 (1주일 후부터 체감).
- Paperclip 회사 정의는 본인이 직접. 의사결정 트리만 제공.
- 모든 시크릿 관리는 본인 책임. 가이드는 안전 패턴만.

---

## 기여

이 레포는 reference architecture. PR, issue, 다른 환경 (Linux, NixOS, Windows WSL) 가이드 환영.

[`CONTRIBUTING.md`](CONTRIBUTING.md) 참고.

---

## 라이센스

[MIT](LICENSE) — 자유롭게 fork, 수정, 배포.

---

## Acknowledgments

이 레포는 다음 오픈소스 프로젝트 위에 서있음:

- [Anthropic Claude Code](https://claude.com/code) + [Skills marketplace](https://claude.com/plugins)
- [OpenAI Codex CLI](https://developers.openai.com/codex)
- [Hermes Agent (Nous Research)](https://github.com/NousResearch/hermes-agent)
- [opencode (anomalyco)](https://github.com/anomalyco/opencode)
- [oh-my-openagent (omo)](https://github.com/code-yeongyu/oh-my-openagent) — code-yeongyu
- [Superpowers (obra)](https://github.com/obra/superpowers) — Jesse Vincent
- [Paperclip](https://github.com/paperclipai/paperclip)
- [Obsidian](https://obsidian.md) — vault↔Claude Code 브리지는 셋업 시점에 활성 유지되고 있는 community plugin을 선택 (BRAT으로 검색)
- [Vault Daydream skill (glebis)](https://github.com/glebis/claude-skills)

---

> 질문/이슈는 GitHub Issues로.  
> 셋업 진행 중 막힌 곳을 토픽으로 분리해서 issue 올리면 더 빠른 답변 가능.
