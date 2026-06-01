# examples/ 가이드

이 디렉토리의 모든 파일은 **복사 후 수정해서 쓰는 템플릿**이다. 어떤 파일도 repo 안에서 직접 실행되도록 설계되지 않았다 (예외: `hooks/cc-subagent-trace.sh` — repo 경로 그대로 참조 가능).

공통 규칙:

- `.example` / `.example.*` 확장자는 복사 시 제거한다.
- `YOUR_USERNAME`, `<user>`, `${MODEL_*}` 같은 placeholder는 본인 값으로 치환한다.
- 시크릿은 파일에 직접 적지 않는다 — macOS Keychain(`security`) / Linux `secret-tool` 사용.

## configs/ — systemd unit / launchd plist / 앱 설정

| 파일 | 복사 목적지 | 이름 변경 | 의존 관계 | 관련 문서 |
|------|------------|-----------|-----------|-----------|
| `agent-registry.example.yaml` | `~/.hermes/agent-registry.yaml` | `.example` 제거 | `scripts/agents-state.sh`, `scripts/canvas-render.sh`가 role/icon 룩업에 사용 | [docs/09](../docs/09-agent-instrumentation.md) |
| `com.user.claude-creds-sync.plist.example` | `~/Library/LaunchAgents/com.user.claude-creds-sync.plist` | `.example` 제거 | `scripts/sync-claude-creds.sh` 호출 | [docs/10](../docs/10-claude-oauth-proxy.md) |
| `com.user.dashboard-sync.plist.example` | `~/Library/LaunchAgents/com.user.dashboard-sync.plist` | `.example` 제거 | `scripts/dashboard-sync.sh` 호출 | [docs/13](../docs/13-mission-control-operations.md), [docs/14](../docs/14-mobile-vault-sync.md) |
| `com.user.mini-router.plist.example` | `~/Library/LaunchAgents/com.user.mini-router.plist` | `.example` 제거 | `mini-router/bot.py`, `~/.hermes/topic_map.yaml` | [mini-router/README](../mini-router/README.md) |
| `com.user.vault-mirror-sync.plist.example` | `~/Library/LaunchAgents/com.user.vault-mirror-sync.plist` | `.example` 제거 | `scripts/vault-mirror-sync.sh` 호출 | [docs/15](../docs/15-obsidian-vault-integration.md), [docs/16](../docs/16-obsidian-rest-api-write.md) |
| `dashboard-render.plist.example` | **DEPRECATED** — Hermes 네이티브 대시보드(`localhost:9119`, `hermes-dashboard.service.example`) 권장. 굳이 쓰면 `~/Library/LaunchAgents/com.agentic-harness.dashboard-render.plist` | `.example` 제거 | `scripts/dashboard-tick.sh` | [docs/13](../docs/13-mission-control-operations.md) |
| `dashboard-render.service.example` | **DEPRECATED** (위와 동일) — `/etc/systemd/system/dashboard-render.service` | `.example` 제거 | `dashboard-render.timer`와 쌍, `scripts/dashboard-tick.sh` | [docs/13](../docs/13-mission-control-operations.md) |
| `dashboard-render.timer.example` | **DEPRECATED** (위와 동일) — `/etc/systemd/system/dashboard-render.timer` | `.example` 제거 | `dashboard-render.service` 트리거 | [docs/13](../docs/13-mission-control-operations.md) |
| `dashboard-tick.service.example` | **DEPRECATED** (위와 동일) — `~/.config/systemd/user/dashboard-tick.service` | `.example` 제거 | `scripts/dashboard-tick.sh`, `~/.hermes/agents-state.json` | [docs/13](../docs/13-mission-control-operations.md) |
| `dashboard-tick.timer.example` | **DEPRECATED** (위와 동일) — `~/.config/systemd/user/dashboard-tick.timer` | `.example` 제거 | `dashboard-tick.service` 트리거 | [docs/13](../docs/13-mission-control-operations.md) |
| `hermes-config.example.yaml` | `~/.hermes/config.yaml` | `.example` 제거 | `soul/` 3종 파일 경로 참조, `${MODEL_*}` 치환 필요 | [docs/03](../docs/03-execution-phase1-7.md) |
| `hermes-daily-rollup.service.example` | `~/.config/systemd/user/hermes-daily-rollup.service` | `.example` 제거 | `scripts/hermes-daily-rollup.sh` | [docs/08](../docs/08-memory-feedback-pattern.md) |
| `hermes-daily-rollup.timer.example` | `~/.config/systemd/user/hermes-daily-rollup.timer` | `.example` 제거 | `hermes-daily-rollup.service` 트리거 | [docs/08](../docs/08-memory-feedback-pattern.md) |
| `hermes-dashboard.service.example` | `~/.config/systemd/user/hermes-dashboard.service` | `.example` 제거 | `hermes` CLI (`~/.local/bin/hermes`) | [docs/13](../docs/13-mission-control-operations.md) |
| `hermes-gateway.override.conf.example` | `~/.config/systemd/user/hermes-gateway.service.d/override.conf` | `override.conf`로 변경 | `secret-tool`(service `hermes` / account `telegram-bot-token`), `~/.hermes/.env`. ANTHROPIC_* 블록은 off-policy opt-in | [docs/06](../docs/06-troubleshooting.md), [docs/10](../docs/10-claude-oauth-proxy.md) |
| `mini-router.service.example` | `~/.config/systemd/user/mini-router.service` (`scripts/install-all.sh`가 placeholder 치환 후 자동 설치) | `.example` 제거 | `mini-router/bot.py`, `~/.hermes/topic_map.yaml`, `secret-tool` | [mini-router/README](../mini-router/README.md) |
| `oh-my-openagent.example.jsonc` | `~/.config/opencode/oh-my-openagent.jsonc` | `.example` 제거 | opencode + omo 플러그인, `${MODEL_*}` 치환 필요 | [docs/02](../docs/02-architecture.md), [docs/04](../docs/04-execution-phase8-17.md) |
| `omo-proxy.service.example` | `~/.config/systemd/user/omo-proxy.service` | `.example` 제거 | omo_proxy clone, `~/.claude/.credentials.json` — **off-policy opt-in** | [docs/10](../docs/10-claude-oauth-proxy.md) |
| `opencode.example.jsonc` | `~/.config/opencode/opencode.jsonc` | `.example` 제거 | Codex OAuth 플러그인, `${MODEL_*}` 치환 필요 | [docs/03](../docs/03-execution-phase1-7.md) |
| `quant-ingest.service.example` | `~/.config/systemd/user/quant-ingest.service` | `.example` 제거 | `~/dev/quant/routines/ingest.sh` (= `routines/quant-ingest.sh.example`을 복사+이름 변경한 것) | [docs/08](../docs/08-memory-feedback-pattern.md) |
| `quant-ingest.timer.example` | `~/.config/systemd/user/quant-ingest.timer` | `.example` 제거 | `quant-ingest.service` 트리거 | [docs/08](../docs/08-memory-feedback-pattern.md) |
| `quant-rollup.service.example` | `~/.config/systemd/user/quant-rollup.service` | `.example` 제거 | `~/dev/quant/routines/rollup.sh` (= `routines/quant-rollup.sh.example`을 복사+이름 변경한 것) | [docs/08](../docs/08-memory-feedback-pattern.md) |
| `quant-rollup.timer.example` | `~/.config/systemd/user/quant-rollup.timer` | `.example` 제거 | `quant-rollup.service` 트리거 | [docs/08](../docs/08-memory-feedback-pattern.md) |
| `topic-map.example.yaml` | `~/.hermes/topic_map.yaml` | **`topic-map` → `topic_map`** (하이픈 → 언더스코어) + `.example` 제거 | `mini-router/bot.py`와 Hermes router가 소비. `topic_id`는 `scripts/topic-discover.sh`로 확인 | [mini-router/README](../mini-router/README.md) |

## hooks/ — Claude Code 훅

| 파일 | 복사 목적지 | 이름 변경 | 의존 관계 | 관련 문서 |
|------|------------|-----------|-----------|-----------|
| `cc-subagent-trace.sh` | 복사 불필요 — repo 경로 그대로 settings.json에서 절대경로로 참조 (`chmod +x` 필요) | — | `jq`(또는 `python3`), 출력을 `scripts/agents-state.sh`가 소비 | [docs/09](../docs/09-agent-instrumentation.md) |
| `claude-settings-snippet.example.json` | 파일 복사 X — `hooks` 키만 `~/.claude/settings.json`에 병합 | — | `cc-subagent-trace.sh` 절대경로 참조 (경로 수정 필수) | [docs/09](../docs/09-agent-instrumentation.md) |

## paperclip-companies/ — Paperclip 회사 설계 예시 (참고 문서)

복사 목적지가 없다. Paperclip에서 회사/routine을 만들 때 참고하는 설계 문서다.

| 파일 | 복사 목적지 | 이름 변경 | 의존 관계 | 관련 문서 |
|------|------------|-----------|-----------|-----------|
| `content-studio.example.md` | 없음 (설계 참고용) | — | Paperclip(`localhost:3100`), Board approval 채널 | [docs/08](../docs/08-memory-feedback-pattern.md) |
| `quant-research-action-loop.example.md` | 없음 (설계 참고용) | — | `configs/quant-*` unit + `routines/quant-*` 스크립트와 같은 패턴 | [docs/08](../docs/08-memory-feedback-pattern.md) |
| `research-lab.example.md` | 없음 (설계 참고용) | — | Paperclip(`localhost:3100`), vault | [docs/08](../docs/08-memory-feedback-pattern.md) |

## routines/ — quant 사이클 placeholder 스크립트

주의: **복사하면서 파일명이 바뀐다.** systemd unit의 `ExecStart`는 바뀐 이름(`ingest.sh` / `rollup.sh`)을 참조한다.

| 파일 | 복사 목적지 | 이름 변경 | 의존 관계 | 관련 문서 |
|------|------------|-----------|-----------|-----------|
| `quant-ingest.sh.example` | `~/dev/quant/routines/ingest.sh` | **`quant-ingest.sh.example` → `ingest.sh`** | `configs/quant-ingest.service.example`이 이 경로 실행 | [docs/08](../docs/08-memory-feedback-pattern.md) |
| `quant-rollup.sh.example` | `~/dev/quant/routines/rollup.sh` | **`quant-rollup.sh.example` → `rollup.sh`** | `configs/quant-rollup.service.example`, `scripts/hermes-feedback.sh` | [docs/08](../docs/08-memory-feedback-pattern.md) |

복사 예:

```bash
mkdir -p ~/dev/quant/routines
cp examples/routines/quant-ingest.sh.example ~/dev/quant/routines/ingest.sh
cp examples/routines/quant-rollup.sh.example ~/dev/quant/routines/rollup.sh
chmod +x ~/dev/quant/routines/{ingest,rollup}.sh
```

## soul/ — Hermes 5 Pillar 템플릿

| 파일 | 복사 목적지 | 이름 변경 | 의존 관계 | 관련 문서 |
|------|------------|-----------|-----------|-----------|
| `SOUL.example.md` | `~/.hermes/SOUL.md` | `.example` 제거 | `configs/hermes-config.example.yaml`의 `soul_file` | [docs/02](../docs/02-architecture.md), [docs/03](../docs/03-execution-phase1-7.md) |
| `MEMORY.example.md` | `~/.hermes/MEMORY.md` | `.example` 제거 | `memory_file` + `scripts/hermes-feedback.sh`가 append | [docs/08](../docs/08-memory-feedback-pattern.md) |
| `USER.example.md` | `~/.hermes/USER.md` | `.example` 제거 | `user_file` | [docs/02](../docs/02-architecture.md), [docs/03](../docs/03-execution-phase1-7.md) |
