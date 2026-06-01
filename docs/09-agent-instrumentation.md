# Agent Instrumentation — 누가 어디서 뭘 하는지 보이게

> Mission Control 칸반에 active agent role / 할당 상황이 보이려면, 각 harness가 lifecycle 이벤트를 공유 위치에 기록해야 한다. 본 문서는 그 패턴.

## 두 레이어

1. **정적 registry** (`examples/configs/agent-registry.example.yaml`):
   - 시스템에 어떤 agent가 존재하고 각자 무슨 역할인지
   - icon / 모델 / trigger / 호출 관계
   - 사용자가 직접 관리. 한 번 작성하면 거의 안 바뀜.

2. **동적 state** (`~/.hermes/agents-state.json`):
   - 지금 이 순간 누가 어느 세션에서 무슨 작업을 하고 있는지
   - `scripts/agents-state.sh` 가 매 1분 갱신
   - canvas-render.sh가 읽어서 칸반 카드에 표기

## 데이터 흐름

```text
┌─ Claude Code session ─┐         ┌─ opencode session ──┐
│  Agent tool 호출      │         │  Sisyphus dispatch  │
│   ↓ PreToolUse hook   │         │   ↓ omo telemetry   │
│  cc-subagent-trace.sh │         │  log 출력 (best-eff)│
└──────────┬────────────┘         └──────────┬──────────┘
           │                                  │
           ▼                                  ▼
  ~/.hermes/agents-state/<session>.jsonl  ~/.opencode/logs/*.log
           │                                  │
           └───────────────┬──────────────────┘
                           ▼
                ┌──────────────────────┐
                │ scripts/agents-state │  (매 1분)
                │     .sh              │
                └──────────┬───────────┘
                           ▼
            ~/.hermes/agents-state.json
                           │
                           ▼
                ┌──────────────────────┐
                │ scripts/canvas-render│  (매 1분)
                │     .sh              │
                └──────────┬───────────┘
                           ▼
   Obsidian Vault/00-Mission-Control/Mission-Control.canvas
                           │
                           ▼
           폰/데스크탑 Obsidian Canvas 칸반 view
```

## Claude Code 훅 설치 (subagent lifecycle 자동 기록)

1. 훅 스크립트 실행 권한:

   ```bash
   chmod +x examples/hooks/cc-subagent-trace.sh
   ```

2. `~/.claude/settings.json`에 hooks 키 병합:

   ```bash
   # 백업
   cp ~/.claude/settings.json ~/.claude/settings.json.bak

   # 병합 (예: jq merge)
   jq -s '.[0] * .[1]' \
     ~/.claude/settings.json \
     examples/hooks/claude-settings-snippet.example.json \
     > ~/.claude/settings.json.new
   mv ~/.claude/settings.json.new ~/.claude/settings.json
   ```

3. Claude Code 재시작 → 다음 subagent 호출부터 `~/.hermes/agents-state/<session>.jsonl`에 이벤트 append

4. 확인:

   ```bash
   # 최근 hook 이벤트
   tail ~/.hermes/agents-state/*.jsonl

   # 통합 state JSON
   bash scripts/agents-state.sh
   jq '.agents[] | {name, role, session, status}' ~/.hermes/agents-state.json
   ```

## opencode (omo) 측

opencode는 native hook system이 Claude Code만큼 단순하지 않을 수 있음. 두 접근:

**옵션 A — omo skill로 trace 강제 (권장)**:

- `~/.config/superpowers/skills/omo-trace/SKILL.md` 추가 (별도 작업 필요)
- Sisyphus가 specialist를 dispatch할 때마다 trace 명령을 호출하도록 skill에 강제
- 트리거된 specialist 정보를 `~/.hermes/agents-state/oc-<session>.jsonl`에 append

**옵션 B — log 파싱 fallback (현재 구현)**:

- `agents-state.sh`가 `~/.opencode/logs/*.log`를 tail 파싱
- 패턴: `Dispatching to <Name>` / `Activating: <Name>` / `Specialist: <Name> started`
- 정확도 한계 있음 (omo 출력 포맷 의존), 그러나 훅 설치 없이 즉시 작동

## 정적 registry 사용

`examples/configs/agent-registry.example.yaml`를 `~/.hermes/agent-registry.yaml`로 복사 후 본인 환경에 맞게 수정 (모델 ID 치환 등).

`agents-state.sh`는 이 파일이 있으면 yq로 role/icon을 룩업, 없으면 하드코딩된 fallback 사용. 새 agent를 시스템에 추가하면 (예: 새 Claude Code subagent) registry에도 추가하기.

## 칸반에서 보이는 모습

`canvas-render.sh`가 두 곳에 agent 정보를 표시:

1. **각 tmux 세션 카드 안**: 그 세션에 binding된 active agent 리스트가 inline bullet으로

   ```
   ## 🖥 oc-<project-d>
   idle: 2m
   `oc-<project-d>: 3 windows (created ...)`

   **Active roles**:
   - ⚙ sisyphus (orchestrator)
   - 🔨 hephaestus (implementer)
   - 🔍 oracle (reviewer)
   ```

2. **In Progress 컬럼 상단 "Agent Roster" 종합 카드**: 모든 harness 전체 active agent

   ```
   ## 🤖 Active Agent Roster (5)

   **opencode** (3)
   - ⚙ sisyphus — orchestrator · `ulw 보안 감사`
   - 🔨 hephaestus — implementer · `patch gas optimization`
   - 🔍 oracle — reviewer · `audit invariants`

   **claude-code** (2)
   - 🔎 code-reviewer — code_quality_audit · `PR #142 review`
   - 🐛 debugger — error_root_cause · `crash in module X`
   ```

이 두 view 덕분에:

- "지금 어떤 agent들이 살아있나" — Roster 카드로 한눈에
- "어느 세션에서 누가 작업 중인가" — session 카드 inline bullet으로

## 검증 / 트러블슈팅

| 증상 | 점검 |
|------|------|
| 칸반에 Agent Roster 카드가 안 보임 | `cat ~/.hermes/agents-state.json` → agents 배열 비어있나? |
| agents-state.json은 채워졌는데 칸반엔 반영 X | `AGENTS_STATE_JSON` 환경변수 일치 확인. canvas-render.sh stat 후 launchd/systemd 재로드 |
| 훅이 안 부르는 듯 (jsonl이 안 생김) | `~/.claude/settings.json`의 hooks 키 jq로 검증. Claude Code 재시작 했나? |
| jsonl이 무한 누적 | `find ~/.hermes/agents-state -mtime +7 -delete` cron으로 7일 이전 자동 정리 |
| 같은 agent가 active로 영원히 잡힘 | `ACTIVE_WINDOW_MIN` (default 30분) 안에 새 start 이벤트만 살아있다고 간주. SubagentStop이 안 와도 30분 후 자동 cull |

## 관련 자료

- 정적 registry: [`examples/configs/agent-registry.example.yaml`](../examples/configs/agent-registry.example.yaml)
- 동적 collector: [`scripts/agents-state.sh`](../scripts/agents-state.sh)
- Claude Code 훅 스크립트: [`examples/hooks/cc-subagent-trace.sh`](../examples/hooks/cc-subagent-trace.sh)
- 훅 settings.json snippet: [`examples/hooks/claude-settings-snippet.example.json`](../examples/hooks/claude-settings-snippet.example.json)
- 칸반 렌더러: [`scripts/canvas-render.sh`](../scripts/canvas-render.sh)
