#!/usr/bin/env bash
# agents-state.sh
# 모든 활성 agent의 현재 상태를 ~/.hermes/agents-state.json 으로 통합.
#
# 데이터 소스 (있는 것만 사용):
#   1. ~/.hermes/agents-state/*.jsonl  ← Claude Code 훅이 SubagentStart/Stop 시 append
#   2. ~/.opencode/logs/*.log          ← omo specialist 활성화 로그 (best-effort 파싱)
#   3. ~/.claude/logs/sessions/*.log   ← Claude Code 세션 로그 (best-effort)
#   4. ~/.hermes/logs/router.log       ← 최근 라우팅 결정
#   5. ~/.hermes/agent-registry.yaml   ← 정적 역할 매핑 (icon / role 룩업)
#
# 출력 schema (agents-state.json):
#   {
#     "updated_at": "ISO-8601",
#     "agents": [
#       {
#         "id":         "unique-id",
#         "name":       "Sisyphus",
#         "role":       "orchestrator",
#         "icon":       "⚙",
#         "harness":    "opencode" | "claude-code" | "hermes",
#         "session":    "tmux session name 또는 null",
#         "status":     "active" | "idle" | "done" | "failed",
#         "task":       "최근 명령/프롬프트 일부",
#         "started_at": "ISO-8601",
#         "parent":     "상위 agent id (있을 시)"
#       }, ...
#     ]
#   }

set -uo pipefail

STATE_DIR="${STATE_DIR:-${HOME}/.hermes/agents-state}"
OUTPUT="${OUTPUT:-${HOME}/.hermes/agents-state.json}"
REGISTRY="${REGISTRY:-${HOME}/.hermes/agent-registry.yaml}"
OPENCODE_LOG_DIR="${OPENCODE_LOG_DIR:-${HOME}/.opencode/logs}"
CLAUDE_LOG_DIR="${CLAUDE_LOG_DIR:-${HOME}/.claude/logs}"
HERMES_ROUTER_LOG="${HERMES_ROUTER_LOG:-${HOME}/.hermes/logs/router.log}"

# 지난 N분 안의 이벤트만 active로 간주
ACTIVE_WINDOW_MIN="${ACTIVE_WINDOW_MIN:-30}"

mkdir -p "${STATE_DIR}" "$(dirname "${OUTPUT}")"

NOW_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
NOW_EPOCH="$(date +%s)"
CUTOFF_EPOCH=$((NOW_EPOCH - ACTIVE_WINDOW_MIN * 60))

AGENTS_JSON="[]"

# ---------- helpers ----------

iso_to_epoch() {
  # BSD date (macOS) and GNU date 모두 시도
  date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$1" "+%s" 2>/dev/null \
    || date -u -d "$1" "+%s" 2>/dev/null \
    || echo 0
}

add_agent() {
  # args: id name role icon harness session status task started_at parent
  local id="$1" name="$2" role="$3" icon="$4" harness="$5"
  local session="$6" status="$7" task="$8" started="$9" parent="${10:-}"

  AGENTS_JSON="$(printf '%s' "$AGENTS_JSON" | jq \
    --arg id "$id" --arg name "$name" --arg role "$role" --arg icon "$icon" \
    --arg harness "$harness" --arg session "$session" --arg status "$status" \
    --arg task "$task" --arg started "$started" --arg parent "$parent" \
    '. + [{
      id: $id, name: $name, role: $role, icon: $icon,
      harness: $harness,
      session: ($session | select(. != "") // null),
      status: $status,
      task: $task,
      started_at: $started,
      parent: ($parent | select(. != "") // null)
    }]')"
}

# ---------- 1. JSONL hook events (highest signal) ----------
# Claude Code / opencode 훅이 SubagentStart/Stop 시 append하는 파일.
# 형식: 한 줄 JSON {event, agent_name, session, task, ts, parent?}
# event: "start" | "stop" | "fail"
# bash 3.2 호환 위해 jq로 group-by 처리 (associative array 미사용)

ALL_EVENTS_JSON="[]"
if [ -d "$STATE_DIR" ]; then
  for f in "${STATE_DIR}"/*.jsonl; do
    [ -e "$f" ] || continue
    session_from_file="$(basename "${f%.jsonl}")"
    # 모든 이벤트를 한 배열로 수집 (file context = default session)
    file_events="$(jq -c --arg sess "$session_from_file" \
      '. + {session: (.session // $sess)}' \
      < "$f" 2>/dev/null | jq -s '.' 2>/dev/null || echo "[]")"
    ALL_EVENTS_JSON="$(jq -n --argjson a "$ALL_EVENTS_JSON" --argjson b "$file_events" '$a + $b')"
  done
fi

# 각 (session, agent_name)별로 가장 최근 이벤트만 추출
LATEST_EVENTS_JSON="$(printf '%s' "$ALL_EVENTS_JSON" | jq '
  group_by([.session, .agent_name])
  | map(sort_by(.ts) | .[-1])
  | map(select(.event != null and .agent_name != null))
')"

# registry에서 agent 이름으로 role/icon 룩업
lookup_role() {
  local name="$1"
  if [ -f "$REGISTRY" ] && command -v yq >/dev/null 2>&1; then
    yq -r "(.omo.${name}.role // .claude_code[\"${name}\"].role // \"\")" "$REGISTRY" 2>/dev/null
  else
    case "$name" in
      sisyphus|Sisyphus)       echo "orchestrator" ;;
      hephaestus|Hephaestus)   echo "implementer" ;;
      oracle|Oracle)           echo "reviewer" ;;
      librarian|Librarian)     echo "spec_lookup" ;;
      explore|Explore)         echo "codebase_search" ;;
      artistry|Artistry)       echo "ui_polish" ;;
      code-reviewer)           echo "code_quality_audit" ;;
      test-automator)          echo "test_generation" ;;
      docs-architect)          echo "docs_generation" ;;
      architect-reviewer)      echo "system_design_review" ;;
      debugger)                echo "error_root_cause" ;;
      error-detective)         echo "log_analysis" ;;
      *) echo "unknown" ;;
    esac
  fi
}

lookup_icon() {
  local name="$1"
  if [ -f "$REGISTRY" ] && command -v yq >/dev/null 2>&1; then
    yq -r "(.omo.${name}.icon // .claude_code[\"${name}\"].icon // \"\")" "$REGISTRY" 2>/dev/null
  else
    case "$name" in
      sisyphus|Sisyphus)       echo "⚙" ;;
      hephaestus|Hephaestus)   echo "🔨" ;;
      oracle|Oracle)           echo "🔍" ;;
      librarian|Librarian)     echo "📚" ;;
      explore|Explore)         echo "🔎" ;;
      artistry|Artistry)       echo "🎨" ;;
      code-reviewer)           echo "🔎" ;;
      test-automator)          echo "🧪" ;;
      docs-architect)          echo "📝" ;;
      architect-reviewer)      echo "🏛" ;;
      debugger)                echo "🐛" ;;
      error-detective)         echo "🔍" ;;
      *) echo "🤖" ;;
    esac
  fi
}

lookup_harness() {
  case "$1" in
    sisyphus|hephaestus|oracle|librarian|explore|artistry|adversary_a)
      echo "opencode" ;;
    code-reviewer|test-automator|docs-architect|architect-reviewer|debugger|error-detective)
      echo "claude-code" ;;
    *) echo "unknown" ;;
  esac
}

# 각 (session, agent_name) latest event → agent entry
# jq에서 추출한 후 shell loop로 lookup_role/icon/harness 적용
EVENTS_TSV="$(printf '%s' "$LATEST_EVENTS_JSON" | jq -r \
  '.[] | [.event, .agent_name, .session, (.ts // ""), (.task // ""), (.parent // "")] | @tsv')"

HOOK_AGENT_KEYS=""  # "session/name" 누적 (opencode log fallback 시 중복 회피)
while IFS=$'\t' read -r ev ag_name ag_session ag_ts ag_task ag_parent; do
  [ -z "$ev" ] && continue
  [ -z "$ag_name" ] && continue

  ts_epoch="$(iso_to_epoch "$ag_ts")"
  if [ "${ts_epoch:-0}" -lt "$CUTOFF_EPOCH" ] && [ "$ev" != "fail" ]; then
    continue
  fi

  status="active"
  case "$ev" in
    start) status="active" ;;
    stop)  status="done" ;;
    fail)  status="failed" ;;
  esac

  role="$(lookup_role "$ag_name")"
  icon="$(lookup_icon "$ag_name")"
  harness="$(lookup_harness "$ag_name")"
  id="${harness}-${ag_session}-${ag_name}"

  add_agent "$id" "$ag_name" "$role" "$icon" "$harness" \
            "$ag_session" "$status" "$ag_task" "$ag_ts" "$ag_parent"
  HOOK_AGENT_KEYS="${HOOK_AGENT_KEYS}|${ag_session}/${ag_name}|"
done <<< "$EVENTS_TSV"

# ---------- 2. opencode log best-effort 파싱 ----------
# 훅 데이터가 없을 때 fallback. omo가 "Specialist activated: X" 류 로그 남긴다고 가정.
if [ -d "$OPENCODE_LOG_DIR" ]; then
  # 최근 30분 안에 수정된 로그만
  while IFS= read -r logf; do
    [ -e "$logf" ] || continue
    # 세션 이름 추측: 파일명에서
    session_guess="$(basename "${logf%.log}")"

    # 마지막 100줄에서 "Specialist activated|Dispatching to" 류 패턴
    while IFS= read -r line; do
      ag=""
      # 패턴 1: "[Sisyphus] Dispatching to Hephaestus"
      if [[ "$line" =~ Dispatching\ to\ ([A-Za-z]+) ]]; then
        ag="${BASH_REMATCH[1]}"
      # 패턴 2: "[omo] Activating: Oracle"
      elif [[ "$line" =~ Activating:\ ([A-Za-z]+) ]]; then
        ag="${BASH_REMATCH[1]}"
      # 패턴 3: "Specialist: Hephaestus started"
      elif [[ "$line" =~ Specialist:\ ([A-Za-z]+) ]]; then
        ag="${BASH_REMATCH[1]}"
      fi

      if [ -n "$ag" ]; then
        ag_lower="$(printf '%s' "$ag" | tr '[:upper:]' '[:lower:]')"
        # 이미 훅 데이터로 있으면 skip
        case "$HOOK_AGENT_KEYS" in
          *"|${session_guess}/${ag_lower}|"*) continue ;;
          *"|${session_guess}/${ag}|"*) continue ;;
        esac

        role="$(lookup_role "$ag_lower")"
        icon="$(lookup_icon "$ag_lower")"
        id="opencode-${session_guess}-${ag_lower}-log"
        add_agent "$id" "$ag" "$role" "$icon" "opencode" \
                  "$session_guess" "active" "(from log)" "$NOW_ISO" ""
      fi
    done < <(tail -n 100 "$logf" 2>/dev/null)
  done < <(find "$OPENCODE_LOG_DIR" -name "*.log" -newermt "${ACTIVE_WINDOW_MIN} minutes ago" 2>/dev/null)
fi

# ---------- 3. 최근 router 결정 → "Hermes self" entry ----------
if [ -f "$HERMES_ROUTER_LOG" ]; then
  last_route="$(tail -n 1 "$HERMES_ROUTER_LOG" 2>/dev/null)"
  if [ -n "$last_route" ]; then
    # 라우터 자체를 한 agent로 표시
    add_agent "hermes-router" "router" "routing" "🧭" "hermes" \
              "" "active" "$last_route" "$NOW_ISO" ""
  fi
fi

# ---------- 출력 ----------
jq -n \
  --arg updated "$NOW_ISO" \
  --argjson agents "$AGENTS_JSON" \
  --argjson window "$ACTIVE_WINDOW_MIN" \
  '{
    updated_at: $updated,
    active_window_minutes: $window,
    agents: $agents,
    by_session: ($agents | group_by(.session // "_no_session_") | map({session: .[0].session, agents: .})),
    by_harness: ($agents | group_by(.harness) | map({harness: .[0].harness, agents: .}))
  }' > "$OUTPUT"

# 한 줄 요약 stdout
count=$(printf '%s' "$AGENTS_JSON" | jq 'length')
echo "agents-state: $count active agents → $OUTPUT"
