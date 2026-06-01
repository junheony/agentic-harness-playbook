#!/usr/bin/env bash
# restore-backup.sh
# backup.sh 의 복원 카운터파트 — 백업 repo의 설정 디렉토리와
# age/gpg 암호화된 5 pillar 아카이브를 홈 디렉토리로 복원.
#
# backup.sh 가 만드는 레이아웃 (BACKUP_REPO 기준) ↔ 복원 대상:
#   claude-code/                  → ~/.claude/          (대화 기록은 백업에 없음)
#   opencode/                     → ~/.config/opencode/
#   hermes/                       → ~/.hermes/          (5 pillar 제외분)
#   paperclip/                    → ~/.paperclip/
#   hermes-5pillar-<날짜>.tar.age → ~/.hermes/{SOUL,USER,MEMORY}.md (age -d)
#   hermes-5pillar-<날짜>.tar.gpg → 위와 동일 (gpg symmetric)
#
# 사용:
#   ./scripts/restore-backup.sh --list             # 스냅샷 목록 + 백업 구성 확인
#   ./scripts/restore-backup.sh                    # 전체 복원 (항목별 확인 프롬프트)
#   ./scripts/restore-backup.sh --dry-run          # 실행 없이 명령만 출력
#   ./scripts/restore-backup.sh --date=2026-07-01  # 특정 날짜의 5 pillar 아카이브 복원
#
# 환경변수:
#   BACKUP_REPO         백업 repo 경로 (default: ~/dev/_personal/agentic-backup)
#   AGE_IDENTITY_FILE   age 개인키(identity) 파일 (default: ~/.config/age/key.txt)
#   GPG_PASSPHRASE      .tar.gpg 복호화 passphrase (미설정 시 gpg 대화형)
#   ASSUME_YES=1        모든 confirm 자동 yes
#
# 주의:
#   - rsync는 --delete 없이 merge 복원. 백업에 없는 로컬 파일은 남는다.
#   - 시크릿(.env, auth.json, *.token 등)은 backup.sh 가 애초에 백업하지
#     않으므로 복원되지 않는다. install-all.sh Phase 1/4 로 재등록할 것.

set -euo pipefail

BACKUP_REPO="${BACKUP_REPO:-$HOME/dev/_personal/agentic-backup}"
AGE_IDENTITY_FILE="${AGE_IDENTITY_FILE:-$HOME/.config/age/key.txt}"
DRY_RUN=false
MODE="restore"
PICK_DATE=""

for arg in "$@"; do
  case $arg in
    --list) MODE="list" ;;
    --dry-run) DRY_RUN=true ;;
    --date=*) PICK_DATE="${arg#*=}" ;;
    -h|--help)
      sed -n '2,29p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

if [[ -t 1 ]]; then
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; NC=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; NC=''
fi
log()  { printf '%s[restore]%s %s\n' "$GREEN"  "$NC" "$*"; }
ok()   { printf '%s✓%s %s\n' "$GREEN" "$NC" "$*"; }
warn() { printf '%s[restore]%s %s\n' "$YELLOW" "$NC" "$*"; }
err()  { printf '%s[restore]%s %s\n' "$RED"    "$NC" "$*" >&2; }

# run: dry-run 시 출력만, 아니면 실행
run() {
  if $DRY_RUN; then
    printf '    [dry-run] %s\n' "$*"
  else
    sh -c "$*"
  fi
}

confirm() {
  if [[ "${ASSUME_YES:-0}" == "1" ]]; then return 0; fi
  local reply
  read -rp "$1 [y/N]: " -n 1 reply; echo
  [[ "$reply" =~ ^[Yy]$ ]]
}

if [[ ! -d "$BACKUP_REPO" ]]; then
  err "백업 repo 없음: $BACKUP_REPO"
  err "BACKUP_REPO 환경변수로 경로 지정하거나 backup.sh 를 먼저 실행할 것"
  exit 1
fi

# 5 pillar 스냅샷 목록 (오름차순 — 마지막이 최신)
list_snapshots() {
  find "$BACKUP_REPO" -maxdepth 1 \
    \( -name 'hermes-5pillar-*.tar.age' -o -name 'hermes-5pillar-*.tar.gpg' \) \
    2>/dev/null | sort
}

# ─── list 모드 ────────────────────────────────────────────
if [[ "$MODE" == "list" ]]; then
  log "백업 repo: $BACKUP_REPO"
  echo
  echo "── 디렉토리 백업 (rsync 복원 대상) ──"
  for d in claude-code opencode hermes paperclip; do
    if [[ -d "$BACKUP_REPO/$d" ]]; then
      printf '  %-12s %s\n' "$d" "$(du -sh "$BACKUP_REPO/$d" 2>/dev/null | cut -f1)"
    else
      printf '  %-12s (없음)\n' "$d"
    fi
  done
  echo
  echo "── 5 pillar 암호화 스냅샷 ──"
  SNAPS="$(list_snapshots)"
  if [[ -n "$SNAPS" ]]; then
    printf '%s\n' "$SNAPS" | sed "s|^$BACKUP_REPO/|  |"
  else
    echo "  (없음)"
  fi
  echo
  if git -C "$BACKUP_REPO" rev-parse --git-dir >/dev/null 2>&1; then
    echo "── 최근 백업 커밋 (5) ──"
    git -C "$BACKUP_REPO" log --oneline -5 2>/dev/null || true
  fi
  exit 0
fi

# ─── 1~4. 디렉토리 복원 (backup.sh 레이아웃 미러) ─────────
restore_dir() {
  local src="$1" dest="$2" label="$3"
  if [[ ! -d "$BACKUP_REPO/$src" ]]; then
    warn "$label 백업 없음 ($BACKUP_REPO/$src) — skip"
    return 0
  fi
  if confirm "$label 복원? ($BACKUP_REPO/$src/ → $dest/)"; then
    run "mkdir -p '$dest'"
    run "rsync -a '$BACKUP_REPO/$src/' '$dest/'"
    ok "$label 복원 완료 → $dest"
  else
    warn "$label 복원 skip"
  fi
}

log "복원 시작 (backup repo: $BACKUP_REPO)"
restore_dir claude-code "$HOME/.claude"          "Claude Code 설정"
restore_dir opencode    "$HOME/.config/opencode" "opencode 설정"
restore_dir hermes      "$HOME/.hermes"          "Hermes 설정 (5 pillar 제외분)"
restore_dir paperclip   "$HOME/.paperclip"       "Paperclip"

# ─── 5. 5 Pillar 복원 (age/gpg 복호화) ────────────────────
ARCHIVE=""
if [[ -n "$PICK_DATE" ]]; then
  for ext in age gpg; do
    if [[ -f "$BACKUP_REPO/hermes-5pillar-${PICK_DATE}.tar.${ext}" ]]; then
      ARCHIVE="$BACKUP_REPO/hermes-5pillar-${PICK_DATE}.tar.${ext}"
      break
    fi
  done
  if [[ -z "$ARCHIVE" ]]; then
    err "hermes-5pillar-${PICK_DATE}.tar.{age,gpg} 없음 — --list 로 스냅샷 확인"
    exit 1
  fi
else
  ARCHIVE="$(list_snapshots | tail -1)"
fi

if [[ -z "$ARCHIVE" ]]; then
  warn "5 pillar 암호화 스냅샷 없음 — skip"
else
  log "5 pillar 스냅샷: $ARCHIVE"
  if [[ -f "$HOME/.hermes/SOUL.md" || -f "$HOME/.hermes/USER.md" || -f "$HOME/.hermes/MEMORY.md" ]]; then
    warn "기존 $HOME/.hermes/{SOUL,USER,MEMORY}.md 가 덮어써짐"
  fi
  if confirm "5 pillar 복원? ($ARCHIVE → $HOME/.hermes/)"; then
    run "mkdir -p '$HOME/.hermes'"
    case "$ARCHIVE" in
      *.tar.age)
        if ! command -v age >/dev/null 2>&1; then
          if $DRY_RUN; then
            warn "age 미설치 (dry-run이라 계속) — brew install age / sudo apt-get install age"
          else
            err "age 미설치 — brew install age (macOS) / sudo apt-get install age (Linux)"
            exit 1
          fi
        fi
        if [[ ! -r "$AGE_IDENTITY_FILE" ]]; then
          if $DRY_RUN; then
            warn "age 개인키 없음: $AGE_IDENTITY_FILE (dry-run이라 계속)"
          else
            err "age 개인키(identity) 없음: $AGE_IDENTITY_FILE"
            err "AGE_IDENTITY_FILE 환경변수로 실제 키 파일 경로 지정"
            exit 1
          fi
        fi
        run "age -d -i '$AGE_IDENTITY_FILE' '$ARCHIVE' | tar -xf - -C '$HOME/.hermes'"
        ;;
      *.tar.gpg)
        if ! command -v gpg >/dev/null 2>&1 && ! $DRY_RUN; then
          err "gpg 미설치"
          exit 1
        fi
        if $DRY_RUN; then
          printf '    [dry-run] <secret op: gpg -d %s | tar -xf - -C %s/.hermes>\n' "$ARCHIVE" "$HOME"
        elif [[ -n "${GPG_PASSPHRASE:-}" ]]; then
          gpg --batch --yes --passphrase "$GPG_PASSPHRASE" -d "$ARCHIVE" | tar -xf - -C "$HOME/.hermes"
        else
          gpg -d "$ARCHIVE" | tar -xf - -C "$HOME/.hermes"
        fi
        ;;
    esac
    for f in SOUL.md USER.md MEMORY.md; do
      [[ -f "$HOME/.hermes/$f" ]] && run "chmod 600 '$HOME/.hermes/$f'"
    done
    ok "5 pillar 복원 완료 → $HOME/.hermes/"
  else
    warn "5 pillar 복원 skip"
  fi
fi

echo
log "복원 완료"
echo "다음 단계:"
echo "  1. 시크릿 재등록: ./scripts/install-all.sh --only-phase=4 (Telegram) / codex login (Phase 1)"
echo "  2. ./scripts/healthcheck.sh 로 상태 점검"
echo "  3. ./scripts/verify-phase7.sh 로 round-trip 검증"
