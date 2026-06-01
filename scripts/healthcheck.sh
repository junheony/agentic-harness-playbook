#!/usr/bin/env bash
# healthcheck.sh
# 모든 컴포넌트 상태 점검. cron으로 정기 실행 가능 (예: 5분마다).
# 실패 시 Telegram #ops 토픽에 알람 (ALERT_ON_FAILURE=true 필요).
#
# 환경변수:
#   ALERT_ON_FAILURE   FAIL 발생 시 Telegram 알람 (default: false)
#   TELEGRAM_OPS_CHAT_ID   알람 대상 chat_id
#   WORKDIR_ROOT       작업 루트 디스크 사용량 체크 대상 (default: ~/dev)

set -uo pipefail

ALERT_ON_FAILURE=${ALERT_ON_FAILURE:-false}
WORKDIR_ROOT="${WORKDIR_ROOT:-$HOME/dev}"

# Telegram 토큰: OS 네이티브 시크릿 스토어 우선, env fallback
if [[ "$OSTYPE" == "darwin"* ]]; then
  TG_BOT_TOKEN=$(security find-generic-password -a hermes -s telegram-bot-token -w 2>/dev/null || echo "${TELEGRAM_BOT_TOKEN:-}")
elif command -v secret-tool >/dev/null 2>&1; then
  TG_BOT_TOKEN=$(secret-tool lookup service hermes account telegram-bot-token 2>/dev/null || echo "${TELEGRAM_BOT_TOKEN:-}")
elif command -v pass >/dev/null 2>&1; then
  TG_BOT_TOKEN=$(pass show hermes/telegram-bot-token 2>/dev/null | head -1 || echo "${TELEGRAM_BOT_TOKEN:-}")
else
  TG_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
fi
TG_CHAT_ID="${TELEGRAM_OPS_CHAT_ID:-}"

if [[ -t 1 ]]; then
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; NC=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; NC=''
fi

PASS=0; FAIL=0; WARN=0
FAILED_ITEMS=()

# 크로스 플랫폼 stat (8진 권한)
stat_perm() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    stat -f %A "$1" 2>/dev/null
  else
    stat -c %a "$1" 2>/dev/null
  fi
}

check() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    printf '%s✓%s %s\n' "$GREEN" "$NC" "$name"
    PASS=$((PASS + 1))
  else
    printf '%s✗%s %s\n' "$RED" "$NC" "$name"
    FAIL=$((FAIL + 1))
    FAILED_ITEMS+=("$name")
  fi
}

warn_check() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    printf '%s✓%s %s\n' "$GREEN" "$NC" "$name"
    PASS=$((PASS + 1))
  else
    printf '%s⚠%s %s (optional)\n' "$YELLOW" "$NC" "$name"
    WARN=$((WARN + 1))
  fi
}

# ── mini-router 활성 여부 감지 ──
# Hermes 없이 mini-router만 쓰는 구성(mini-router-only)을 지원하기 위해,
# mini-router가 살아있으면 Hermes 관련 항목은 FAIL 대신 WARN으로 처리한다.
MINI_ROUTER_ACTIVE=false
if systemctl --user is-active mini-router.service >/dev/null 2>&1; then
  MINI_ROUTER_ACTIVE=true
elif pgrep -f 'mini-router/bot\.py' >/dev/null 2>&1; then
  MINI_ROUTER_ACTIVE=true
elif launchctl list 2>/dev/null | grep -q 'com\.user\.mini-router'; then
  MINI_ROUTER_ACTIVE=true
fi

# hermes_check: mini-router 활성 시 Hermes 부재는 WARN, 아니면 기존대로 FAIL
hermes_check() {
  if $MINI_ROUTER_ACTIVE; then
    warn_check "$@"
  else
    check "$@"
  fi
}

echo "═══════════════════════════════════════════════════════"
echo " Agentic Harness Healthcheck — $(date)"
echo "═══════════════════════════════════════════════════════"

check_perm() {
  local file="$1" expected="$2"
  [[ ! -f "$file" ]] && return 0
  local actual
  actual=$(stat_perm "$file")
  [[ "$actual" == "$expected" ]]
}

echo
echo "── OAuth & Credentials ──"
# mini-router-only 구성에선 Codex/opencode 트랙이 없을 수 있음 → 그 경우 WARN으로 강등
hermes_check "Codex OAuth"        codex login status
check "Codex auth file 권한 600"  check_perm ~/.codex/auth.json 600
check "Hermes .env 권한 600"      check_perm ~/.hermes/.env 600

if [[ "$OSTYPE" == "darwin"* ]]; then
  warn_check "Telegram bot token (Keychain)" \
    bash -c 'security find-generic-password -a hermes -s telegram-bot-token -w >/dev/null 2>&1'
elif command -v secret-tool >/dev/null 2>&1; then
  warn_check "Telegram bot token (secret-tool)" \
    bash -c 'secret-tool lookup service hermes account telegram-bot-token >/dev/null 2>&1'
elif command -v pass >/dev/null 2>&1; then
  warn_check "Telegram bot token (pass)" \
    bash -c 'pass show hermes/telegram-bot-token >/dev/null 2>&1'
fi

echo
echo "── Hermes 5 Pillars ──"
hermes_check "SOUL.md 존재"             test -f ~/.hermes/SOUL.md
hermes_check "USER.md 존재"             test -f ~/.hermes/USER.md
hermes_check "MEMORY.md 존재"           test -f ~/.hermes/MEMORY.md
hermes_check "skills/ 디렉토리"         test -d ~/.hermes/skills

# 용량 체크 (consolidate 임박?)
check_size_threshold() {
  local file="$1" limit="$2" label="$3"
  [[ ! -f "$file" ]] && return 0
  local bytes
  bytes=$(wc -c <"$file")
  if (( bytes > limit * 80 / 100 )); then
    printf '%s⚠%s %s %s/%s bytes (consolidate 임박)\n' "$YELLOW" "$NC" "$label" "$bytes" "$limit"
    WARN=$((WARN + 1))
  else
    printf '%s✓%s %s %s/%s bytes\n' "$GREEN" "$NC" "$label" "$bytes" "$limit"
    PASS=$((PASS + 1))
  fi
}

check_size_threshold ~/.hermes/MEMORY.md 2200 "MEMORY.md"
check_size_threshold ~/.hermes/USER.md 1375 "USER.md"

echo
echo "── 프로세스 / 서비스 관리자 ──"

# mini-router 자체 헬스체크 (Telegram → tmux forwarder)
if $MINI_ROUTER_ACTIVE; then
  printf '%s✓%s mini-router 활성 (Telegram → tmux forwarder)\n' "$GREEN" "$NC"
  PASS=$((PASS + 1))
else
  printf '%s⚠%s mini-router 비활성 (Hermes gateway 사용 시 무시 OK)\n' "$YELLOW" "$NC"
  WARN=$((WARN + 1))
fi

if [[ "$OSTYPE" == "darwin"* ]]; then
  hermes_check "hermes gateway (launchd)"   bash -c 'launchctl list | grep -q hermes'
  warn_check "paperclip server (launchd)" bash -c 'launchctl list | grep -q paperclip'
else
  hermes_check "hermes gateway (systemd user)" \
    bash -c 'systemctl --user is-active hermes-gateway >/dev/null 2>&1'
  warn_check "linger 활성 (부팅 시 user unit)" \
    bash -c 'loginctl show-user "$USER" 2>/dev/null | grep -q "Linger=yes"'
  warn_check "Tailscale 활성 (Linux)" \
    bash -c 'tailscale status >/dev/null 2>&1'
fi
hermes_check "hermes 프로세스 실행 중"  pgrep -f "hermes gateway"

echo
echo "── MCP 연결 ──"
if command -v claude >/dev/null 2>&1; then
  hermes_check "Claude Code: hermes MCP" \
    bash -c 'claude mcp list 2>/dev/null | grep -qE "^hermes.*Connected"'
  warn_check "Claude Code: postgres MCP" \
    bash -c 'claude mcp list 2>/dev/null | grep -qE "^postgres.*Connected"'
  warn_check "Claude Code: paperclip MCP" \
    bash -c 'claude mcp list 2>/dev/null | grep -qE "^paperclip.*Connected"'
  warn_check "Claude Code: obsidian MCP" \
    bash -c 'claude mcp list 2>/dev/null | grep -qE "^obsidian.*Connected"'
else
  printf '%s⚠%s claude CLI 없음 — MCP 체크 스킵\n' "$YELLOW" "$NC"
  WARN=$((WARN + 1))
fi

echo
echo "── Network / External ──"
warn_check "Tailscale 활성" bash -c 'tailscale status >/dev/null 2>&1'
PAPERCLIP_URL="${PAPERCLIP_URL:-http://localhost:3100}"
OBSIDIAN_URL="${OBSIDIAN_URL:-http://localhost:22360}"
warn_check "Paperclip API (${PAPERCLIP_URL})" \
  bash -c "curl -fs -m 2 ${PAPERCLIP_URL}/api/health"
warn_check "Obsidian MCP (${OBSIDIAN_URL})" \
  bash -c "curl -fs -m 2 ${OBSIDIAN_URL}/health || curl -fs -m 2 ${OBSIDIAN_URL}/"

echo
echo "── Skills / Settings ──"
# mini-router-only 구성에선 Claude Code 메서돌로지 스킬이 없을 수 있음 → WARN 강등
hermes_check "Superpowers (Claude Code)" \
  bash -c 'ls ~/.claude/skills/superpowers-source 2>/dev/null || ls ~/.claude/plugins/superpowers 2>/dev/null'
warn_check "omo 설정"             test -f ~/.config/opencode/oh-my-openagent.jsonc
warn_check "Router SKILL.md"      test -f ~/.hermes/skills/router/SKILL.md
warn_check "playbook-override SKILL.md" \
  bash -c 'test -f ~/.config/superpowers/skills/playbook-override/SKILL.md || test -f ~/.claude/skills/playbook-override/SKILL.md'

echo
echo "── 디스크 / 로그 ──"
if [[ -d ~/.hermes/logs ]]; then
  LOG_MB=$(du -sm ~/.hermes/logs 2>/dev/null | cut -f1)
  if (( ${LOG_MB:-0} > 500 )); then
    printf '%s⚠%s Hermes 로그 %sMB — 로테이션 필요\n' "$YELLOW" "$NC" "$LOG_MB"
    WARN=$((WARN + 1))
  else
    printf '%s✓%s Hermes 로그 %sMB\n' "$GREEN" "$NC" "${LOG_MB:-0}"
    PASS=$((PASS + 1))
  fi
fi

# 작업 디렉토리 여유 공간 (WORKDIR_ROOT)
if [[ -d "$WORKDIR_ROOT" ]]; then
  AVAIL=$(df -h "$WORKDIR_ROOT" | tail -1 | awk '{print $4}')
  USE_PCT=$(df -P "$WORKDIR_ROOT" | tail -1 | awk '{print $5}' | tr -d '%')
  if (( ${USE_PCT:-0} > 90 )); then
    printf '%s✗%s %s %s%% used (%s avail) — 공간 부족\n' "$RED" "$NC" "$WORKDIR_ROOT" "$USE_PCT" "$AVAIL"
    FAIL=$((FAIL + 1))
    FAILED_ITEMS+=("disk-full:$WORKDIR_ROOT")
  else
    printf '%s✓%s %s %s%% used (%s avail)\n' "$GREEN" "$NC" "$WORKDIR_ROOT" "$USE_PCT" "$AVAIL"
    PASS=$((PASS + 1))
  fi
fi

echo
echo "═══════════════════════════════════════════════════════"
printf ' 결과: %sPASS %d%s | %sWARN %d%s | %sFAIL %d%s\n' \
  "$GREEN" "$PASS" "$NC" "$YELLOW" "$WARN" "$NC" "$RED" "$FAIL" "$NC"
echo "═══════════════════════════════════════════════════════"

# URL-encode 도우미 (Telegram body 안전화)
urlencode() {
  local string="$1" encoded='' i c
  for (( i=0; i<${#string}; i++ )); do
    c="${string:i:1}"
    case "$c" in
      [a-zA-Z0-9.~_-]) encoded+="$c" ;;
      *) printf -v c '%%%02X' "'$c"; encoded+="$c" ;;
    esac
  done
  printf '%s' "$encoded"
}

if (( FAIL > 0 )) && $ALERT_ON_FAILURE && [[ -n "$TG_BOT_TOKEN" && -n "$TG_CHAT_ID" ]]; then
  RAW_MSG=$'\xF0\x9F\x9A\xA8 Agentic Harness Healthcheck FAIL\n\nFailed: '"${FAILED_ITEMS[*]}"$'\nHost: '"$(hostname)"$'\nTime: '"$(date +%H:%M)"
  ENC=$(urlencode "$RAW_MSG")
  curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${TG_CHAT_ID}" \
    --data "text=${ENC}" \
    >/dev/null || true
fi

# Exit code: FAIL > 0 → 1
(( FAIL == 0 ))
