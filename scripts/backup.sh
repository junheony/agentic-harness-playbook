#!/usr/bin/env bash
# backup.sh
# 일일 백업 (cron 추천: 매일 04:00 KST)
# 시크릿(.env/auth.json/*.token/...)은 제외, SOUL/USER/MEMORY는 별도 암호화 아카이브로
# Claude Code 대화 기록(projects/, history*, todos/ 등)은 백업하지 않음 (설정만)
#
# ⚠ 주의: 기본 백업 위치(BACKUP_REPO=~/dev/_personal/agentic-backup)는 원본과
#   같은 디스크다. 디스크 장애 시 백업도 같이 사라진다. git remote를 추가하고
#   --remote=<name> 으로 오프사이트(예: GitHub private repo) push를 강력 권장.
#   복원은 ./scripts/restore-backup.sh 참고.
#
# 사용:
#   ./scripts/backup.sh                     # 기본
#   ./scripts/backup.sh --remote=origin     # 특정 git remote로 push
#   BACKUP_REPO=/path/to/dir ./scripts/backup.sh

set -euo pipefail

BACKUP_REPO="${BACKUP_REPO:-$HOME/dev/_personal/agentic-backup}"
REMOTE="origin"
DATE=$(date +%Y-%m-%d)

for arg in "$@"; do
  case $arg in
    --remote=*) REMOTE="${arg#*=}" ;;
    -h|--help)
      sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

if [[ -t 1 ]]; then
  GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; RED=$'\033[0;31m'; NC=$'\033[0m'
else
  GREEN=''; YELLOW=''; RED=''; NC=''
fi
log()  { printf '%s[backup]%s %s\n' "$GREEN"  "$NC" "$*"; }
warn() { printf '%s[backup]%s %s\n' "$YELLOW" "$NC" "$*"; }
err()  { printf '%s[backup]%s %s\n' "$RED"    "$NC" "$*" >&2; }

# ─── 같은 디스크 경고 ─────────────────────────────────────
warn "백업 위치: $BACKUP_REPO — 원본과 같은 디스크면 디스크 장애 시 백업도 소실됨"
warn "오프사이트 권장: git remote 추가 후 --remote=<name> 로 push (예: GitHub private repo)"

# ─── 백업 디렉토리 준비 ───────────────────────────────────
if [[ ! -d "$BACKUP_REPO" ]]; then
  log "백업 repo 초기화: $BACKUP_REPO"
  mkdir -p "$BACKUP_REPO"
  (
    cd "$BACKUP_REPO"
    if git init -b main -q 2>/dev/null; then :
    else
      # 구 git: -b 미지원
      git init -q && git symbolic-ref HEAD refs/heads/main
    fi
    cat > .gitignore <<'EOF'
# 시크릿 절대 백업 X
*.token
*.key
*.pem
auth.json
.env
.env.*
.pgpass
credentials*
*.credentials

# 5 pillar는 별도 암호화 아카이브로
SOUL.md
USER.md
MEMORY.md

# 로그 / 캐시
*.log
logs/
cache/
EOF
    git add .gitignore
    git -c user.email='backup@local' -c user.name='backup' commit -q -m "init backup repo"
  )
fi

cd "$BACKUP_REPO"

# 매 실행마다 .gitignore 강제 갱신 (사용자가 실수로 수정/삭제했을 경우 대비)
cat > .gitignore <<'EOF'
*.token
*.key
*.pem
auth.json
.env
.env.*
.pgpass
credentials*
*.credentials
SOUL.md
USER.md
MEMORY.md
*.log
logs/
cache/
EOF

# rsync 공통 제외 패턴 (방어적 denylist)
RSYNC_EXCLUDES=(
  --exclude='auth.json'
  --exclude='credentials*'
  --exclude='.credentials*'
  --exclude='*.credentials'
  --exclude='*.token'
  --exclude='*.key'
  --exclude='*.pem'
  --exclude='.env'
  --exclude='.env.*'
  --exclude='.pgpass'
  --exclude='logs/'
  --exclude='cache/'
  --exclude='*.db'
)

# ─── 1. Claude Code 설정 ──────────────────────────────────
# 설정만 백업 — 대화 기록/세션 상태는 제외 (개인 대화 내용이 백업 repo에 남지 않도록)
log "Claude Code 설정 백업 (대화 기록 제외)"
mkdir -p claude-code
rsync -a "${RSYNC_EXCLUDES[@]}" \
  --exclude='projects/' \
  --exclude='history*' \
  --exclude='sessions/' \
  --exclude='todos/' \
  --exclude='transcripts/' \
  --exclude='tasks/' \
  --exclude='paste-cache/' \
  --exclude='uploads/' \
  --exclude='session-env/' \
  --exclude='shell-snapshots/' \
  --exclude='file-history/' \
  --exclude='statsig/' \
  ~/.claude/ claude-code/ 2>/dev/null || warn "$HOME/.claude/ 일부 누락"

# ─── 2. opencode 설정 ─────────────────────────────────────
log "opencode 설정 백업"
mkdir -p opencode
rsync -a "${RSYNC_EXCLUDES[@]}" ~/.config/opencode/ opencode/ 2>/dev/null || warn "opencode 누락"

# ─── 3. Hermes 설정 (5 pillar 제외) ───────────────────────
log "Hermes 설정 백업 (5 pillar 제외)"
mkdir -p hermes
rsync -a "${RSYNC_EXCLUDES[@]}" \
  --exclude='SOUL.md' \
  --exclude='USER.md' \
  --exclude='MEMORY.md' \
  ~/.hermes/ hermes/ 2>/dev/null || warn "$HOME/.hermes/ 누락"

# ─── 4. Paperclip ─────────────────────────────────────────
if [[ -d ~/.paperclip ]]; then
  log "Paperclip 백업"
  mkdir -p paperclip
  rsync -a "${RSYNC_EXCLUDES[@]}" \
    --exclude='audit/*/raw/' \
    ~/.paperclip/ paperclip/ 2>/dev/null || warn "paperclip 누락"
fi

# ─── 5. 5 Pillar — 별도 암호화 아카이브 ──────────────────
if [[ -f ~/.hermes/SOUL.md || -f ~/.hermes/USER.md || -f ~/.hermes/MEMORY.md ]]; then
  if command -v age >/dev/null 2>&1; then
    AGE_PUB="${AGE_RECIPIENT_FILE:-$HOME/.config/age/public-key.txt}"
    if [[ -r "$AGE_PUB" ]]; then
      log "5 Pillar 암호화 백업 (age)"
      TMP=$(mktemp -d)
      cp ~/.hermes/SOUL.md ~/.hermes/USER.md ~/.hermes/MEMORY.md "$TMP/" 2>/dev/null || true
      tar -cf - -C "$TMP" . | age -r "$(cat "$AGE_PUB")" > "hermes-5pillar-${DATE}.tar.age"
      rm -rf "$TMP"
    else
      warn "age 공개키 없음 ($AGE_PUB) — 5 pillar 백업 skip"
    fi
  elif command -v gpg >/dev/null 2>&1; then
    log "5 Pillar 암호화 백업 (gpg symmetric)"
    if [[ -z "${GPG_PASSPHRASE:-}" ]]; then
      warn "GPG_PASSPHRASE 미설정 — 대화형 입력 또는 환경변수 설정 권장. skip."
    else
      tar -cf - -C ~/.hermes SOUL.md USER.md MEMORY.md 2>/dev/null | \
        gpg --batch --yes --passphrase "$GPG_PASSPHRASE" \
            --symmetric --cipher-algo AES256 -o "hermes-5pillar-${DATE}.tar.gpg"
    fi
  else
    warn "age/gpg 없음 — 5 pillar 백업 skip (수동 백업 권장)"
  fi
fi

# ─── 6. Commit + Push ─────────────────────────────────────
log "git add + commit"
git add -A
if git diff --cached --quiet; then
  log "변경 없음, commit skip"
else
  git -c user.email='backup@local' -c user.name='backup' commit -q -m "backup: $DATE"
  log "commit: $(git rev-parse --short HEAD)"
fi

if git remote | grep -qE "^${REMOTE}$"; then
  CURRENT_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo "HEAD")
  log "push to $REMOTE ($CURRENT_BRANCH)"
  git push -q "$REMOTE" "$CURRENT_BRANCH" || warn "push 실패 (네트워크?)"
else
  warn "remote '$REMOTE' 없음 — 로컬 git만 commit됨"
  warn "리모트 추가: cd '$BACKUP_REPO' && git remote add $REMOTE <URL>"
fi

# ─── 7. 오래된 백업 정리 (30일 이상) ──────────────────────
log "오래된 5 pillar 백업 정리 (30일 초과)"
find "$BACKUP_REPO" -maxdepth 1 -name "hermes-5pillar-*.tar.*" -mtime +30 -delete 2>/dev/null || true

log "백업 완료: $DATE"
