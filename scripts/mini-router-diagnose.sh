#!/usr/bin/env bash
# Safe mini-router / Telegram diagnostics. Does not print bot tokens.

set -uo pipefail

HARNESS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${HOME}/.hermes/.env"
TOPIC_MAP="${TOPIC_MAP_PATH:-$HOME/.hermes/topic_map.yaml}"

if [[ -r "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

token=""
if command -v security >/dev/null 2>&1; then
  token="$(security find-generic-password -a hermes -s telegram-bot-token -w 2>/dev/null || true)"
fi
if [[ -z "$token" ]]; then
  token="${TELEGRAM_BOT_TOKEN:-}"
fi

status() {
  printf '%-30s %s\n' "$1" "$2"
}

echo "== local =="
status "harness" "$HARNESS_ROOT"
status "$ENV_FILE" "$([[ -f "$ENV_FILE" ]] && echo yes || echo no)"
status "topic_map" "$([[ -f "$TOPIC_MAP" ]] && echo "$TOPIC_MAP" || echo no)"
status "keychain/env token" "$([[ -n "$token" ]] && echo yes || echo no)"
status "allowed_users" "$([[ -n "${TELEGRAM_ALLOWED_USERS:-}" ]] && echo yes || echo no)"
status "allowed_chats" "$([[ -n "${TELEGRAM_ALLOWED_CHATS:-}" ]] && echo yes || echo no)"

echo
echo "== deps =="
for c in python3 tmux opencode jq curl launchctl security; do
  if command -v "$c" >/dev/null 2>&1; then
    status "$c" "$(command -v "$c")"
  else
    status "$c" missing
  fi
done

echo
echo "== launchd =="
launchctl print "gui/${UID}/com.user.mini-router" 2>/dev/null | sed -n '1,45p' || echo "com.user.mini-router not loaded"

echo
echo "== telegram =="
if [[ -z "$token" ]]; then
  echo "missing token"
else
  curl -fsS "https://api.telegram.org/bot${token}/getMe" \
    | jq '{ok, id:.result.id, username:.result.username, can_join_groups:.result.can_join_groups, can_read_all_group_messages:.result.can_read_all_group_messages}' \
    || echo "getMe failed"
  curl -fsS "https://api.telegram.org/bot${token}/getWebhookInfo" \
    | jq '{ok, url:.result.url, pending_update_count:.result.pending_update_count, last_error_message:.result.last_error_message}' \
    || echo "getWebhookInfo failed"
fi

echo
echo "== latest updates =="
if [[ -n "$token" ]]; then
  curl -fsS "https://api.telegram.org/bot${token}/getUpdates?limit=10&timeout=1" \
    | jq -r '
      .result[]? |
      .message as $m |
      select($m != null) |
      [
        "update_id=\(.update_id)",
        "chat=\($m.chat.id)",
        "thread=\($m.message_thread_id // "none")",
        "from=\($m.from.id)",
        "chat_title=\($m.chat.title // $m.chat.username // "dm")"
      ] | join(" | ")
    ' \
    || true
fi

echo
echo "== logs =="
tail -60 "$HOME/.hermes/logs/mini-router.log" 2>/dev/null || true
tail -60 "$HOME/.hermes/logs/mini-router.launchd.err.log" 2>/dev/null || true

