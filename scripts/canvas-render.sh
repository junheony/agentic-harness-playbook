#!/usr/bin/env bash
# canvas-render.sh — Obsidian Canvas 라이브 칸반 대시보드
# 매분 호출. Pending / In Progress / Blocked / Done Today 4-컬럼 kanban.
# 카드는 자신의 상태에 따라 컬럼 사이를 이동.
# node id deterministic → 같은 카드는 항상 같은 id (재실행 시 위치 안정).

set -uo pipefail

VAULT_ROOT="${VAULT_ROOT:-${HOME}/Documents/SecondBrain}"
PAPERCLIP_URL="${PAPERCLIP_URL:-http://localhost:3100}"
CANVAS_PATH="${CANVAS_PATH:-${VAULT_ROOT}/00-Mission-Control/Mission-Control.canvas}"
AGENTS_STATE_JSON="${AGENTS_STATE_JSON:-${HOME}/.hermes/agents-state.json}"

NOW="$(date '+%Y-%m-%d %H:%M')"
TODAY="$(date '+%Y-%m-%d')"

# 세션별 active agent 리스트 (markdown bullets로 포맷)
agents_for_session() {
  local sess="$1"
  [ ! -f "$AGENTS_STATE_JSON" ] && return
  jq -r --arg s "$sess" '
    .agents
    | map(select(.session == $s and .status == "active"))
    | if length == 0 then ""
      else
        "\n\n**Active roles**:\n" +
        (map("- \(.icon // "🤖") \(.name) (\(.role // "?"))") | join("\n"))
      end
  ' "$AGENTS_STATE_JSON" 2>/dev/null
}

# Kanban column geometry
COL_W=420
COL_H_HEADER=80
CARD_W=400
CARD_H_DEFAULT=140
CARD_GAP_Y=20
HEADER_Y=0
FIRST_CARD_Y=$((COL_H_HEADER + 20))

# Obsidian Canvas color id 사용 (1=red 2=orange 3=yellow 4=green 5=cyan 6=purple)
COL_PENDING_X=0      ; COL_PENDING_COLOR=""    ; COL_PENDING_LABEL="📋 Pending"
COL_INPROG_X=$((COL_W * 1))  ; COL_INPROG_COLOR="5"   ; COL_INPROG_LABEL="⚙️ In Progress"
COL_BLOCKED_X=$((COL_W * 2)) ; COL_BLOCKED_COLOR="3"  ; COL_BLOCKED_LABEL="⚠️ Blocked"
COL_DONE_X=$((COL_W * 3))    ; COL_DONE_COLOR="4"    ; COL_DONE_LABEL="✅ Done Today"

# 각 컬럼의 현재 stacking y (header 아래부터 시작)
PENDING_Y=$FIRST_CARD_Y
INPROG_Y=$FIRST_CARD_Y
BLOCKED_Y=$FIRST_CARD_Y
DONE_Y=$FIRST_CARD_Y

# JSON accumulators
NODES_JSON="[]"
EDGES_JSON="[]"

# ---------- node helpers ----------

add_text_card() {
  # args: id col_x col_y w h text [color]
  local id="$1" x="$2" y="$3" w="$4" h="$5" content="$6" color="${7:-}"
  if [ -n "$color" ]; then
    NODES_JSON="$(printf '%s' "$NODES_JSON" | jq \
      --arg id "$id" --arg text "$content" --arg col "$color" \
      --argjson x "$x" --argjson y "$y" --argjson w "$w" --argjson h "$h" \
      '. + [{"id": $id, "type": "text", "x": $x, "y": $y, "width": $w, "height": $h, "text": $text, "color": $col}]')"
  else
    NODES_JSON="$(printf '%s' "$NODES_JSON" | jq \
      --arg id "$id" --arg text "$content" \
      --argjson x "$x" --argjson y "$y" --argjson w "$w" --argjson h "$h" \
      '. + [{"id": $id, "type": "text", "x": $x, "y": $y, "width": $w, "height": $h, "text": $text}]')"
  fi
}

add_file_card() {
  # args: id x y w h file_relpath [color]
  local id="$1" x="$2" y="$3" w="$4" h="$5" file="$6" color="${7:-}"
  if [ -n "$color" ]; then
    NODES_JSON="$(printf '%s' "$NODES_JSON" | jq \
      --arg id "$id" --arg file "$file" --arg col "$color" \
      --argjson x "$x" --argjson y "$y" --argjson w "$w" --argjson h "$h" \
      '. + [{"id": $id, "type": "file", "x": $x, "y": $y, "width": $w, "height": $h, "file": $file, "color": $col}]')"
  else
    NODES_JSON="$(printf '%s' "$NODES_JSON" | jq \
      --arg id "$id" --arg file "$file" \
      --argjson x "$x" --argjson y "$y" --argjson w "$w" --argjson h "$h" \
      '. + [{"id": $id, "type": "file", "x": $x, "y": $y, "width": $w, "height": $h, "file": $file}]')"
  fi
}

# Push a card into a column. Increments the column's running y.
# args: column_name id text_or_file type=text|file [color_override]
push_to_column() {
  local col="$1" id="$2" content="$3" ctype="$4" color_override="${5:-}"
  local x y color h
  case "$col" in
    pending)  x=$COL_PENDING_X ; y=$PENDING_Y ; color="${color_override:-$COL_PENDING_COLOR}" ;;
    inprog)   x=$COL_INPROG_X  ; y=$INPROG_Y  ; color="${color_override:-$COL_INPROG_COLOR}"  ;;
    blocked)  x=$COL_BLOCKED_X ; y=$BLOCKED_Y ; color="${color_override:-$COL_BLOCKED_COLOR}" ;;
    done)     x=$COL_DONE_X    ; y=$DONE_Y    ; color="${color_override:-$COL_DONE_COLOR}"    ;;
    *) return 1 ;;
  esac

  # adjust h by content length (rough heuristic for text cards)
  if [ "$ctype" = "text" ]; then
    local lines
    lines="$(printf '%s' "$content" | awk 'BEGIN{n=0} {n++} END{print n}')"
    h=$((CARD_H_DEFAULT + lines * 12))
    [ "$h" -gt 320 ] && h=320
    add_text_card "$id" "$x" "$y" "$CARD_W" "$h" "$content" "$color"
  else
    h=180
    add_file_card "$id" "$x" "$y" "$CARD_W" "$h" "$content" "$color"
  fi

  # advance stacking y
  case "$col" in
    pending) PENDING_Y=$((y + h + CARD_GAP_Y)) ;;
    inprog)  INPROG_Y=$((y + h + CARD_GAP_Y)) ;;
    blocked) BLOCKED_Y=$((y + h + CARD_GAP_Y)) ;;
    done)    DONE_Y=$((y + h + CARD_GAP_Y)) ;;
  esac
}

slug() {
  printf '%s' "$1" | tr -cs '[:alnum:]_-' '_' | cut -c1-40
}

# ---------- column headers ----------
add_text_card "hdr-pending" "$COL_PENDING_X" "$HEADER_Y" "$CARD_W" "$COL_H_HEADER" \
  "# ${COL_PENDING_LABEL}\n*${NOW}*"
add_text_card "hdr-inprog"  "$COL_INPROG_X"  "$HEADER_Y" "$CARD_W" "$COL_H_HEADER" \
  "# ${COL_INPROG_LABEL}" "$COL_INPROG_COLOR"
add_text_card "hdr-blocked" "$COL_BLOCKED_X" "$HEADER_Y" "$CARD_W" "$COL_H_HEADER" \
  "# ${COL_BLOCKED_LABEL}" "$COL_BLOCKED_COLOR"
add_text_card "hdr-done"    "$COL_DONE_X"    "$HEADER_Y" "$CARD_W" "$COL_H_HEADER" \
  "# ${COL_DONE_LABEL}" "$COL_DONE_COLOR"

# ---------- classify cards ----------

# === tmux sessions: idle 분 단위로 분류 ===
# - <10분 활동: In Progress
# - 10분 ~ 60분: In Progress (희미한 회색 X — 그대로 5)
# - >60분: Blocked (3=노랑)
if command -v tmux >/dev/null 2>&1; then
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    # tmux ls 출력: "name: 3 windows (created ...) [192x49]"
    sess_name="$(printf '%s' "$line" | cut -d: -f1)"
    sess_slug="$(slug "$sess_name")"
    node_id="tmux-${sess_slug}"

    # idle 시간: tmux display-message -t <name> -p '#{session_activity}' (unix epoch)
    activity_epoch="$(tmux display-message -t "$sess_name" -p '#{session_activity}' 2>/dev/null || echo 0)"
    now_epoch="$(date +%s)"
    idle_sec=$((now_epoch - ${activity_epoch:-0}))
    idle_min=$((idle_sec / 60))

    # 세션에 active agent 있으면 그 리스트도 카드에 inline
    roles_block="$(agents_for_session "$sess_name")"
    card_text="## 🖥 ${sess_name}\n\nidle: ${idle_min}m\n\`${line}\`${roles_block}"
    if [ "$idle_min" -gt 60 ]; then
      push_to_column blocked "$node_id" "$card_text" text
    else
      push_to_column inprog "$node_id" "$card_text" text
    fi
  done < <(tmux ls 2>/dev/null || true)
fi

# === Paperclip routines: status별 분류 ===
ROUTINES_RAW="$(curl -fs "${PAPERCLIP_URL}/api/routines/active" 2>/dev/null || true)"
if [ -n "$ROUTINES_RAW" ] && [ "$ROUTINES_RAW" != "[]" ] && [ "$ROUTINES_RAW" != "null" ]; then
  # iterate routines
  while IFS=$'\t' read -r r_id r_company r_name r_status r_next r_last; do
    [ -z "$r_id" ] && continue
    rid_slug="$(slug "$r_id")"
    node_id="routine-${rid_slug}"
    card_text="## ⚙ ${r_company}/${r_name}\n\nstatus: ${r_status}\nnext: ${r_next}\nlast: ${r_last}"

    case "$r_status" in
      running|executing|in_progress)
        push_to_column inprog "$node_id" "$card_text" text ;;
      pending|scheduled|waiting)
        push_to_column pending "$node_id" "$card_text" text ;;
      blocked|failed|error|timeout)
        push_to_column blocked "$node_id" "$card_text" text "1" ;;   # red
      done|completed|success)
        # done인데 last가 오늘이면 Done Today 컬럼
        if printf '%s' "$r_last" | grep -q "$TODAY"; then
          push_to_column 'done' "$node_id" "$card_text" text
        fi
        # 어제 이전 done은 노출 안 함
        ;;
      *)
        push_to_column pending "$node_id" "$card_text" text ;;
    esac
  done < <(printf '%s' "$ROUTINES_RAW" | jq -r '.[] | [.id, .company // "?", .name // .id, .status // "unknown", .next_run // "?", .last_run // "?"] | @tsv' 2>/dev/null || true)
fi

# === Board approvals: 항상 Pending에 빨강 강조 ===
APPROVALS_RAW="$(curl -fs "${PAPERCLIP_URL}/api/approvals/pending" 2>/dev/null || true)"
if [ -n "$APPROVALS_RAW" ] && [ "$APPROVALS_RAW" != "[]" ] && [ "$APPROVALS_RAW" != "null" ]; then
  while IFS=$'\t' read -r a_id a_title a_requested; do
    [ -z "$a_id" ] && continue
    aid_slug="$(slug "$a_id")"
    node_id="approval-${aid_slug}"
    card_text="## ⏳ Approval Needed\n\n**${a_title}**\n\nrequested: ${a_requested}\nid: ${a_id}"
    push_to_column pending "$node_id" "$card_text" text "1"   # red
  done < <(printf '%s' "$APPROVALS_RAW" | jq -r '.[] | [.id, .title // .description // "(no title)", .requested_at // "?"] | @tsv' 2>/dev/null || true)
fi

# === Today vault notes: Done Today 컬럼에 type=file 카드로 (드릴다운) ===
while IFS= read -r f; do
  [ -z "$f" ] && continue
  note_rel="${f#"${VAULT_ROOT}/"}"
  # Mission Control 자기 자신은 제외
  case "$note_rel" in
    00-Mission-Control/*) continue ;;
  esac
  note_id="vault-$(slug "$note_rel")"
  push_to_column 'done' "$note_id" "$note_rel" file
done < <(find "${VAULT_ROOT}" -newermt "${TODAY}" -name "*.md" -type f 2>/dev/null | sort)

# === 전체 active agent roster (In Progress 상단) ===
# tmux 세션에 binding 안 된 agent들도 보이게 — 예: Claude Code subagent가 별도 process로 돌 때
if [ -f "$AGENTS_STATE_JSON" ]; then
  roster_text="$(jq -r '
    .agents
    | map(select(.status == "active"))
    | if length == 0 then "" else
        "## 🤖 Active Agent Roster (\(length))\n\n" +
        (group_by(.harness)
         | map(
             "**\(.[0].harness)** (\(length))\n" +
             (map("- \(.icon // "🤖") \(.name) — \(.role // "?")" +
                  (if .task != "" and .task != null then " · `\(.task | .[0:40])`" else "" end))
              | join("\n"))
           )
         | join("\n\n"))
      end
  ' "$AGENTS_STATE_JSON" 2>/dev/null)"
  if [ -n "$roster_text" ]; then
    push_to_column inprog "agent-roster" "$roster_text" text
  fi
fi

# === 최근 router 결정 — In Progress 하단에 ===
ROUTER_LOG="${HOME}/.hermes/logs/router.log"
if [ -f "$ROUTER_LOG" ]; then
  router_tail="$(tail -n 5 "$ROUTER_LOG" 2>/dev/null || true)"
  if [ -n "$router_tail" ]; then
    push_to_column inprog "router-recent" "## 🔄 최근 라우팅 결정 (5)\n\n${router_tail}" text
  fi
fi

# === 에러 — Blocked 컬럼 하단에 (red) ===
ERROR_LOG="${HOME}/.hermes/logs/error.log"
if [ -f "$ERROR_LOG" ]; then
  err_tail="$(tail -n 5 "$ERROR_LOG" 2>/dev/null || true)"
  if [ -n "$err_tail" ]; then
    push_to_column blocked "errors-recent" "## 🚨 최근 에러 (5)\n\n${err_tail}" text "1"
  fi
fi

# === 빈 컬럼이면 placeholder ===
[ "$PENDING_Y" -eq "$FIRST_CARD_Y" ] && push_to_column pending "empty-pending" "_대기 중인 작업 없음_" text
[ "$INPROG_Y"  -eq "$FIRST_CARD_Y" ] && push_to_column inprog  "empty-inprog"  "_진행 중인 작업 없음_" text
[ "$BLOCKED_Y" -eq "$FIRST_CARD_Y" ] && push_to_column blocked "empty-blocked" "_막힌 작업 없음_" text
[ "$DONE_Y"    -eq "$FIRST_CARD_Y" ] && push_to_column 'done'  "empty-done"    "_오늘 완료된 항목 없음_" text

# ---------- write canvas file ----------
mkdir -p "$(dirname "${CANVAS_PATH}")"
jq -n \
  --argjson nodes "$NODES_JSON" \
  --argjson edges "$EDGES_JSON" \
  '{"nodes": $nodes, "edges": $edges}' > "${CANVAS_PATH}"
