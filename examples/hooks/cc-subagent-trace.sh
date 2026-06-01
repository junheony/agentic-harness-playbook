#!/usr/bin/env bash
# cc-subagent-trace.sh
# Claude Code 훅으로 subagent lifecycle (start/stop/fail)을 캡처해
# ~/.hermes/agents-state/<session>.jsonl 에 append.
# scripts/agents-state.sh 가 매 사이클 이 JSONL을 읽어 agents-state.json으로 통합.
#
# Claude Code 훅 프로토콜 (실제 동작):
#   훅은 환경변수가 아니라 STDIN으로 JSON 객체 하나를 받는다.
#   공통 필드: hook_event_name, session_id, transcript_path, cwd
#   PreToolUse/PostToolUse 추가 필드: tool_name, tool_input (PostToolUse는 tool_response도)
#   subagent 호출 = Task tool → tool_input.subagent_type / .description / .prompt
#
# 훅 매핑 (~/.claude/settings.json — claude-settings-snippet.example.json 참고):
#   - PreToolUse  + matcher "Task" → 이 스크립트 (event=start)
#   - SubagentStop                 → 이 스크립트 (event=stop)
#   - PostToolUse + matcher "Task" → tool_response 실패 시 event=fail (성공은 무시)
#
# 파싱: jq 우선, 없으면 python3 -c json fallback.
#
# 출력 JSONL 스키마 (agents-state.sh와 필드명 동일해야 함):
#   {"event": "start|stop|fail", "agent_name": "...", "session": "...",
#    "task": "...", "ts": "ISO-8601"}

set -uo pipefail

STATE_DIR="${STATE_DIR:-${HOME}/.hermes/agents-state}"
mkdir -p "$STATE_DIR"

# ---------- STDIN JSON 읽기 ----------
PAYLOAD="$(cat 2>/dev/null || true)"
[ -z "$PAYLOAD" ] && PAYLOAD='{}'

# ---------- JSON 필드 추출 helper (jq → python3 fallback) ----------
json_get() {
  # usage: json_get "dot.notation.path" → 값 (없으면 빈 문자열)
  local path="$1"
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$PAYLOAD" | jq -r --arg p "$path" '
      getpath($p | split("."))
      | if . == null then empty
        elif type == "string" then .
        else tojson end
    ' 2>/dev/null || true
  else
    printf '%s' "$PAYLOAD" | python3 -c '
import json, sys
path = sys.argv[1].split(".")
try:
    obj = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for key in path:
    if isinstance(obj, dict) and key in obj:
        obj = obj[key]
    else:
        sys.exit(0)
if obj is None:
    sys.exit(0)
sys.stdout.write(obj if isinstance(obj, str) else json.dumps(obj, ensure_ascii=False))
' "$path" 2>/dev/null || true
  fi
}

HOOK_EVENT="$(json_get hook_event_name)"
TOOL_NAME="$(json_get tool_name)"

# ---------- 세션 식별 (우선순위): session_id → tmux 세션 이름 → "default" ----------
SESSION="$(json_get session_id)"
if [ -z "$SESSION" ] && [ -n "${TMUX:-}" ]; then
  SESSION="$(tmux display-message -p '#S' 2>/dev/null || echo default)"
fi
SESSION="${SESSION:-default}"
SESSION="${SESSION//\//_}"   # 파일명 안전화

# ---------- 이벤트 종류 매핑 ----------
EVENT=""
case "$HOOK_EVENT" in
  PreToolUse)
    # matcher "Task"가 이미 필터링하지만, 방어적으로 한 번 더 확인
    [ "$TOOL_NAME" = "Task" ] || exit 0
    EVENT="start"
    ;;
  SubagentStop)
    EVENT="stop"
    ;;
  PostToolUse)
    [ "$TOOL_NAME" = "Task" ] || exit 0
    # tool 실패 여부는 tool_response에서
    succ="$(json_get tool_response.success)"
    err="$(json_get tool_response.error)"
    if [ "$succ" = "false" ] || [ -n "$err" ]; then
      EVENT="fail"
    else
      # PostToolUse 성공은 SubagentStop이 별도로 처리하므로 여기선 무시
      exit 0
    fi
    ;;
  *)
    # 훅 밖에서 수동 호출 시: 첫 번째 인자를 이벤트로 (기본 start)
    EVENT="${1:-start}"
    ;;
esac

# ---------- subagent 이름 추출 ----------
# PreToolUse/PostToolUse: tool_input.subagent_type
# SubagentStop: payload에 subagent 정보가 없는 버전이 많음 → best-effort
SUBAGENT_NAME="$(json_get tool_input.subagent_type)"
[ -z "$SUBAGENT_NAME" ] && SUBAGENT_NAME="$(json_get agent_type)"
SUBAGENT_NAME="${SUBAGENT_NAME:-unknown-subagent}"

# ---------- task 설명 (Task tool input의 description 또는 prompt) ----------
TASK="$(json_get tool_input.description)"
[ -z "$TASK" ] && TASK="$(json_get tool_input.prompt)"
TASK="${TASK:0:120}"

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
OUT_FILE="${STATE_DIR}/${SESSION}.jsonl"

# ---------- JSON line append (jq → python3 fallback) ----------
if command -v jq >/dev/null 2>&1; then
  jq -cn \
    --arg event "$EVENT" \
    --arg agent_name "$SUBAGENT_NAME" \
    --arg session "$SESSION" \
    --arg task "$TASK" \
    --arg ts "$TS" \
    '{event: $event, agent_name: $agent_name, session: $session, task: $task, ts: $ts}' \
    >> "$OUT_FILE"
else
  python3 -c '
import json, sys
print(json.dumps({
    "event": sys.argv[1],
    "agent_name": sys.argv[2],
    "session": sys.argv[3],
    "task": sys.argv[4],
    "ts": sys.argv[5],
}, ensure_ascii=False))
' "$EVENT" "$SUBAGENT_NAME" "$SESSION" "$TASK" "$TS" >> "$OUT_FILE"
fi

exit 0
