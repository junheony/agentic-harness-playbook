#!/usr/bin/env bash
# agent-commit-push.sh
# Agent (opencode / Hermes / Claude Code) 작업 종료 시 호출해서 자동 commit + branch push.
#
# 호출 패턴:
#   agent의 post-task hook 또는 wrapper script가 호출
#   ./scripts/agent-commit-push.sh \
#       --repo ~/dev/my-app \
#       --task "gas optimization for orderbook module" \
#       --agent sisyphus
#
# 환경변수:
#   AGENT_BRANCH_PREFIX  (default: agent)
#   AGENT_AUTO_PUSH      (default: true)  false면 commit만 하고 push 안 함
#   GH_TOKEN             (optional) — git remote가 https인 경우만
#
# 동작:
#   1. repo가 깨끗하면 (변경 X) early return
#   2. 새 branch 생성: <prefix>/<sanitized-task>-<YYYYMMDD-HHMMSS>
#   3. git add -A + commit (메시지에 task / agent 이름 포함)
#   4. push origin <new-branch> (AUTO_PUSH=true 시)
#   5. (옵션) Hermes에 알람 + Telegram #ops에 push notification

set -uo pipefail

REPO=""
TASK=""
AGENT="agent"
PREFIX="${AGENT_BRANCH_PREFIX:-agent}"
AUTO_PUSH="${AGENT_AUTO_PUSH:-true}"

while [[ $# -gt 0 ]]; do
  case $1 in
    --repo) REPO="$2"; shift 2 ;;
    --task) TASK="$2"; shift 2 ;;
    --agent) AGENT="$2"; shift 2 ;;
    --no-push) AUTO_PUSH="false"; shift ;;
    -h|--help)
      sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Unknown: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$REPO" ]] && { echo "ERROR: --repo 필수" >&2; exit 1; }
[[ -z "$TASK" ]] && TASK="agent-work"

REPO="${REPO/#\~/$HOME}"
if [[ ! -d "$REPO/.git" ]]; then
  echo "ERROR: $REPO 는 git repo 아님" >&2
  exit 1
fi

cd "$REPO" || { echo "ERROR: cd $REPO 실패" >&2; exit 1; }

# 1. 변경사항 없으면 early return
if git diff --quiet && git diff --cached --quiet && [[ -z "$(git ls-files --others --exclude-standard)" ]]; then
  echo "✓ 변경사항 없음 — commit/push skip"
  exit 0
fi

# 2. branch 이름 sanitize
TASK_SLUG=$(printf '%s' "$TASK" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '-' | sed 's/^-\+//;s/-\+$//' | cut -c1-50)
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BRANCH="${PREFIX}/${TASK_SLUG}-${TIMESTAMP}"

# 3. 새 branch 체크아웃 (현재 어디서 분기되어도 안전)
ORIG_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo "HEAD")
git checkout -b "$BRANCH" 2>&1 | tail -2

# 4. commit
git add -A

# 4.5 push 전 위생 게이트 — staged diff에 개인 경로/시크릿 패턴이 있으면 중단.
#     우회(본인 책임): ALLOW_UNSCANNED_PUSH=1
if [[ "${ALLOW_UNSCANNED_PUSH:-0}" != "1" ]]; then
  # sk-/ghp_는 실키 길이({20,})로 앵커 — 짧게 두면 task-slug/disk-full/mask-* 같은 일반 단어 오탐
  LEAK_PATTERN='/Users/[a-z]+|/home/[a-z]+|BEGIN.*PRIVATE KEY|ghp_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9]{20,}|[0-9]{8,10}:AA[A-Za-z0-9_-]{30}'
  if git diff --cached -U0 | grep -Eq "$LEAK_PATTERN"; then
    echo "✗ 위생 게이트: staged diff에서 개인 경로/시크릿 의심 패턴 감지 — commit/push 중단" >&2
    echo "  감지된 라인 (최대 10줄):" >&2
    git diff --cached -U0 | grep -E "$LEAK_PATTERN" | head -10 >&2
    echo "  확인 후 정말 push하려면: ALLOW_UNSCANNED_PUSH=1 재실행" >&2
    echo "  (현재 branch: $BRANCH — staged 상태 그대로 남김)" >&2
    exit 1
  fi
fi

# user.email / user.name 없으면 agent 명의로 설정 (이 repo만)
git config user.email 2>/dev/null || git config user.email "${AGENT}@agentic-harness.local"
git config user.name 2>/dev/null || git config user.name "${AGENT} (agent)"

REPO_LABEL=$(basename "$REPO")
COMMIT_BODY="Auto-commit by ${AGENT}.

Task: ${TASK}
Repo: ${REPO_LABEL}
Branch: ${BRANCH}
Original branch: ${ORIG_BRANCH}
Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)
"

if git commit -m "${AGENT}: ${TASK}" -m "$COMMIT_BODY" 2>&1 | tail -3; then
  echo "✓ commit on branch $BRANCH"
else
  echo "✗ commit 실패"
  exit 1
fi

# 5. push (옵션)
if [[ "$AUTO_PUSH" == "true" ]]; then
  if git remote | grep -q "^origin$"; then
    if git push -u origin "$BRANCH" 2>&1 | tail -3; then
      echo "✓ pushed $BRANCH"
      # commit URL (best-effort, github only)
      REMOTE_URL=$(git remote get-url origin)
      case "$REMOTE_URL" in
        git@github.com:*) REPO_HTTP="https://github.com/${REMOTE_URL#git@github.com:}" ;;
        https://github.com/*) REPO_HTTP="$REMOTE_URL" ;;
        *) REPO_HTTP="" ;;
      esac
      REPO_HTTP="${REPO_HTTP%.git}"
      if [[ -n "$REPO_HTTP" ]]; then
        echo "  → branch: ${REPO_HTTP}/tree/${BRANCH}"
        echo "  → compare: ${REPO_HTTP}/compare/${ORIG_BRANCH}...${BRANCH}"
      fi
    else
      echo "✗ push 실패 (인증/네트워크 확인). branch는 로컬에 남음."
    fi
  else
    echo "⚠ remote 'origin' 없음 — push skip"
  fi
fi

# 6. 원래 branch로 복귀 (agent가 다음 작업에 영향 X)
git checkout "$ORIG_BRANCH" 2>&1 | tail -1

echo
echo "summary:"
echo "  agent  : $AGENT"
echo "  task   : $TASK"
echo "  branch : $BRANCH"
echo "  pushed : $AUTO_PUSH"
