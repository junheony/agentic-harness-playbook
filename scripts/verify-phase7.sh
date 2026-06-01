#!/usr/bin/env bash
# verify-phase7.sh
# Phase 1~7 통합 검증. install-all.sh 완료 후 실행해서 각 컴포넌트 동작 확인.
#
# 본 스크립트는 healthcheck.sh보다 한 단계 위:
#   - healthcheck.sh: "지금 살아있나" (cron-friendly)
#   - verify-phase7.sh: "실제 round-trip이 작동하나" (셋업 완료 검증용)
#
# 사용:
#   ./scripts/verify-phase7.sh             # 인터랙티브
#   ./scripts/verify-phase7.sh --quick     # 자동 모드, 대화형 검증 생략

set -uo pipefail

QUICK=false
for arg in "$@"; do
  case $arg in
    --quick) QUICK=true ;;
    -h|--help)
      sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
  esac
done

if [[ -t 1 ]]; then
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; NC=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; NC=''
fi

# 비인터랙티브 SSH 환경에서도 사용자가 설치한 도구 찾도록 PATH 보강
export PATH="$HOME/.opencode/bin:$HOME/.local/bin:$HOME/.npm-global/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
PASS=0; FAIL=0
ok()   { printf '%s✓%s %s\n' "$GREEN" "$NC" "$*"; PASS=$((PASS+1)); }
err()  { printf '%s✗%s %s\n' "$RED"   "$NC" "$*" >&2; FAIL=$((FAIL+1)); }
warn() { printf '%s⚠%s %s\n' "$YELLOW" "$NC" "$*"; }

echo "── Phase 1: Codex OAuth round-trip ──"
if codex login status >/dev/null 2>&1; then
  ok "codex login status"
  # 실제 응답 round-trip은 codex CLI 버전마다 출력 schema가 달라서
  # JSON parse 대신 plain text 매칭으로 변경. trust-check도 우회.
  if $QUICK; then
    warn "--quick: codex round-trip 검증 스킵"
  else
    response=$(printf 'Reply ONLY with the word OK\n' | \
      codex exec --skip-git-repo-check 2>/dev/null || \
      codex exec 2>/dev/null || \
      true)
    if printf '%s' "$response" | grep -qi 'OK'; then
      ok "Codex round-trip 응답 (OK 확인)"
    else
      warn "Codex round-trip 응답 확인 안 됨 (CLI 버전 의존). 수동 검증: codex exec 'hi'"
    fi
  fi
else
  err "Codex OAuth 비활성"
fi

echo
echo "── Phase 2: opencode ──"
if command -v opencode >/dev/null 2>&1; then
  ok "opencode 명령 PATH"
  if [[ -f ~/.config/opencode/opencode.jsonc ]] || [[ -f ~/.config/opencode/opencode.json ]]; then
    ok "opencode config 존재"
  else
    err "$HOME/.config/opencode/opencode.{json,jsonc} 둘 다 없음"
  fi
else
  err "opencode 미설치"
fi

echo
echo "── Phase 3: Hermes 5 pillar ──"
for f in SOUL.md USER.md MEMORY.md; do
  if [[ -f ~/.hermes/$f ]]; then
    ok "$HOME/.hermes/$f 존재"
  else
    err "$HOME/.hermes/$f 없음"
  fi
done

if [[ -d ~/.hermes/skills ]]; then
  ok "$HOME/.hermes/skills/ 디렉토리"
else
  err "$HOME/.hermes/skills/ 디렉토리 없음"
fi

if ! $QUICK && command -v hermes >/dev/null 2>&1; then
  # Skill auto-creation은 3회 반복이 필요 — manual 테스트
  warn "Skill auto-creation 검증은 수동: 같은 패턴 3회 반복 후 ~/.hermes/skills/ 확인"
fi

echo
echo "── Phase 4: Telegram gateway ──"
# 시크릿 조회 순서: macOS Keychain → Linux secret-tool → Linux pass → env
TG_TOKEN=""
if [[ "$OSTYPE" == "darwin"* ]] && command -v security >/dev/null 2>&1; then
  TG_TOKEN=$(security find-generic-password -a hermes -s telegram-bot-token -w 2>/dev/null || true)
fi
if [[ -z "$TG_TOKEN" ]] && command -v secret-tool >/dev/null 2>&1; then
  # canonical 속성 순서: service hermes account <secret-name>
  TG_TOKEN=$(secret-tool lookup service hermes account telegram-bot-token 2>/dev/null || true)
fi
if [[ -z "$TG_TOKEN" ]] && command -v pass >/dev/null 2>&1; then
  TG_TOKEN=$(pass show hermes/telegram-bot-token 2>/dev/null || true)
fi
[[ -z "$TG_TOKEN" ]] && TG_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
# Also try ~/.hermes/.env (chmod 600 fallback)
if [[ -z "$TG_TOKEN" && -r ~/.hermes/.env ]]; then
  TG_TOKEN=$(grep -E '^TELEGRAM_BOT_TOKEN=' ~/.hermes/.env 2>/dev/null | tail -1 | cut -d= -f2-)
fi

if [[ -n "$TG_TOKEN" ]]; then
  if curl -fs "https://api.telegram.org/bot${TG_TOKEN}/getMe" >/dev/null; then
    ok "Telegram Bot API getMe 통과"
  else
    err "Telegram Bot API 호출 실패 (토큰 invalid?)"
  fi
else
  err "Telegram bot token 미설정"
fi

echo
echo "── Phase 5: Claude Code MCP ──"
if command -v claude >/dev/null 2>&1; then
  if claude mcp list 2>/dev/null | grep -qE '^hermes.*Connected'; then
    ok "Claude Code: hermes MCP Connected"
  else
    err "Claude Code: hermes MCP Connected 아님"
  fi
else
  warn "claude CLI 없음 — MCP 체크 스킵"
fi

echo
echo "── Phase 6: 상시 가동 ──"
if [[ "$OSTYPE" == "darwin"* ]]; then
  pmset_sleep=$(pmset -g | awk '/^ *sleep/ {print $2}')
  if [[ "$pmset_sleep" == "0" ]]; then
    ok "Sleep 비활성화 (pmset sleep=0)"
  else
    err "Sleep 비활성화 안 됨 (pmset sleep=$pmset_sleep)"
  fi
  if launchctl list 2>/dev/null | grep -q hermes; then
    ok "Hermes gateway launchd 등록됨"
  else
    warn "Hermes gateway launchd 미등록 (Hermes 미사용 시 무시 OK)"
  fi
else
  # Linux systemd
  linger=$(loginctl show-user "$USER" -p Linger --value 2>/dev/null)
  if [[ "$linger" == "yes" ]]; then
    ok "linger 활성화 (부팅 시 user 서비스 시작)"
  else
    warn "linger 비활성화 — \`sudo loginctl enable-linger $USER\` 권장"
  fi
  # mini-router 또는 hermes-gateway 중 하나라도 active이면 OK
  for unit in mini-router hermes-gateway; do
    if systemctl --user is-active "$unit.service" >/dev/null 2>&1; then
      ok "systemd user service: $unit.service active"
    fi
  done
fi

echo
echo "── Phase 7: 통합 시나리오 (수동) ──"
warn "다음은 폰에서 실제 진행해야 검증됨:"
warn "  1. Telegram #scratch 토픽에 'echo test' 전송 → 봇 응답 받기"
warn "  2. Telegram에 'cc> hello' 전송 → Claude Code 위임 확인"
warn "  3. Telegram에 'ulw hello' 전송 → opencode-omo Sisyphus 활성화 확인"

echo
echo "═══════════════════════════════════════════════"
printf ' 자동 검증: PASS %s%d%s | FAIL %s%d%s\n' \
  "$GREEN" "$PASS" "$NC" "$RED" "$FAIL" "$NC"
echo "═══════════════════════════════════════════════"

if (( FAIL > 0 )); then
  echo
  echo "→ docs/06-troubleshooting.md 의 해당 컴포넌트 섹션 참고"
  exit 1
fi
