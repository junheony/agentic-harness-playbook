#!/usr/bin/env bash
# Launchd entrypoint for mini-router on macOS.

set -euo pipefail

HARNESS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${HOME}/.hermes/.env"
LOG_DIR="${HOME}/.hermes/logs"

mkdir -p "$LOG_DIR"

if [[ -r "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

if [[ -z "${TELEGRAM_BOT_TOKEN:-}" ]] && command -v security >/dev/null 2>&1; then
  TELEGRAM_BOT_TOKEN="$(security find-generic-password -a hermes -s telegram-bot-token -w 2>/dev/null || true)"
  export TELEGRAM_BOT_TOKEN
fi

for p in "$HOME"/.nvm/versions/node/*/bin; do
  [[ -d "$p" ]] && PATH="$p:$PATH"
done

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
export TOPIC_MAP_PATH="${TOPIC_MAP_PATH:-$HOME/.hermes/topic_map.yaml}"
export WORKDIR_ROOT="${WORKDIR_ROOT:-$HOME/dev}"
export TMUX_DEFAULT_SESSION="${TMUX_DEFAULT_SESSION:-oc-default}"
export OPENCODE_CMD="${OPENCODE_CMD:-opencode}"
export CLAUDE_CMD="${CLAUDE_CMD:-claude}"

cd "$HARNESS_ROOT/mini-router"

if [[ ! -x ".venv/bin/python" ]]; then
  /usr/bin/python3 -m venv .venv
fi

".venv/bin/python" -m pip install -q --upgrade pip
".venv/bin/python" -m pip install -q 'python-telegram-bot==21.*' pyyaml
exec ".venv/bin/python" bot.py

