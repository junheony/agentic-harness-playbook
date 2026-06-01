#!/usr/bin/env bash
# Populate TELEGRAM_ALLOWED_USERS / TELEGRAM_ALLOWED_CHATS from recent bot updates.

set -euo pipefail

ENV_DIR="${HOME}/.hermes"
ENV_FILE="${ENV_DIR}/.env"

mkdir -p "$ENV_DIR"
touch "$ENV_FILE"
chmod 600 "$ENV_FILE"

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

if [[ -z "$token" ]]; then
  echo "Telegram token missing. Run ./scripts/install-mini-router-macos.sh interactively first." >&2
  exit 1
fi

updates="$(curl -fsS "https://api.telegram.org/bot${token}/getUpdates?limit=50&timeout=1")"

users="$(printf '%s' "$updates" | jq -r '.result[]?.message?.from?.id // empty' | sort -u)"
chats="$(printf '%s' "$updates" | jq -r '.result[]?.message?.chat?.id // empty' | sort -u)"
groups="$(printf '%s\n' "$chats" | grep '^-' || true)"

if [[ -z "$users" ]]; then
  echo "No updates found. Send /start to your bot in Telegram, then rerun this script." >&2
  exit 1
fi

default_user="$(printf '%s\n' "$users" | head -1)"
default_chat="$(printf '%s\n' "$groups" | head -1)"

echo "Recent users:"
printf '  %s\n' $users
echo
echo "Recent chats:"
printf '  %s\n' $chats
echo

allowed_user="${TELEGRAM_ALLOWED_USERS:-$default_user}"
allowed_chat="${TELEGRAM_ALLOWED_CHATS:-$default_chat}"

if [[ -t 0 ]]; then
  read -rp "Allowed user_id [${allowed_user}]: " input_user
  allowed_user="${input_user:-$allowed_user}"
  read -rp "Allowed chat_id [${allowed_chat}]: " input_chat
  allowed_chat="${input_chat:-$allowed_chat}"
fi

set_env_key() {
  local key="$1" value="$2" tmp
  tmp="$(mktemp)"
  grep -vE "^${key}=" "$ENV_FILE" > "$tmp" 2>/dev/null || true
  printf '%s=%s\n' "$key" "$value" >> "$tmp"
  mv "$tmp" "$ENV_FILE"
}

set_env_key TELEGRAM_ALLOWED_USERS "$allowed_user"
set_env_key TELEGRAM_ALLOWED_CHATS "$allowed_chat"
set_env_key WORKDIR_ROOT "${WORKDIR_ROOT:-$HOME/dev}"
set_env_key TMUX_DEFAULT_SESSION "${TMUX_DEFAULT_SESSION:-oc-default}"
set_env_key TOPIC_MAP_PATH "${TOPIC_MAP_PATH:-$HOME/.hermes/topic_map.yaml}"
set_env_key OPENCODE_CMD "${OPENCODE_CMD:-opencode}"
set_env_key CLAUDE_CMD "${CLAUDE_CMD:-claude}"
chmod 600 "$ENV_FILE"

echo "Updated $ENV_FILE"
echo "  TELEGRAM_ALLOWED_USERS=$allowed_user"
echo "  TELEGRAM_ALLOWED_CHATS=$allowed_chat"

