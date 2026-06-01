#!/usr/bin/env bash
# tmux-overview.sh — TUI session aggregator
# viddy가 있으면 viddy -n 5 -d 안에서 동작, 없으면 단독 실행.
# gum이 있으면 double-border 포맷, 없으면 평문.
# 80x24 기준 한 페이지 출력.
set -uo pipefail

# ---------- color codes ----------
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
GRAY='\033[0;37m'
BOLD='\033[1m'
RESET='\033[0m'

NOW_EPOCH="$(date +%s)"

# ---------- render core ----------
render() {
  local HAS_GUM=false
  command -v gum >/dev/null 2>&1 && HAS_GUM=true

  local lines=""
  lines+="$(printf '%b' "${BOLD}tmux sessions — $(date '+%Y-%m-%d %H:%M:%S')${RESET}")"$'\n'
  lines+="$(printf '%-24s %-20s %-12s %s\n' 'SESSION' 'LAST ACTIVITY' 'STATUS' 'LAST OUTPUT')"
  lines+="$(printf -- '%.0s─' {1..80})"$'\n'

  if ! command -v tmux >/dev/null 2>&1; then
    lines+="tmux 명령어 없음"$'\n'
  else
    local sessions
    sessions="$(tmux ls -F '#{session_name}|#{session_activity}|#{session_attached}' 2>/dev/null)" || {
      lines+="tmux 서버 미실행"$'\n'
      if "$HAS_GUM"; then
        printf '%s' "$lines" | gum style --border double --padding "1 2"
      else
        printf '%s\n' "$lines"
      fi
      return
    }

    local count=0
    while IFS='|' read -r sname sactivity sattached; do
      [ -z "$sname" ] && continue
      count=$((count + 1))
      # cap at ~20 sessions to fit 24 lines
      if [ "$count" -gt 20 ]; then
        lines+="… (추가 세션 있음, tmux ls 로 확인)"$'\n'
        break
      fi

      # idle time
      local idle_secs=$(( NOW_EPOCH - sactivity ))
      local idle_str
      if   [ "$idle_secs" -lt  60 ]; then idle_str="방금"
      elif [ "$idle_secs" -lt 3600 ]; then idle_str="$((idle_secs/60))분 전"
      else                                  idle_str="$((idle_secs/3600))시간 전"
      fi

      # color
      local color="$GREEN"
      [ "$idle_secs" -ge  600 ] && color="$YELLOW"
      [ "$idle_secs" -ge 3600 ] && color="$GRAY"

      # status label
      local status_label
      if [ "$sattached" -gt 0 ]; then
        status_label="attached"
        color="$GREEN"
      else
        status_label="detached"
      fi

      # last 5 lines of last pane (first window, first pane)
      local pane_out
      pane_out="$(tmux capture-pane -pt "${sname}" -S -5 2>/dev/null | tr '\n' ' ' | sed 's/  */ /g; s/^ //; s/ $//')" || pane_out="(캡처 불가)"
      # truncate to 25 chars for single-line display
      pane_out="${pane_out:0:25}"

      lines+="$(printf '%b%-24s %-20s %-12s %s%b\n' \
        "$color" \
        "${sname:0:22}" \
        "${idle_str:0:18}" \
        "${status_label}" \
        "${pane_out}" \
        "$RESET")"$'\n'
    done <<< "$sessions"

    [ "$count" -eq 0 ] && lines+="활성 세션 없음"$'\n'
  fi

  if "$HAS_GUM"; then
    printf '%s' "$lines" | gum style --border double --padding "1 2"
  else
    printf '%s\n' "$lines"
  fi
}

# ---------- entry point ----------
# If called as "tmux-overview.sh --watch" it self-invokes with viddy
if [ "${1:-}" = "--watch" ]; then
  if command -v viddy >/dev/null 2>&1; then
    exec viddy -n 5 -d -- bash "$0"
  else
    # fallback: simple loop
    while true; do
      clear
      render
      sleep 5
    done
  fi
else
  render
fi
