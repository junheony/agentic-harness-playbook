#!/usr/bin/env bash
# Mac → Linux: ~/.claude/.credentials.json 변경 시 자동 sync.
# launchd WatchPaths가 호출. omo-proxy 자동 restart로 새 token 반영.
#
# 로그: ~/.claude-creds-sync.log
# 락:   ~/.claude-creds-sync.lockdir  (macOS portable, mkdir atomic)

set -uo pipefail

REMOTE="${REMOTE:-linux}"
LOG="$HOME/.claude-creds-sync.log"
LOCKDIR="$HOME/.claude-creds-sync.lockdir"

# 동시 실행 방지 (mkdir atomic) — macOS / Linux 둘 다 동작
if ! mkdir "$LOCKDIR" 2>/dev/null; then
  echo "$(date '+%H:%M:%S') already running, skip" >> "$LOG"
  exit 0
fi
trap 'rmdir "$LOCKDIR" 2>/dev/null || true' EXIT

# 디바운스 — credentials.json이 1초 내에 여러번 write되면 마지막 것만
sleep 0.5

TS=$(date '+%Y-%m-%d %H:%M:%S')
SIZE=$(stat -f %z ~/.claude/.credentials.json 2>/dev/null || stat -c %s ~/.claude/.credentials.json 2>/dev/null || echo "?")

{
  echo "─── $TS ───"
  echo "local size=$SIZE"

  # scp (preserve perms)
  if scp -p -o ConnectTimeout=10 ~/.claude/.credentials.json "${REMOTE}:~/.claude/.credentials.json" 2>&1; then
    echo "✓ scp OK"
  else
    echo "✗ scp 실패, 5초 후 1회 재시도"
    sleep 5
    if scp -p -o ConnectTimeout=10 ~/.claude/.credentials.json "${REMOTE}:~/.claude/.credentials.json" 2>&1; then
      echo "✓ scp 재시도 OK"
    else
      echo "✗ scp 재시도 실패 — 수동 점검"
      exit 1
    fi
  fi

  # 권한 + omo-proxy restart
  if ssh -o ConnectTimeout=10 "$REMOTE" 'chmod 600 ~/.claude/.credentials.json && systemctl --user restart omo-proxy.service' 2>&1; then
    echo "✓ omo-proxy restart OK"
  else
    echo "✗ omo-proxy restart 실패"
  fi
} >> "$LOG" 2>&1
