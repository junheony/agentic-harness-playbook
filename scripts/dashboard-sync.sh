#!/usr/bin/env bash
# Mac cron이 매분 호출. Linux dashboard 결과를 Mac vault로 sync.
# 두 디렉토리 sync:
#   <REMOTE>:<REMOTE_BASE>/00-Mission-Control/ → ~/dashboard-mirror/   (vault 안 symlink로 노출)
#   <REMOTE>:<REMOTE_BASE>/03-Daily-Reports/   → ~/dashboard-mirror-reports/ (vault 밖 + symlink)
# vault의 다른 폴더와 충돌 방지 위해 03-Daily-Reports 분리.
#
# 환경변수:
#   REMOTE        SSH alias (default: linux)
#   REMOTE_BASE   원격 dashboard 출력 루트. 원격 HOME 기준 상대 경로 또는 절대 경로.
#                 (default: dashboard-output — vault-mirror-sync.sh의 REMOTE_TARGET과 같은 컨벤션)

set -uo pipefail

REMOTE="${REMOTE:-linux}"
REMOTE_BASE="${REMOTE_BASE:-dashboard-output}"
LOG="$HOME/.dashboard-sync.log"
LOCKDIR="$HOME/.dashboard-sync.lockdir"

if ! mkdir "$LOCKDIR" 2>/dev/null; then exit 0; fi
trap 'rmdir "$LOCKDIR" 2>/dev/null || true' EXIT

{
  echo "─── $(date '+%Y-%m-%d %H:%M:%S') ───"

  # (1) Mission Control (Canvas + md) → ~/dashboard-mirror
  rsync -az --delete -e 'ssh -o ConnectTimeout=8' \
    "${REMOTE}:${REMOTE_BASE}/00-Mission-Control/" \
    "$HOME/dashboard-mirror/" 2>&1 \
    && echo "✓ Mission Control synced" \
    || echo "✗ MC rsync 실패"

  # (2) Daily Reports → ~/dashboard-mirror-reports (vault 밖) + symlink
  mkdir -p "$HOME/dashboard-mirror-reports"
  rsync -az --delete -e 'ssh -o ConnectTimeout=8' \
    "${REMOTE}:${REMOTE_BASE}/03-Daily-Reports/" \
    "$HOME/dashboard-mirror-reports/" 2>&1 \
    && echo "✓ Daily Reports synced" \
    || echo "✗ Reports rsync 실패"

  # (3) Quant cycles state → 같은 reports 폴더에
  mkdir -p "$HOME/dashboard-mirror-reports/quant-cycles"
  rsync -az --delete -e 'ssh -o ConnectTimeout=8' \
    "${REMOTE}:${REMOTE_BASE}/quant-cycles/" \
    "$HOME/dashboard-mirror-reports/quant-cycles/" 2>&1 \
    && echo "✓ Quant cycles synced"

} >> "$LOG" 2>&1
