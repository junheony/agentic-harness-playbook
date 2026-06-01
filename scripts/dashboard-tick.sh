#!/usr/bin/env bash
# dashboard-tick.sh — 매 1분 cron tick에서 호출하는 통합 wrapper.
# agents-state 먼저 갱신 → canvas + markdown rollup 동시에.
# launchd plist / systemd timer에서 본 스크립트를 호출하면 됨 (개별 호출 X).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. dynamic agent state 갱신 (먼저 — 다른 dashboard가 이걸 읽으므로)
bash "${SCRIPT_DIR}/agents-state.sh" >/dev/null 2>&1 || true

# 2. canvas (Obsidian kanban) + markdown rollup 병렬
bash "${SCRIPT_DIR}/canvas-render.sh" >/dev/null 2>&1 &
bash "${SCRIPT_DIR}/dashboard-render.sh" >/dev/null 2>&1 &
wait

exit 0
