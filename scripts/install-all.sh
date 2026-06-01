#!/usr/bin/env bash
# install-all.sh
# Phase 0~7 + 4b + 6b 대화형 설치 스크립트 (macOS Apple Silicon 또는 Linux 서버 지원)
#
# 사용:
#   ./scripts/install-all.sh                          # 기본 (Phase 0부터)
#   ./scripts/install-all.sh --dry-run                # 모든 명령을 출력만, 실행 X
#   ./scripts/install-all.sh --start-phase=3          # Phase 3부터 시작 (0, 1, 2 건너뜀)
#   ./scripts/install-all.sh --only-phase=4           # Phase 4만 실행
#   ./scripts/install-all.sh --workdir=/home/user/dev # 작업 디렉토리 루트 (default: ~/dev)
#   ./scripts/install-all.sh --enable-claude-proxy    # OFF-POLICY: omo_proxy 배포 (Phase 6b)
#
# 환경변수 오버라이드:
#   WORKDIR_ROOT          작업 루트 (default: ~/dev)
#   ASSUME_YES=1          모든 confirm 자동 yes (CI/무인 셋업용)
#   ENABLE_CLAUDE_PROXY=1 --enable-claude-proxy 와 동일
#
# Phase 매핑:
#   Phase 0   OS 의존성 (apt/brew) + Node 20 + pnpm + uv
#   Phase 1   Codex OAuth
#   Phase 2   opencode
#   Phase 3   Hermes (감지 + 활용 / 없으면 skip)
#   Phase 4   Telegram bot + secret
#   Phase 4b  mini-router (Hermes 없거나 사용자 명시 시)
#   Phase 5   Claude Code MCP (조건부)
#   Phase 6   systemd 상시 가동 + linger (Linux) / launchd (macOS)
#   Phase 6b  --enable-claude-proxy 시 omo_proxy 배포 (OFF-POLICY)
#   Phase 7   verify-phase7.sh 자동 호출
#
# 시크릿 저장 우선순위:
#   macOS: Keychain > ~/.hermes/.env (chmod 600)
#   Linux: secret-tool (libsecret) > pass (gpg) > ~/.hermes/.env (chmod 600)

set -euo pipefail

# ─── 인자 파싱 ────────────────────────────────────────────
DRY_RUN=false
START_PHASE=0
ONLY_PHASE=""
WORKDIR_ROOT="${WORKDIR_ROOT:-$HOME/dev}"
ENABLE_CLAUDE_PROXY="${ENABLE_CLAUDE_PROXY:-0}"

for arg in "$@"; do
  case $arg in
    --dry-run) DRY_RUN=true ;;
    --start-phase=*) START_PHASE="${arg#*=}" ;;
    --only-phase=*) ONLY_PHASE="${arg#*=}" ;;
    --workdir=*) WORKDIR_ROOT="${arg#*=}" ;;
    --enable-claude-proxy) ENABLE_CLAUDE_PROXY=1 ;;
    -h|--help)
      sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

# ─── PATH 보강 (비인터랙티브 SSH 환경 대응) ───────────────
# SSH non-interactive 쉘에서 ~/.local/bin, ~/.opencode/bin 등 안 보임.
# 여기서 미리 추가해두면 "이미 설치됨" early-return이 올바르게 작동.
export PATH="$HOME/.opencode/bin:$HOME/.local/bin:$HOME/.npm-global/bin:$HOME/.cargo/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

# ─── 색상 / 로깅 ──────────────────────────────────────────
if [[ -t 1 ]]; then
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
  BLUE=$'\033[0;34m'; NC=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; NC=''
fi

log()  { printf '%s[%s]%s %s\n' "$BLUE" "$(date +%H:%M:%S)" "$NC" "$*"; }
ok()   { printf '%s✓%s %s\n' "$GREEN" "$NC" "$*"; }
warn() { printf '%s⚠%s %s\n' "$YELLOW" "$NC" "$*"; }
err()  { printf '%s✗%s %s\n' "$RED" "$NC" "$*" >&2; }

# run: 단일 인자 명령을 sh -c로 실행 (eval 대신). dry-run 시 출력만.
run() {
  if $DRY_RUN; then
    printf '    [dry-run] %s\n' "$*"
  else
    sh -c "$*"
  fi
}

# run_secret: 시크릿이 포함된 명령 — dry-run 시에도 시크릿은 절대 출력하지 않음
run_secret() {
  local label="$1"; shift
  if $DRY_RUN; then
    printf '    [dry-run] <secret op: %s>\n' "$label"
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

# phase_active: 현재 phase가 실행 대상인지 판단
# 4b, 6b 같은 서브 phase는 문자열 비교로 처리
# ONLY_PHASE="" (기본) → START_PHASE 이상인 모든 phase 실행
# ONLY_PHASE="4b" 등 → 해당 phase만 실행
phase_active() {
  local phase="$1"
  if [[ -n "$ONLY_PHASE" ]]; then
    [[ "$phase" == "$ONLY_PHASE" ]]
  else
    # 숫자 비교: 정수 part만 추출해서 비교
    local phase_num="${phase%%[a-z]*}"
    [[ "$phase_num" -ge "$START_PHASE" ]]
  fi
}

# 시크릿 입력 (stdin 무에코)
read_secret() {
  local prompt="$1" var="$2" value
  read -rsp "$prompt" value; echo
  printf -v "$var" '%s' "$value"
}

# Secret-store helpers (cross-platform)
# 우선순위: macOS Keychain > Linux secret-tool (libsecret) > pass (gpg) > .env fallback
#
# ── 표준 규약 (canonical) ──
# Linux secret-tool 속성은 저장/조회 모두 항상 `service hermes account <secret-name>`:
#   저장: printf '%s' "$VALUE" | secret-tool store --label="hermes:<name>" service hermes account <name>
#   조회: secret-tool lookup service hermes account <name>
# macOS Keychain은 `security find-generic-password -a hermes -s <name> -w` 로 통일.
# (다른 스크립트/유닛 파일도 이 규약을 따른다 — 속성 순서를 바꾸지 말 것)
keychain_set() {
  local service="$1" value="$2"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    security add-generic-password -a hermes -s "$service" -w "$value" -U 2>/dev/null
  elif command -v secret-tool >/dev/null 2>&1; then
    printf '%s' "$value" | secret-tool store --label="hermes:${service}" service hermes account "$service" 2>/dev/null
  elif command -v pass >/dev/null 2>&1; then
    printf '%s\n%s\n' "$value" "$value" | pass insert -e "hermes/${service}" 2>/dev/null
  else
    return 1
  fi
}

keychain_has() {
  local service="$1"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    security find-generic-password -a hermes -s "$service" -w >/dev/null 2>&1
  elif command -v secret-tool >/dev/null 2>&1; then
    secret-tool lookup service hermes account "$service" >/dev/null 2>&1
  elif command -v pass >/dev/null 2>&1; then
    pass show "hermes/${service}" >/dev/null 2>&1
  else
    return 1
  fi
}

keychain_get() {
  local service="$1"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    security find-generic-password -a hermes -s "$service" -w 2>/dev/null
  elif command -v secret-tool >/dev/null 2>&1; then
    secret-tool lookup service hermes account "$service" 2>/dev/null
  elif command -v pass >/dev/null 2>&1; then
    pass show "hermes/${service}" 2>/dev/null | head -1
  fi
}

# ─── 사전 체크 ─────────────────────────────────────────────
log "사전 환경 체크"

case "$OSTYPE" in
  darwin*) ok "macOS 감지" ;;
  linux*)  ok "Linux 감지 — systemd user unit / secret-tool / pass 경로로 동작" ;;
  *)       err "지원하지 않는 OS ($OSTYPE)"; exit 1 ;;
esac

# git, curl은 Phase 0 이전에 있어야 함 (clone 자체에 필요하니까 사실 있겠지만 검증)
PREFLIGHT=(git curl)
PREFLIGHT_MISSING=()
for cmd in "${PREFLIGHT[@]}"; do
  command -v "$cmd" >/dev/null 2>&1 || PREFLIGHT_MISSING+=("$cmd")
done
if (( ${#PREFLIGHT_MISSING[@]} > 0 )); then
  err "git/curl 미설치: ${PREFLIGHT_MISSING[*]}. 수동 설치 후 재실행."
  exit 1
fi
ok "git, curl 준비됨"

# ─── 작업 디렉토리 ────────────────────────────────────────
log "작업 디렉토리: $WORKDIR_ROOT"
run "mkdir -p '$WORKDIR_ROOT' ~/scratch"

# ─── Phase 0: OS 의존성 + Node 20 + pnpm + uv ────────────
if phase_active 0; then
  log "Phase 0: OS 의존성 + Node 20 + pnpm + uv"

  if [[ "$OSTYPE" == "linux"* ]]; then
    # ── Linux (Ubuntu/Debian) ──────────────────────────────
    if command -v apt-get >/dev/null 2>&1; then
      log "apt 패키지 설치 (sudo 필요)"
      APT_PKGS=(
        git curl jq tmux
        python3 python3-venv python3-pip
        libsecret-tools
        age pass gpg gh
      )
      # Ubuntu 24.04 기본 nodejs는 18.x → NodeSource로 20+ 보장
      # apt가 이미 nodejs 20+를 제공하면 skip
      if ! command -v node >/dev/null 2>&1 || \
         [[ "$(node --version 2>/dev/null | tr -d 'v' | cut -d. -f1)" -lt 20 ]]; then
        APT_PKGS+=(nodejs npm)
        if confirm "NodeSource PPA로 Node 20 설치 (sudo apt-get 필요)?"; then
          # fetch → inspect → confirm 패턴 (curl | sudo bash 금지)
          run "curl -fsSL https://deb.nodesource.com/setup_20.x -o /tmp/nodesource-setup.sh"
          if ! $DRY_RUN; then
            echo "── /tmp/nodesource-setup.sh 상단 미리보기 ──"
            head -n 20 /tmp/nodesource-setup.sh
            echo "── (전체 확인: less /tmp/nodesource-setup.sh) ──"
          fi
          if confirm "내용 확인 완료 — sudo bash /tmp/nodesource-setup.sh 실행?"; then
            run "sudo -E bash /tmp/nodesource-setup.sh"
          else
            warn "NodeSource 셋업 스크립트 실행 스킵"
          fi
        else
          warn "Node 20 설치 스킵. 현재 버전: $(node --version 2>/dev/null || echo 미설치)"
        fi
      else
        ok "Node.js $(node --version) 이미 설치됨"
      fi

      if confirm "apt-get install -y ${APT_PKGS[*]} 실행?"; then
        run "sudo apt-get update -qq"
        run "sudo apt-get install -y ${APT_PKGS[*]}"
        ok "apt 패키지 설치 완료"
      else
        warn "apt 설치 스킵 — 이후 phase에서 일부 도구 없을 수 있음"
      fi
    else
      warn "apt-get 없음 (Ubuntu/Debian 아님?) — OS 의존성 수동 설치 필요"
    fi

    # yq(mikefarah)는 선택 사항 — topic-discover.sh가 있으면 활용 (없어도 동작)
    if ! command -v yq >/dev/null 2>&1; then
      warn "yq(mikefarah) 미설치 — 선택 사항. 설치 방법:"
      warn "  sudo snap install yq   또는   https://github.com/mikefarah/yq/releases 에서 바이너리 다운로드"
    fi

    # pnpm (corepack 우선, sudo npm i -g pnpm fallback)
    if ! command -v pnpm >/dev/null 2>&1; then
      if command -v node >/dev/null 2>&1 && \
         [[ "$(node --version 2>/dev/null | tr -d 'v' | cut -d. -f1)" -ge 16 ]]; then
        log "pnpm 설치 (corepack)"
        run "corepack enable"
        run "corepack prepare pnpm@latest --activate"
      else
        log "pnpm 설치 (npm i -g)"
        run "sudo npm i -g pnpm"
      fi
    else
      ok "pnpm 이미 설치됨 ($(pnpm --version 2>/dev/null))"
    fi

    # uv / uvx (Python 패키지 매니저)
    if ! command -v uv >/dev/null 2>&1; then
      log "uv 설치 (fetch → inspect → bash)"
      run "curl -LsSf https://astral.sh/uv/install.sh -o /tmp/uv-install.sh"
      warn "/tmp/uv-install.sh 내용 확인 권장"
      if confirm "uv 설치 스크립트 실행?"; then
        run "bash /tmp/uv-install.sh"
        # uv는 ~/.local/bin에 설치됨 — PATH는 이미 위에서 보강됨
        ok "uv 설치됨 (~/.local/bin/uv)"
      fi
    else
      ok "uv 이미 설치됨 ($(uv --version 2>/dev/null))"
    fi

  elif [[ "$OSTYPE" == "darwin"* ]]; then
    # ── macOS ──────────────────────────────────────────────
    if ! command -v brew >/dev/null 2>&1; then
      warn "Homebrew 미설치"
      if confirm "Homebrew 설치?"; then
        run '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        # Apple Silicon: brew가 /opt/homebrew에 설치됨 → PATH에 이미 포함
      else
        err "Homebrew 없이 macOS 셋업 불가. 설치 후 재실행."; exit 1
      fi
    fi

    for pkg in jq tmux python3 gh age yq; do
      if ! command -v "$pkg" >/dev/null 2>&1; then
        run "brew install $pkg"
      else
        ok "$pkg 이미 설치됨"
      fi
    done

    # Node 20+
    if ! command -v node >/dev/null 2>&1 || \
       [[ "$(node --version 2>/dev/null | tr -d 'v' | cut -d. -f1)" -lt 20 ]]; then
      log "Node.js 설치 (brew)"
      run "brew install node"
    else
      ok "Node.js $(node --version) 이미 설치됨"
    fi

    # pnpm (corepack 우선)
    if ! command -v pnpm >/dev/null 2>&1; then
      log "pnpm 설치 (corepack)"
      run "corepack enable"
      run "corepack prepare pnpm@latest --activate"
    else
      ok "pnpm 이미 설치됨 ($(pnpm --version 2>/dev/null))"
    fi

    # uv
    if ! command -v uv >/dev/null 2>&1; then
      run "brew install uv"
    else
      ok "uv 이미 설치됨 ($(uv --version 2>/dev/null))"
    fi
  fi

  ok "Phase 0 완료"
fi

# ─── Phase 1: Codex OAuth ────────────────────────────────
if phase_active 1; then
  log "Phase 1: Codex OAuth"

  if ! command -v codex >/dev/null 2>&1; then
    log "Codex CLI 설치"
    if [[ "$OSTYPE" == "linux"* ]]; then
      # Linux: npm prefix를 ~/.npm-global로 설정해서 sudo 없이 전역 설치
      if ! npm config get prefix 2>/dev/null | grep -q "npm-global"; then
        run "mkdir -p '$HOME/.npm-global'"
        run "npm config set prefix '$HOME/.npm-global'"
        # PATH는 이미 위에서 보강됨
        ok "npm prefix → ~/.npm-global (sudo 불필요)"
      fi
      run "npm i -g @openai/codex"
    else
      run "npm i -g @openai/codex"
    fi
  elif $DRY_RUN; then
    ok "Codex CLI 이미 설치됨"
    printf '    [dry-run] codex --version\n'
  else
    ok "Codex CLI 이미 설치됨 ($(codex --version 2>/dev/null | head -1))"
  fi

  if $DRY_RUN; then
    printf '    [dry-run] codex login status || codex login --device-auth\n'
  elif codex login status >/dev/null 2>&1; then
    ok "Codex OAuth 이미 로그인됨"
  else
    log "Codex OAuth 로그인 (device-auth)"
    codex login --device-auth
  fi

  if [[ -f ~/.codex/auth.json ]]; then
    run "chmod 600 ~/.codex/auth.json"
    ok "$HOME/.codex/auth.json 권한 600 적용"
  fi
fi

# ─── Phase 2: opencode + Codex OAuth 플러그인 ─────────────
if phase_active 2; then
  log "Phase 2: opencode + Codex OAuth 플러그인"

  if ! command -v opencode >/dev/null 2>&1; then
    warn "opencode 미설치"
    warn "공식 안내: https://github.com/anomalyco/opencode#install"
    warn "안전 패턴: curl -fsSL https://opencode.ai/install -o /tmp/opencode-install.sh && less /tmp/opencode-install.sh && bash /tmp/opencode-install.sh"
    if confirm "지금 자동 설치 시도?"; then
      run "curl -fsSL https://opencode.ai/install -o /tmp/opencode-install.sh"
      warn "/tmp/opencode-install.sh 내용 확인 권장"
      if confirm "내용 확인 후 실행?"; then
        run "bash /tmp/opencode-install.sh"
        # opencode는 ~/.opencode/bin 에 설치됨 — PATH 이미 보강됨
        ok "opencode 설치됨 (~/.opencode/bin/opencode)"
      fi
    fi
  else
    ok "opencode 이미 설치됨"
  fi

  if command -v opencode >/dev/null 2>&1 && confirm "Codex OAuth 플러그인 설치/업데이트?"; then
    run "npx -y opencode-openai-codex-auth@latest"
  fi

  run "mkdir -p ~/.config/opencode"

  if [[ ! -f ~/.config/opencode/opencode.jsonc ]]; then
    warn "$HOME/.config/opencode/opencode.jsonc 없음 — examples/configs/opencode.example.jsonc 복사 권장:"
    warn "  cp examples/configs/opencode.example.jsonc ~/.config/opencode/opencode.jsonc"
  fi
fi

# ─── Phase 3: Hermes ──────────────────────────────────────
if phase_active 3; then
  log "Phase 3: Hermes 감지 + 5 pillar 구성"

  if ! command -v hermes >/dev/null 2>&1; then
    warn "Hermes 미설치 — Phase 3 기능 skip"
    warn "공식 설치: https://github.com/NousResearch/hermes-agent (README 따라 진행)"
    warn "안전 패턴: curl -fsSL <install-url> -o /tmp/hermes-install.sh && less /tmp/hermes-install.sh && sh /tmp/hermes-install.sh"
    warn "Hermes 없으면 mini-router (Phase 4b)로 Telegram 라우팅 대체 가능"
  else
    ok "Hermes 이미 설치됨"

    if confirm "Hermes 모델 등록 실행 (Codex auth 재사용)?"; then
      run "hermes model"
    fi

    if [[ ! -f ~/.hermes/SOUL.md ]]; then
      log "Hermes 5 pillar 초기화"
      run "mkdir -p ~/.hermes ~/.hermes/skills"
      run "hermes init || true"
      run "touch ~/.hermes/SOUL.md ~/.hermes/USER.md ~/.hermes/MEMORY.md"
      warn "examples/soul/*.example.md 참고해서 본인 정보로 채울 것"
    else
      ok "Hermes 5 pillar 이미 초기화됨"
    fi

    for f in ~/.hermes/.env ~/.hermes/SOUL.md ~/.hermes/USER.md ~/.hermes/MEMORY.md; do
      [[ -f $f ]] && run "chmod 600 '$f'"
    done
  fi
fi

# ─── Phase 4: Telegram ────────────────────────────────────
if phase_active 4; then
  log "Phase 4: Telegram bot + Forum Topics"
  warn "BotFather + 슈퍼그룹 + Forum Topics 활성화는 수동 작업. docs/03-execution-phase1-7.md § Phase 4 참고."

  local_has_token=false
  keychain_has telegram-bot-token 2>/dev/null && local_has_token=true
  [[ -f ~/.hermes/.env ]] && grep -q "TELEGRAM_BOT_TOKEN" ~/.hermes/.env 2>/dev/null && local_has_token=true

  if ! $local_has_token; then
    if $DRY_RUN; then
      # dry-run 순수성: 대화형 입력(read_secret/read)은 절대 실행하지 않는다.
      # ASSUME_YES=1 + 비대화형 stdin(CI) 조합에서 read가 EOF로 실패하는 문제도 함께 방지.
      log "  [dry-run] Telegram 토큰 미등록 — 실제 실행 시 토큰/user_id/chat_id를 대화형 입력받아 시크릿 스토어(canonical: service hermes account telegram-bot-token)에 저장"
    elif confirm "지금 Telegram 봇 토큰 등록할까?"; then
      read_secret "Bot token (무에코): " BOT_TOKEN
      [[ -z "${BOT_TOKEN:-}" ]] && { err "토큰 비어있음"; exit 1; }
      read -rp "Your Telegram user_id (숫자): " USER_ID
      read -rp "Supergroup chat_id (옵션, 빈 값 OK): " CHAT_ID

      # 1순위: OS 네이티브 시크릿 스토어
      _secret_store_available=false
      _secret_store_label=""
      if [[ "$OSTYPE" == "darwin"* ]]; then
        _secret_store_available=true
        _secret_store_label="macOS Keychain"
      elif command -v secret-tool >/dev/null 2>&1; then
        _secret_store_available=true
        _secret_store_label="secret-tool (libsecret)"
      elif command -v pass >/dev/null 2>&1; then
        _secret_store_available=true
        _secret_store_label="pass (gpg)"
      fi

      if $_secret_store_available && confirm "${_secret_store_label}에 토큰 저장 (권장)?"; then
        if $DRY_RUN; then
          printf '    [dry-run] <secret op: %s add telegram-bot-token>\n' "${_secret_store_label}"
        else
          keychain_set telegram-bot-token "$BOT_TOKEN" \
            && ok "${_secret_store_label} 저장됨 (hermes/telegram-bot-token)" \
            || { err "${_secret_store_label} 저장 실패 — .env fallback으로 전환"; _secret_store_available=false; }
        fi
        if $_secret_store_available; then
          run "touch ~/.hermes/.env && chmod 600 ~/.hermes/.env"
          if ! $DRY_RUN; then
            {
              printf 'TELEGRAM_ALLOWED_USERS=%s\n' "$USER_ID"
              [[ -n "$CHAT_ID" ]] && printf 'TELEGRAM_ALLOWED_CHATS=%s\n' "$CHAT_ID"
            } >> ~/.hermes/.env
          fi
          ok "user_id/chat_id 기록 (~/.hermes/.env, chmod 600)"
        fi
      fi

      if ! $_secret_store_available; then
        warn "Fallback: ~/.hermes/.env에 평문 저장 (chmod 600). 가능하면 시크릿 스토어 사용 권장."
        run "mkdir -p ~/.hermes && touch ~/.hermes/.env && chmod 600 ~/.hermes/.env"
        if $DRY_RUN; then
          printf '    [dry-run] <secret op: write TELEGRAM_BOT_TOKEN to ~/.hermes/.env>\n'
        else
          {
            printf 'TELEGRAM_BOT_TOKEN=%s\n' "$BOT_TOKEN"
            printf 'TELEGRAM_ALLOWED_USERS=%s\n' "$USER_ID"
            [[ -n "$CHAT_ID" ]] && printf 'TELEGRAM_ALLOWED_CHATS=%s\n' "$CHAT_ID"
          } >> ~/.hermes/.env
        fi
        ok "Telegram 자격증명 등록됨 (~/.hermes/.env, chmod 600)"
      fi
      unset BOT_TOKEN
    fi
  else
    ok "Telegram 봇 토큰 이미 등록됨"
  fi
fi

# ─── Phase 4b: mini-router 자동 배포 ─────────────────────
if phase_active "4b"; then
  log "Phase 4b: mini-router 배포 (Telegram → tmux forwarder)"

  # Hermes가 있고 gateway가 active이면 충돌 회피
  HERMES_ACTIVE=false
  if command -v hermes >/dev/null 2>&1; then
    if [[ "$OSTYPE" == "linux"* ]]; then
      systemctl --user is-active hermes-gateway.service >/dev/null 2>&1 && HERMES_ACTIVE=true
    elif [[ "$OSTYPE" == "darwin"* ]]; then
      launchctl list 2>/dev/null | grep -q hermes && HERMES_ACTIVE=true
    fi
  fi

  if $HERMES_ACTIVE; then
    warn "Hermes gateway가 이미 active — mini-router 배포 스킵 (충돌 방지)"
    warn "Hermes를 사용하지 않고 mini-router를 배포하려면 Hermes gateway를 먼저 중지 후 재실행"
  else
    # REPO_DIR: clone 루트 감지 (이 스크립트 위치 기준)
    REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
    MINI_ROUTER_DIR="$REPO_DIR/mini-router"

    if [[ ! -f "$MINI_ROUTER_DIR/bot.py" ]]; then
      warn "mini-router/bot.py 없음 ($MINI_ROUTER_DIR) — clone 위치 확인 필요"
    else
      ok "mini-router 소스 감지됨: $MINI_ROUTER_DIR"

      # Python venv 생성 + 의존성 설치
      if [[ ! -d "$MINI_ROUTER_DIR/.venv" ]]; then
        log "Python venv 생성: $MINI_ROUTER_DIR/.venv"
        run "python3 -m venv '$MINI_ROUTER_DIR/.venv'"
      else
        ok "venv 이미 존재함"
      fi

      log "pip 의존성 설치 (python-telegram-bot + pyyaml)"
      run "'$MINI_ROUTER_DIR/.venv/bin/pip' install --quiet 'python-telegram-bot==21.*' pyyaml"
      ok "mini-router 의존성 설치됨"

      # systemd user unit 배포 (Linux)
      if [[ "$OSTYPE" == "linux"* ]]; then
        SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
        UNIT_FILE="$SYSTEMD_USER_DIR/mini-router.service"

        if [[ ! -f "$UNIT_FILE" ]]; then
          if confirm "mini-router.service systemd user unit 배포?"; then
            run "mkdir -p '$SYSTEMD_USER_DIR'"
            run "mkdir -p ~/.hermes/logs"
            if $DRY_RUN; then
              printf '    [dry-run] <create %s from example + sed /home/YOUR_USERNAME/agentic-harness -> %s, YOUR_USERNAME -> %s>\n' "$UNIT_FILE" "$REPO_DIR" "$USER"
            else
              # 1) repo 경로 placeholder를 실제 clone 위치로, 2) 나머지 YOUR_USERNAME을 $USER로
              sed -e "s|/home/YOUR_USERNAME/agentic-harness|$REPO_DIR|g" \
                  -e "s|YOUR_USERNAME|$USER|g" \
                "$REPO_DIR/examples/configs/mini-router.service.example" \
                > "$UNIT_FILE"
              ok "unit 파일 생성됨: $UNIT_FILE"
            fi

            if confirm "systemctl --user enable --now mini-router 실행?"; then
              run "systemctl --user daemon-reload"
              run "systemctl --user enable --now mini-router.service"
              if ! $DRY_RUN; then
                sleep 2
                if systemctl --user is-active mini-router.service >/dev/null 2>&1; then
                  ok "mini-router.service 활성 (systemd user)"
                else
                  err "mini-router.service 기동 실패 — 'journalctl --user -u mini-router' 확인"
                  err "$HOME/.hermes/.env에 TELEGRAM_BOT_TOKEN 설정 여부 확인"
                fi
              fi
            fi
          fi
        else
          ok "mini-router.service unit 이미 존재함: $UNIT_FILE"
        fi
      else
        warn "mini-router systemd unit은 Linux 전용."
        warn "macOS 상시 가동(launchd)은 examples/configs/com.user.mini-router.plist.example 참고,"
        warn "또는 ./scripts/install-mini-router-macos.sh 로 LaunchAgent 자동 설치."
      fi
    fi
  fi
fi

# ─── Phase 5: Claude Code MCP ─────────────────────────────
if phase_active 5; then
  log "Phase 5: Claude Code ↔ Hermes MCP 브리지"

  if ! command -v claude >/dev/null 2>&1; then
    warn "claude CLI 못 찾음"
    if confirm "npm i -g @anthropic-ai/claude-code 로 Claude Code 설치?"; then
      run "npm i -g @anthropic-ai/claude-code"
    else
      warn "Claude Code 설치 후 수동 등록:"
      warn "  claude mcp add hermes --scope user -- hermes mcp serve"
    fi
  fi

  if command -v claude >/dev/null 2>&1; then
    if $DRY_RUN; then
      printf '    [dry-run] claude mcp list | grep hermes || claude mcp add hermes --scope user -- hermes mcp serve\n'
    elif ! claude mcp list 2>/dev/null | grep -qE '^hermes\b'; then
      if command -v hermes >/dev/null 2>&1; then
        log "Claude Code에 Hermes MCP 등록"
        run "claude mcp add hermes --scope user -- hermes mcp serve"
      else
        warn "hermes 없음 — MCP 등록 스킵"
      fi
    else
      ok "Hermes MCP 이미 등록됨"
    fi
  fi
fi

# ─── Phase 6: 상시 가동 ──────────────────────────────────
if phase_active 6; then
  log "Phase 6: 서버 상시 가동"

  if [[ "$OSTYPE" == "darwin"* ]]; then
    # ── macOS: pmset + launchd ──────────────────────────
    if confirm "Sleep 비활성화 (sudo 필요)? 원복 명령: sudo pmset restoredefaults"; then
      run "sudo pmset -a sleep 0 disksleep 0 womp 1 autorestart 1"
      run "sudo pmset -a displaysleep 10"
      ok "Sleep 정책 적용됨 (원복: sudo pmset restoredefaults)"
    fi

    if command -v hermes >/dev/null 2>&1 && confirm "Hermes gateway launchd 등록?"; then
      run "hermes gateway install"
      if ! $DRY_RUN; then
        sleep 2
        if launchctl list | grep -q hermes; then
          ok "Hermes gateway launchd 등록 성공"
        else
          err "launchctl list에서 hermes 못 찾음 — 수동 확인 필요"
        fi
      fi
    fi

  else
    # ── Linux: systemd user unit ────────────────────────
    log "Linux: systemd user unit으로 상시 가동 구성"

    # 1) loginctl enable-linger (sudo 필요)
    LINGER_STATUS="$(loginctl show-user "$USER" -p Linger --value 2>/dev/null || echo no)"
    if [[ "$LINGER_STATUS" != "yes" ]]; then
      if confirm "loginctl enable-linger 설정? (부팅 시 user systemd 서비스 자동 시작, sudo 필요)"; then
        run "sudo loginctl enable-linger '$USER'"
        ok "linger 활성화됨 — 부팅 후 user systemd 서비스 자동 기동"
      fi
    else
      ok "linger 이미 활성화됨"
    fi

    # 2) Hermes gateway systemd user unit
    if command -v hermes >/dev/null 2>&1; then
      HERMES_BIN="$(command -v hermes 2>/dev/null || echo '/usr/local/bin/hermes')"
      SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
      UNIT_FILE="$SYSTEMD_USER_DIR/hermes-gateway.service"

      if [[ ! -f "$UNIT_FILE" ]]; then
        if confirm "hermes-gateway.service systemd user unit 생성 ($UNIT_FILE)?"; then
          if $DRY_RUN; then
            printf '    [dry-run] <create %s>\n' "$UNIT_FILE"
          else
            mkdir -p "$SYSTEMD_USER_DIR" "$HOME/.hermes/logs"
            cat > "$UNIT_FILE" <<UNIT
[Unit]
Description=Hermes AI Gateway
After=network.target
Wants=network.target

[Service]
Type=simple
ExecStart=${HERMES_BIN} gateway run
Restart=on-failure
RestartSec=5
EnvironmentFile=-${HOME}/.hermes/.env
StandardOutput=append:${HOME}/.hermes/logs/gateway.out
StandardError=append:${HOME}/.hermes/logs/gateway.err

[Install]
WantedBy=default.target
UNIT
            ok "unit 파일 생성됨: $UNIT_FILE"
          fi

          if confirm "systemctl --user enable --now hermes-gateway 실행?"; then
            run "systemctl --user daemon-reload"
            run "systemctl --user enable --now hermes-gateway.service"
            if ! $DRY_RUN; then
              sleep 2
              if systemctl --user is-active hermes-gateway.service >/dev/null 2>&1; then
                ok "hermes-gateway.service 활성 (systemd user)"
              else
                err "hermes-gateway.service 기동 실패 — 'journalctl --user -u hermes-gateway' 확인"
              fi
            fi
          fi
        fi
      else
        ok "hermes-gateway.service unit 이미 존재함: $UNIT_FILE"
        if confirm "systemctl --user start hermes-gateway (재시작)?"; then
          run "systemctl --user daemon-reload"
          run "systemctl --user restart hermes-gateway.service"
        fi
      fi
    else
      warn "hermes 없음 — hermes-gateway.service 스킵. mini-router (Phase 4b)를 사용하거나 Hermes 설치 후 재실행."
    fi

    # 3) Sleep/suspend 비활성화
    if confirm "Sleep/suspend 비활성화 (sudo 필요)? 서버 환경 권장."; then
      run "sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target"
      ok "Sleep targets masked (원복: sudo systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target)"
    fi
  fi
fi

# ─── Phase 6b: omo_proxy (OFF-POLICY, --enable-claude-proxy 명시 또는 --only-phase=6b 시에만) ──
# 기본 OFF: --start-phase / 전체 실행으로는 절대 자동 진입 안 함
# 트리거: --only-phase=6b 명시 OR --enable-claude-proxy (또는 ENABLE_CLAUDE_PROXY=1)
_RUN_6B=false
if [[ "$ONLY_PHASE" == "6b" ]]; then
  _RUN_6B=true
elif [[ "$ENABLE_CLAUDE_PROXY" == "1" ]] && phase_active 6; then
  _RUN_6B=true
fi

if $_RUN_6B; then
  warn "===================================================="
  warn "OFF-POLICY 경고: omo_proxy는 Claude OAuth 토큰을"
  warn "3rd-party 도구에서 재사용하는 패턴. Anthropic ToS"
  warn "(2026-04 발효) 위반. 계정 정지 위험. 본인 책임."
  warn "docs/10-claude-oauth-proxy.md 반드시 읽을 것."
  warn "===================================================="

  if ! confirm "위 경고를 이해하고 omo_proxy 배포 계속?"; then
    log "Phase 6b 취소됨"
  else
    log "Phase 6b: omo_proxy 배포"

    OMO_PROXY_DIR="$HOME/omo_proxy"

    if [[ ! -d "$OMO_PROXY_DIR" ]]; then
      run "git clone https://github.com/winglock/omo_proxy '$OMO_PROXY_DIR'"
      ok "omo_proxy 클론됨: $OMO_PROXY_DIR"
    else
      ok "omo_proxy 이미 존재함: $OMO_PROXY_DIR"
    fi

    # credentials.json 이전 안내
    if [[ ! -f ~/.claude/.credentials.json ]]; then
      warn "$HOME/.claude/.credentials.json 없음 — 로컬 Mac에서 아래 명령으로 복사 필요:"
      warn "  scp -p ~/.claude/.credentials.json $(hostname):~/.claude/.credentials.json"
    else
      ok "$HOME/.claude/.credentials.json 존재함"
      run "chmod 600 ~/.claude/.credentials.json"
    fi

    # systemd user unit 배포 (Linux)
    if [[ "$OSTYPE" == "linux"* ]]; then
      SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
      OMO_UNIT="$SYSTEMD_USER_DIR/omo-proxy.service"

      if [[ ! -f "$OMO_UNIT" ]]; then
        REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
        if [[ -f "$REPO_DIR/examples/configs/omo-proxy.service.example" ]]; then
          run "mkdir -p '$SYSTEMD_USER_DIR'"
          if $DRY_RUN; then
            printf '    [dry-run] <create %s from example + sed /home/YOUR_USERNAME/agentic-harness -> %s, YOUR_USERNAME -> %s>\n' "$OMO_UNIT" "$REPO_DIR" "$USER"
          else
            # mini-router unit과 동일한 placeholder 치환 순서 유지
            sed -e "s|/home/YOUR_USERNAME/agentic-harness|$REPO_DIR|g" \
                -e "s|YOUR_USERNAME|$USER|g" \
              "$REPO_DIR/examples/configs/omo-proxy.service.example" \
              > "$OMO_UNIT"
            ok "omo-proxy.service 생성됨: $OMO_UNIT"
          fi
        else
          warn "omo-proxy.service.example 없음 — 수동 생성 필요"
        fi
      else
        ok "omo-proxy.service 이미 존재함"
      fi

      if confirm "systemctl --user enable --now omo-proxy 실행?"; then
        run "systemctl --user daemon-reload"
        run "systemctl --user enable --now omo-proxy.service"
        if ! $DRY_RUN; then
          sleep 2
          if systemctl --user is-active omo-proxy.service >/dev/null 2>&1; then
            ok "omo-proxy.service 활성 (systemd user)"
          else
            err "omo-proxy.service 기동 실패 — 'journalctl --user -u omo-proxy' 확인"
            warn "$HOME/.claude/.credentials.json 이전 후 재시작 필요할 수 있음"
          fi
        fi
      fi
    else
      warn "omo_proxy systemd unit은 Linux 전용. macOS는 launchd 직접 구성 또는 foreground 실행."
      warn "  cd ~/omo_proxy && node proxy.js"
    fi
  fi
fi

# ─── Phase 7: 검증 ───────────────────────────────────────
if phase_active 7; then
  log "Phase 7: 검증"

  if $DRY_RUN; then
    warn "dry-run 모드 — 검증은 실제 실행이 필요하므로 건너뜀"
  else
    # verify-phase7.sh 자동 호출
    REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
    VERIFY_SCRIPT="$REPO_DIR/scripts/verify-phase7.sh"

    if [[ -f "$VERIFY_SCRIPT" && -x "$VERIFY_SCRIPT" ]]; then
      log "verify-phase7.sh 자동 호출..."
      "$VERIFY_SCRIPT" --quick || warn "verify-phase7.sh 일부 항목 실패 — 위 출력 확인"
    else
      warn "verify-phase7.sh 못 찾음 ($VERIFY_SCRIPT) — 수동 실행: ./scripts/verify-phase7.sh"
      # 간략 inline 검증
      codex login status >/dev/null 2>&1   && ok "Codex OAuth: 활성"           || warn "Codex OAuth: 비활성 또는 만료"
      command -v opencode >/dev/null 2>&1  && ok "opencode: 경로 확인됨"        || warn "opencode 미설치 또는 미동작"
      command -v hermes >/dev/null 2>&1    && ok "Hermes: 경로 확인됨"          || warn "Hermes 미설치 (mini-router 사용 중이면 무시 OK)"
    fi
  fi
fi

echo
log "Phase 설치 완료"
echo
echo "다음 단계:"
echo "  1. examples/soul/ 의 SOUL/USER/MEMORY 템플릿 참고해서 본인 정보로 채우기"
echo "  2. 폰 Telegram #scratch 토픽에서 'echo test' 입력 → 봇 응답 확인"
echo "  3. ./scripts/healthcheck.sh 로 종합 상태 점검"
echo "  4. ./scripts/verify-phase7.sh 로 round-trip 검증"
echo "  5. Phase 8~17 진행: playbook/PLAYBOOK.md §9 부터"
if [[ "$ENABLE_CLAUDE_PROXY" == "1" ]]; then
  echo
  warn "omo_proxy (OFF-POLICY) 활성화됨. docs/10-claude-oauth-proxy.md 참고."
  warn "  ss -tlnp | grep 34156   # listen 확인"
  warn "  tail -f ~/omo_proxy/proxy.log"
fi
echo
