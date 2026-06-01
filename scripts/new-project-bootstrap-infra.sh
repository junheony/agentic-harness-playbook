#!/usr/bin/env bash
# new-project-bootstrap-infra.sh
# Phase 0 인프라 부트스트랩: GitHub repo 생성 + 양쪽 머신 clone + 초기 commit
#
# 사용:
#   ./scripts/new-project-bootstrap-infra.sh <slug> "<brief 한 줄>"
#   ./scripts/new-project-bootstrap-infra.sh my-app "<프로젝트 한 줄 설명>"
#
# 옵션:
#   --public          GitHub repo를 public으로 생성 (기본: private)
#   --skip-clone-linux  Linux 서버 clone 생략
#   --skip-clone-mac    Mac clone 생략
#   --skip-commit       초기 commit 생략
#   --ssh-host <host>   Linux SSH alias (기본: linux)
#   --linux-dev <path>  Linux 서버 dev 디렉토리 (기본: ~/dev)
#   --mac-dev <path>    Mac 로컬 dev 디렉토리 (기본: ~/dev)
#   --github-owner <o>  GitHub 계정/org (기본: gh api user 로 자동 감지)
#   -h, --help          이 도움말 출력
#
# 환경변수:
#   GITHUB_OWNER      GitHub 계정/org (기본: gh api user 로 자동 감지)
#   LINUX_SSH_HOST    Linux SSH alias (기본: linux)
#   LINUX_DEV_DIR     Linux 서버 dev 경로 (기본: ~/dev)
#   MAC_DEV_DIR       Mac dev 경로 (기본: ~/dev)

set -uo pipefail

# ─── 색상 ─────────────────────────────────────────────
if [[ -t 1 ]]; then
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
  BLUE=$'\033[0;34m'; BOLD=$'\033[1m'; NC=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; BOLD=''; NC=''
fi

step() { echo "${BLUE}[Phase 0]${NC} ${BOLD}$*${NC}"; }
ok()   { echo "${GREEN}  ✓${NC} $*"; }
warn() { echo "${YELLOW}  !${NC} $*"; }
fail() { echo "${RED}  ✗${NC} $*" >&2; exit 1; }

# ─── 기본값 ───────────────────────────────────────────
GITHUB_OWNER="${GITHUB_OWNER:-}"
LINUX_SSH_HOST="${LINUX_SSH_HOST:-linux}"
LINUX_DEV_DIR="${LINUX_DEV_DIR:-~/dev}"
MAC_DEV_DIR="${MAC_DEV_DIR:-~/dev}"
VISIBILITY="--private"
SKIP_CLONE_LINUX=false
SKIP_CLONE_MAC=false
SKIP_COMMIT=false

# ─── 인자 파싱 ────────────────────────────────────────
SLUG=""
BRIEF=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --public)           VISIBILITY="--public"; shift ;;
    --skip-clone-linux) SKIP_CLONE_LINUX=true; shift ;;
    --skip-clone-mac)   SKIP_CLONE_MAC=true; shift ;;
    --skip-commit)      SKIP_COMMIT=true; shift ;;
    --ssh-host)         LINUX_SSH_HOST="$2"; shift 2 ;;
    --linux-dev)        LINUX_DEV_DIR="$2"; shift 2 ;;
    --mac-dev)          MAC_DEV_DIR="$2"; shift 2 ;;
    --github-owner)     GITHUB_OWNER="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,27p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    -*)
      fail "알 수 없는 옵션: $1"
      ;;
    *)
      if [[ -z "$SLUG" ]]; then
        SLUG="$1"
      elif [[ -z "$BRIEF" ]]; then
        BRIEF="$1"
      else
        fail "인자 초과: $1"
      fi
      shift
      ;;
  esac
done

[[ -z "$SLUG" ]] && fail "사용법: $0 <slug> [\"brief\"] [옵션]\n예: $0 my-app \"<프로젝트 한 줄 설명>\""
[[ -z "$BRIEF" ]] && BRIEF="$SLUG (Phase A에서 채움)"

# GITHUB_OWNER 미지정 시: gh 인증되어 있으면 자동 감지, 아니면 즉시 실패
if [[ -z "$GITHUB_OWNER" ]]; then
  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    GITHUB_OWNER="$(gh api user -q .login 2>/dev/null || true)"
  fi
fi
if [[ -z "$GITHUB_OWNER" ]]; then
  fail "GITHUB_OWNER 미설정 — 'gh auth login' 후 재실행하거나, GITHUB_OWNER=<계정> 환경변수 또는 --github-owner <계정> 옵션 지정"
fi

REPO_FULL="${GITHUB_OWNER}/${SLUG}"
REPO_SSH="git@github.com:${REPO_FULL}.git"
MAC_CLONE_PATH="${MAC_DEV_DIR}/${SLUG}"
LINUX_CLONE_PATH="${LINUX_DEV_DIR}/${SLUG}"

echo
echo "${BOLD}=== New Project Bootstrap — Phase 0: Infra ===${NC}"
echo "  slug        : $SLUG"
echo "  brief       : $BRIEF"
echo "  GitHub repo : ${REPO_FULL} (${VISIBILITY/--/})"
echo "  Linux clone : ${LINUX_SSH_HOST}:${LINUX_CLONE_PATH}"
echo "  Mac clone   : ${MAC_CLONE_PATH}"
echo

# ─── 사전 의존성 체크 ─────────────────────────────────
step "사전 의존성 확인"
command -v gh >/dev/null 2>&1  || fail "gh (GitHub CLI) 미설치. https://cli.github.com"
command -v git >/dev/null 2>&1 || fail "git 미설치."
ok "gh, git 확인 완료"

# ─── 0-1. GitHub repo 생성 ────────────────────────────
step "0-1. GitHub repo 생성: ${REPO_FULL}"
if gh repo view "$REPO_FULL" >/dev/null 2>&1; then
  warn "repo 이미 존재: https://github.com/${REPO_FULL} — 생성 skip"
else
  gh repo create "$REPO_FULL" \
    "$VISIBILITY" \
    --description "$BRIEF" \
    --add-readme \
    || fail "gh repo create 실패"
  ok "생성 완료: https://github.com/${REPO_FULL}"
fi

# ─── 0-2a. Linux 서버 clone ───────────────────────────
if [[ "$SKIP_CLONE_LINUX" == false ]]; then
  step "0-2a. Linux 서버 clone (${LINUX_SSH_HOST})"
  if ssh "$LINUX_SSH_HOST" "test -d ${LINUX_CLONE_PATH}/.git" 2>/dev/null; then
    warn "${LINUX_SSH_HOST}:${LINUX_CLONE_PATH} 이미 존재 — clone skip"
  else
    ssh "$LINUX_SSH_HOST" \
      "git clone ${REPO_SSH} ${LINUX_CLONE_PATH}" \
      || fail "Linux clone 실패. SSH key 확인: ssh -T git@github.com"
    ok "Linux clone 완료"
  fi
fi

# ─── 0-2b. Mac 로컬 clone ─────────────────────────────
if [[ "$SKIP_CLONE_MAC" == false ]]; then
  step "0-2b. Mac 로컬 clone"
  MAC_CLONE_PATH_EXPANDED="${MAC_CLONE_PATH/#\~/$HOME}"
  if [[ -d "${MAC_CLONE_PATH_EXPANDED}/.git" ]]; then
    warn "${MAC_CLONE_PATH} 이미 존재 — clone skip"
  else
    git clone "$REPO_SSH" "$MAC_CLONE_PATH_EXPANDED" \
      || fail "Mac clone 실패. SSH key 확인: ssh -T git@github.com"
    ok "Mac clone 완료: ${MAC_CLONE_PATH}"
  fi
fi

# ─── 0-3. Telegram 토픽 안내 ─────────────────────────
step "0-3. Telegram 토픽 안내"
cat <<EOF

  ${YELLOW}사용자 액션 필요${NC}:
  1. Telegram 슈퍼그룹에서 [+] 버튼 → 새 토픽 이름 '${SLUG}' 으로 생성
  2. 그 토픽에서 봇에게 메시지 한 줄 전송 (예: "register")
  3. 토픽 매핑 자동화:
       ssh ${LINUX_SSH_HOST} 'cd ~/agentic-harness && ./scripts/topic-discover.sh'
     또는 --watch 백그라운드 모드가 이미 실행 중이면 자동 캡처됨.

EOF

# ─── 0-5. 초기 commit ────────────────────────────────
if [[ "$SKIP_COMMIT" == false ]]; then
  MAC_CLONE_PATH_EXPANDED="${MAC_CLONE_PATH/#\~/$HOME}"
  if [[ -d "$MAC_CLONE_PATH_EXPANDED" ]]; then
    step "0-5. 초기 commit (Mac 클론 기준)"

    # .gitignore (범용 — Python + Node + macOS)
    GITIGNORE_PATH="${MAC_CLONE_PATH_EXPANDED}/.gitignore"
    if [[ ! -f "$GITIGNORE_PATH" ]]; then
      cat > "$GITIGNORE_PATH" <<'GITIGNORE'
# macOS
.DS_Store
.AppleDouble
.LSOverride

# Python
__pycache__/
*.py[cod]
*.egg-info/
.venv/
venv/
dist/
build/
*.egg

# Node
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*
.pnp.*
.yarn/cache
.parcel-cache/
.next/
.nuxt/
dist/

# IDE / Editors
.idea/
.vscode/
*.swp
*.swo

# Env
.env
.env.*
!.env.example

# Logs
*.log
logs/
GITIGNORE
      ok ".gitignore 생성 완료"
    else
      warn ".gitignore 이미 존재 — skip"
    fi

    # README.md placeholder (GitHub --add-readme로 이미 있을 수 있음)
    README_PATH="${MAC_CLONE_PATH_EXPANDED}/README.md"
    if grep -q "Phase A에서 채움" "$README_PATH" 2>/dev/null || ! grep -q "." "$README_PATH" 2>/dev/null; then
      cat > "$README_PATH" <<README
# ${SLUG}

> ${BRIEF}

_Why / 상세 설명은 Phase A (Discovery) 완료 후 채워짐._

## 빠른 시작

```bash
# Phase A 완료 후 채움
```
README
      ok "README.md 업데이트 완료"
    fi

    # commit + push
    cd "$MAC_CLONE_PATH_EXPANDED" || fail "cd 실패: ${MAC_CLONE_PATH_EXPANDED}"
    git add .gitignore README.md 2>/dev/null || true
    if git diff --cached --quiet 2>/dev/null; then
      warn "변경사항 없음 — commit skip"
    else
      git commit -m "chore: initial scaffold (Phase 0 infra bootstrap)" \
        || fail "git commit 실패"
      git push \
        || fail "git push 실패"
      ok "초기 commit push 완료"
    fi
  else
    warn "Mac clone 디렉토리 없음 — commit skip"
  fi
fi

# ─── 완료 요약 ────────────────────────────────────────
echo
echo "${GREEN}${BOLD}━━━ Infra Bootstrap 완료 ━━━${NC}"
echo "  GitHub : https://github.com/${REPO_FULL}"
if [[ "$SKIP_CLONE_LINUX" == false ]]; then
  echo "  Linux  : ${LINUX_SSH_HOST}:${LINUX_CLONE_PATH} (clone OK)"
fi
if [[ "$SKIP_CLONE_MAC" == false ]]; then
  echo "  Mac    : ${MAC_CLONE_PATH} (clone OK)"
fi
echo "  Telegram topic: 사용자 액션 대기"
echo "  topic_map: topic-discover.sh 실행 후 <${SLUG}> entry 추가 예정"
echo
echo "다음: Phase A (Discovery) — Superpowers /brainstorming 호출"
echo
