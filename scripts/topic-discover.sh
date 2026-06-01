#!/usr/bin/env bash
# topic-discover.sh
# Telegram Forum Topics의 message_thread_id를 캡처해서 topic_map.yaml에 자동 등록.
#
# 사용 시나리오:
#   1. Telegram 앱에서 슈퍼그룹 → + 버튼으로 새 토픽 생성 (이름 자유)
#   2. 그 토픽에서 봇한테 한 줄 메시지 (예: "register" / 임의 텍스트)
#   3. 본 스크립트를 서버에서 실행 → 그 메시지의 thread_id 캡처 → 사용자가
#      매핑 정보 (workdir, default_harness, skills_extra) 입력 → topic_map.yaml 갱신
#
# 사용:
#   ./scripts/topic-discover.sh                        # 인터랙티브 (1회)
#   ./scripts/topic-discover.sh --watch                # 백그라운드 폴링 모드
#   ./scripts/topic-discover.sh --list                 # 현재 등록된 매핑 출력
#
# 환경변수:
#   TELEGRAM_BOT_TOKEN       (필수, secret-tool 또는 .env에서)
#   TELEGRAM_ALLOWED_CHATS   매핑 대상 chat_id 화이트리스트 (기본: ~/.hermes/.env 참조)
#   TOPIC_MAP_PATH           (default: ~/.hermes/topic_map.yaml)

set -uo pipefail

TOPIC_MAP_PATH="${TOPIC_MAP_PATH:-${HOME}/.hermes/topic_map.yaml}"
MODE="interactive"

for arg in "$@"; do
  case $arg in
    --watch) MODE="watch" ;;
    --list)  MODE="list" ;;
    -h|--help)
      sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
  esac
done

if [[ -t 1 ]]; then
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'
  BLUE=$'\033[0;34m'; NC=$'\033[0m'
else
  RED=''; GREEN=''; BLUE=''; NC=''
fi

# ─── 토큰 조회 (secret-tool → env → .env) ──────────────
get_token() {
  local t=""
  if [[ "$OSTYPE" == "darwin"* ]] && command -v security >/dev/null 2>&1; then
    t=$(security find-generic-password -a hermes -s telegram-bot-token -w 2>/dev/null || true)
  fi
  if [[ -z "$t" ]] && command -v secret-tool >/dev/null 2>&1; then
    # canonical 속성 순서: service hermes account <secret-name>
    t=$(secret-tool lookup service hermes account telegram-bot-token 2>/dev/null || true)
  fi
  [[ -z "$t" ]] && t="${TELEGRAM_BOT_TOKEN:-}"
  if [[ -z "$t" && -r ~/.hermes/.env ]]; then
    t=$(grep -E '^TELEGRAM_BOT_TOKEN=' ~/.hermes/.env 2>/dev/null | tail -1 | cut -d= -f2-)
  fi
  printf '%s' "$t"
}

TG_TOKEN=$(get_token)
if [[ -z "$TG_TOKEN" ]]; then
  echo "${RED}✗${NC} TELEGRAM_BOT_TOKEN 미설정. secret-tool / .env 확인" >&2
  exit 1
fi

# 허용 chat 화이트리스트 (.env에서)
ALLOWED=""
if [[ -r ~/.hermes/.env ]]; then
  ALLOWED=$(grep -E '^TELEGRAM_ALLOWED_CHATS=' ~/.hermes/.env 2>/dev/null | tail -1 | cut -d= -f2-)
fi

# ─── topic_map.yaml 보장 ──────────────────────────────
ensure_topic_map() {
  if [[ ! -f "$TOPIC_MAP_PATH" ]]; then
    mkdir -p "$(dirname "$TOPIC_MAP_PATH")"
    cat > "$TOPIC_MAP_PATH" <<'EOF'
# Auto-generated topic_map (편집 가능).
# 각 topic_id (Forum thread_id)에 워크디렉토리/하네스/스킬 매핑.
topics: {}
EOF
  fi
}
ensure_topic_map

# ─── list 모드 ────────────────────────────────────────
if [[ "$MODE" == "list" ]]; then
  echo "${BLUE}현재 등록된 매핑${NC} ($TOPIC_MAP_PATH):"
  cat "$TOPIC_MAP_PATH"
  exit 0
fi

# ─── update 폴링 로직 ─────────────────────────────────
seen_threads=()
last_offset=0

fetch_updates() {
  local limit="${1:-10}"
  curl -fsS "https://api.telegram.org/bot${TG_TOKEN}/getUpdates?limit=${limit}&offset=${last_offset}&timeout=2" 2>/dev/null || echo "{}"
}

extract_topic_event() {
  # 새 thread_id를 stdout으로 한 줄씩 출력: "<chat_id>|<thread_id>|<user>|<text>"
  local raw="$1"
  printf '%s' "$raw" | jq -r '
    .result[] |
    select(.message != null and .message.message_thread_id != null) |
    "\(.update_id)|\(.message.chat.id)|\(.message.message_thread_id)|\(.message.from.id)|\(.message.text // "(no text)")"
  ' 2>/dev/null
}

is_allowed_chat() {
  local chat_id="$1"
  [[ -z "$ALLOWED" ]] && return 0
  printf '%s' "$ALLOWED" | tr ',' '\n' | grep -q "^${chat_id}$"
}

is_seen() {
  local key="$1"
  for k in "${seen_threads[@]}"; do
    [[ "$k" == "$key" ]] && return 0
  done
  return 1
}

# ─── 사용자 입력 받아 매핑 entry 작성 ─────────────────
prompt_for_mapping() {
  local chat_id="$1" thread_id="$2" sample_text="$3"

  echo
  echo "${GREEN}━━━ 새 토픽 발견 ━━━${NC}"
  echo "  chat_id    : $chat_id"
  echo "  thread_id  : $thread_id"
  echo "  첫 메시지   : ${sample_text:0:80}"
  echo
  read -rp "이 토픽의 별칭 (예: my-app, 빈 값=skip): " topic_name
  [[ -z "$topic_name" ]] && { echo "  → skip"; return; }

  read -rp "워크디렉토리 (default: ~/dev/${topic_name}): " workdir
  workdir="${workdir:-~/dev/${topic_name}}"

  read -rp "기본 하네스 [self/claude-code/opencode] (default: opencode): " harness
  harness="${harness:-opencode}"

  read -rp "추가 스킬 (콤마 구분, 빈 값 OK): " skills_csv

  # yq 있으면 사용, 없으면 직접 append
  if command -v yq >/dev/null 2>&1; then
    yq -i ".topics.\"${topic_name}\" = {
      \"topic_id\": ${thread_id},
      \"chat_id\": ${chat_id},
      \"workdir\": \"${workdir}\",
      \"default_harness\": \"${harness}\",
      \"skills_extra\": [$(echo "$skills_csv" | awk -F, '{for(i=1;i<=NF;i++) printf (i>1?\",\":\"\")\"\\\"\"$i\"\\\"\"}')],
      \"registered_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
    }" "$TOPIC_MAP_PATH"
  else
    # 단순 append (YAML 들여쓰기 가정)
    cat >> "$TOPIC_MAP_PATH" <<EOF

  ${topic_name}:
    topic_id: ${thread_id}
    chat_id: ${chat_id}
    workdir: "${workdir}"
    default_harness: "${harness}"
    skills_extra: [$(printf '%s' "$skills_csv" | sed -E 's/([^,]+)/"\1"/g')]
    registered_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
EOF
  fi

  echo "${GREEN}✓${NC} ${topic_name} 등록 완료 (thread_id=${thread_id})"
  echo "  → ${TOPIC_MAP_PATH}"
  echo "  → Hermes/router 가 다음 사이클부터 인식. 필요 시 \`systemctl --user restart hermes-gateway\`"
}

# ─── 메인 루프 ────────────────────────────────────────
echo "${BLUE}topic-discover${NC} ($MODE 모드) — Ctrl+C로 종료"
echo "Bot @$(curl -fsS "https://api.telegram.org/bot${TG_TOKEN}/getMe" 2>/dev/null | jq -r '.result.username // "?"')"
echo "감시 chat_id: ${ALLOWED:-(all)}"
echo "topic_map: $TOPIC_MAP_PATH"
echo

while true; do
  updates=$(fetch_updates 20)
  while IFS='|' read -r update_id chat_id thread_id _ text; do
    [[ -z "$update_id" ]] && continue
    last_offset=$((update_id + 1))
    is_allowed_chat "$chat_id" || continue
    key="${chat_id}/${thread_id}"
    is_seen "$key" && continue
    seen_threads+=("$key")
    prompt_for_mapping "$chat_id" "$thread_id" "$text"
    [[ "$MODE" == "interactive" ]] && { echo "interactive 모드 — 1개 처리 후 종료"; exit 0; }
  done < <(extract_topic_event "$updates")

  [[ "$MODE" == "interactive" ]] || sleep 3
done
