#!/usr/bin/env bash
# Mac → Linux: vault 단방향 mirror. agent가 노트 검색/읽기만.
# Mission Control (Linux → Mac) sync와 방향 다름, 충돌 X.

set -uo pipefail

REMOTE="${REMOTE:-linux}"
LOCAL_VAULT="${LOCAL_VAULT:-$HOME/Documents/Obsidian Vault}"
REMOTE_TARGET="${REMOTE_TARGET:-/home/<user>/vault-mirror}"
LOG="$HOME/.vault-mirror-sync.log"
LOCKDIR="$HOME/.vault-mirror-sync.lockdir"

if ! mkdir "$LOCKDIR" 2>/dev/null; then exit 0; fi
trap 'rmdir "$LOCKDIR" 2>/dev/null || true' EXIT

{
  echo "─── $(date '+%Y-%m-%d %H:%M:%S') ───"
  rsync -az --delete --ignore-errors \
    --exclude='.obsidian/workspace*.json' \
    --exclude='.obsidian/cache*' \
    --exclude='.trash/' \
    --exclude='*.swp' \
    -e 'ssh -o ConnectTimeout=10' \
    "${LOCAL_VAULT}/" "${REMOTE}:${REMOTE_TARGET}/" 2>&1 \
    && echo "✓ vault mirror synced" \
    || echo "✗ rsync 실패"
} >> "$LOG"
