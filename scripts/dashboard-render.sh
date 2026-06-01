#!/usr/bin/env bash
# dashboard-render.sh — Mission Control markdown rollup
# 매분 호출되어 dashboard.md 갱신. set -e 금지 — curl 실패도 정상 흐름.
set -uo pipefail

MISSION_CONTROL_PATH="${MISSION_CONTROL_PATH:-${HOME}/Documents/SecondBrain/00-Mission-Control/dashboard.md}"
PAPERCLIP_URL="${PAPERCLIP_URL:-http://localhost:3100}"
VAULT_ROOT="${VAULT_ROOT:-${HOME}/Documents/SecondBrain}"
AGENTS_STATE_JSON="${AGENTS_STATE_JSON:-${HOME}/.hermes/agents-state.json}"

NOW="$(date '+%Y-%m-%d %H:%M')"

# ---------- helpers ----------
section() { printf '\n## %s\n\n' "$1"; }

# ---------- tmux sessions ----------
tmux_section() {
  section "🟢 활성 tmux 세션"
  if command -v tmux >/dev/null 2>&1 && tmux ls 2>/dev/null; then
    :
  else
    printf 'tmux 세션 없음 또는 서버 미실행\n'
  fi
}

# ---------- Paperclip routines ----------
paperclip_routines_section() {
  section "📋 Paperclip routines"
  local raw
  raw="$(curl -fs "${PAPERCLIP_URL}/api/routines/active" 2>/dev/null)" || {
    printf 'Paperclip 미실행\n'
    return
  }
  if [ -z "$raw" ]; then
    printf '활성 루틴 없음\n'
    return
  fi
  printf '%s\n' "$raw" | jq -r '.[] | "- [\(.status // "??")] \(.name // .id) — \(.schedule // "")"' 2>/dev/null \
    || printf '%s\n' "$raw"
}

# ---------- Pending Board approvals ----------
pending_approvals_section() {
  section "⏳ Pending Board approvals"
  local raw
  raw="$(curl -fs "${PAPERCLIP_URL}/api/approvals/pending" 2>/dev/null)" || {
    printf 'Paperclip 미실행\n'
    return
  }
  if [ -z "$raw" ] || [ "$raw" = "[]" ] || [ "$raw" = "null" ]; then
    printf '대기 중인 승인 없음\n'
    return
  fi
  printf '%s\n' "$raw" | jq -r '.[] | "- \(.id) | \(.title // .description // "(제목 없음)") | 요청자: \(.requester // "?")"' 2>/dev/null \
    || printf '%s\n' "$raw"
}

# ---------- Today vault notes ----------
vault_notes_section() {
  section "📊 오늘 생성된 vault 노트"
  local today
  today="$(date '+%Y-%m-%d')"
  local notes
  notes="$(find "${VAULT_ROOT}" -newermt "${today}" -name "*.md" -type f 2>/dev/null | sort)"
  if [ -z "$notes" ]; then
    printf '오늘 생성된 노트 없음\n'
    return
  fi
  while IFS= read -r f; do
    # vault-root 기준 상대 경로
    printf -- '- %s\n' "${f#"${VAULT_ROOT}/"}"
  done <<< "$notes"
}

# ---------- Recent errors ----------
error_log_section() {
  section "🚨 최근 에러"
  local logfile="${HOME}/.hermes/logs/error.log"
  if [ -f "$logfile" ]; then
    tail -n 10 "$logfile"
  else
    printf '에러 로그 없음 (%s)\n' "$logfile"
  fi
}

# ---------- Active agents ----------
agents_section() {
  section "🤖 Active Agents"
  if [ ! -f "$AGENTS_STATE_JSON" ]; then
    printf 'agents-state.json 없음 — `bash scripts/agents-state.sh` 먼저 실행 또는 cron 등록\n'
    return
  fi
  local count
  count="$(jq -r '.agents | map(select(.status == "active")) | length' "$AGENTS_STATE_JSON" 2>/dev/null || echo 0)"
  if [ "${count:-0}" -eq 0 ]; then
    printf '활성 agent 없음 (지난 %s분)\n' "$(jq -r '.active_window_minutes // 30' "$AGENTS_STATE_JSON")"
    return
  fi
  jq -r '
    .agents
    | map(select(.status == "active"))
    | group_by(.harness)
    | map(
        "**\(.[0].harness)** (\(length))\n" +
        (map("- \(.icon // "🤖") \(.name) — \(.role // "?")" +
             (if .session and .session != null then " · session: `\(.session)`" else "" end) +
             (if .task and .task != "" then " · `\(.task | .[0:60])`" else "" end))
         | join("\n"))
      )
    | join("\n\n")
  ' "$AGENTS_STATE_JSON" 2>/dev/null
}

# ---------- Recent router decisions ----------
router_log_section() {
  section "🔄 최근 라우팅 결정"
  local logfile="${HOME}/.hermes/logs/router.log"
  if [ -f "$logfile" ]; then
    tail -n 5 "$logfile"
  else
    printf '라우터 로그 없음 (%s)\n' "$logfile"
  fi
}

# ---------- assemble ----------
{
  printf '# Mission Control — %s\n' "$NOW"
  agents_section
  tmux_section
  paperclip_routines_section
  pending_approvals_section
  vault_notes_section
  error_log_section
  router_log_section
} > "${MISSION_CONTROL_PATH}"
