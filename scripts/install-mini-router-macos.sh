#!/usr/bin/env bash
# Install mini-router as a macOS LaunchAgent.

set -euo pipefail

HARNESS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_DIR="${HOME}/.hermes"
ENV_FILE="${ENV_DIR}/.env"
TOPIC_MAP="${ENV_DIR}/topic_map.yaml"
PLIST="${HOME}/Library/LaunchAgents/com.user.mini-router.plist"
LOAD=true

for arg in "$@"; do
  case "$arg" in
    --no-load) LOAD=false ;;
    -h|--help)
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
  esac
done

mkdir -p "$ENV_DIR" "$HOME/Library/LaunchAgents" "$ENV_DIR/logs"
chmod 700 "$ENV_DIR"

if [[ ! -f "$TOPIC_MAP" ]]; then
  if [[ -f "$HARNESS_ROOT/examples/configs/topic-map.example.yaml" ]]; then
    cp "$HARNESS_ROOT/examples/configs/topic-map.example.yaml" "$TOPIC_MAP"
    chmod 600 "$TOPIC_MAP"
    echo "Seeded topic map from example: $TOPIC_MAP (edit topic_id/workdir/session for your setup)"
  else
    echo "No topic map example found. Create $TOPIC_MAP manually (see docs)." >&2
  fi
fi

if ! security find-generic-password -a hermes -s telegram-bot-token >/dev/null 2>&1; then
  if [[ -t 0 ]]; then
    read -rsp "Telegram bot token from BotFather: " token
    echo
    if [[ -n "$token" ]]; then
      security add-generic-password -U -a hermes -s telegram-bot-token -w "$token" >/dev/null
      echo "Stored Telegram token in macOS Keychain."
    fi
  else
    echo "Telegram token missing. Run interactively to store it in Keychain." >&2
  fi
fi

allowed_users=""
allowed_chats=""
if [[ -f "$ENV_FILE" ]]; then
  allowed_users="$(grep -E '^TELEGRAM_ALLOWED_USERS=' "$ENV_FILE" 2>/dev/null | tail -1 | cut -d= -f2- || true)"
  allowed_chats="$(grep -E '^TELEGRAM_ALLOWED_CHATS=' "$ENV_FILE" 2>/dev/null | tail -1 | cut -d= -f2- || true)"
fi

if [[ -t 0 ]]; then
  if [[ -z "$allowed_users" ]]; then
    read -rp "Your numeric Telegram user_id: " allowed_users
  fi
  if [[ -z "$allowed_chats" ]]; then
    read -rp "Allowed supergroup chat_id, e.g. -100123... (blank ok for first DM test): " allowed_chats
  fi
fi

cat > "$ENV_FILE" <<EOF
TELEGRAM_ALLOWED_USERS=${allowed_users}
TELEGRAM_ALLOWED_CHATS=${allowed_chats}
WORKDIR_ROOT=${WORKDIR_ROOT:-${HOME}/dev}
TMUX_DEFAULT_SESSION=oc-default
TOPIC_MAP_PATH=${TOPIC_MAP}
OPENCODE_CMD=opencode
CLAUDE_CMD=claude
EOF
chmod 600 "$ENV_FILE"

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.user.mini-router</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>${HARNESS_ROOT}/scripts/mini-router-launchd.sh</string>
  </array>
  <key>WorkingDirectory</key>
  <string>${HARNESS_ROOT}</string>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>${ENV_DIR}/logs/mini-router.launchd.out.log</string>
  <key>StandardErrorPath</key>
  <string>${ENV_DIR}/logs/mini-router.launchd.err.log</string>
</dict>
</plist>
EOF

chmod +x "$HARNESS_ROOT/scripts/mini-router-launchd.sh"

if [[ "$LOAD" == true ]]; then
  launchctl bootout "gui/${UID}" "$PLIST" >/dev/null 2>&1 || true
  if launchctl bootstrap "gui/${UID}" "$PLIST" 2>/dev/null; then
    launchctl enable "gui/${UID}/com.user.mini-router" >/dev/null 2>&1 || true
    echo "Loaded LaunchAgent: com.user.mini-router"
  else
    launchctl load "$PLIST"
    echo "Loaded LaunchAgent with launchctl load: com.user.mini-router"
  fi
else
  echo "Wrote LaunchAgent but did not load: $PLIST"
fi

"$HARNESS_ROOT/scripts/mini-router-diagnose.sh" || true

