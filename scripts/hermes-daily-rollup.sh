#!/usr/bin/env bash
# 매일 21시 KST 호출. 오늘 활동 요약을 Hermes Memory에 한 줄 append.
set -uo pipefail
export PATH="$HOME/.local/bin:$HOME/.opencode/bin:/usr/local/bin:/usr/bin:/bin"

TODAY=$(date +%Y-%m-%d)
DATE_NUM=$(date +%Y%m%d)
SESSION_COUNT=$(find ~/.hermes/sessions -name "session_${DATE_NUM}_*.json" 2>/dev/null | wc -l | tr -d " ")
DASHBOARD_OK=$([ -f ~/dashboard-output/00-Mission-Control/dashboard.md ] && echo 1 || echo 0)

# 오늘 git activity (서버에서 agent commit한 거)
AGENT_COMMITS=0
for repo in ${AGENT_REPOS:-~/dev/project-a ~/dev/project-b ~/dev/project-c}; do
  [ -d "$repo/.git" ] || continue
  COUNT=$(cd "$repo" && git log --since="$TODAY 00:00" --oneline 2>/dev/null | wc -l | tr -d " ")
  AGENT_COMMITS=$((AGENT_COMMITS + COUNT))
done

SUMMARY="sessions=${SESSION_COUNT}, agent_commits=${AGENT_COMMITS}, dashboard=${DASHBOARD_OK} (auto rollup)"
bash ~/agentic-harness/scripts/hermes-feedback.sh daily-rollup "${SUMMARY}"
