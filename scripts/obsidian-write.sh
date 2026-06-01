#!/usr/bin/env bash
#
# obsidian-write.sh — Obsidian Local REST API로 vault에 노트 작성/append
#
# 사용법:
#   obsidian-write.sh <vault-relative-path> [content]
#   echo "content" | obsidian-write.sh <vault-relative-path>
#
# 예:
#   obsidian-write.sh "03-Daily-Reports/2026-05-28.md" "# 오늘 리포트"
#   git log -5 | obsidian-write.sh "inbox/recent-commits.md"
#   OBSIDIAN_METHOD=POST obsidian-write.sh "inbox/log.md" "- append 한 줄"
#
# 환경변수:
#   OBSIDIAN_HOST    REST API 호스트 (기본: 127.0.0.1 — 원격이면 Mac Tailscale IP)
#   OBSIDIAN_PORT    REST API 포트 (기본: 27124, HTTPS)
#   OBSIDIAN_METHOD  PUT(덮어쓰기, 기본) | POST(append)
#
# API key 조회 순서 (canonical):
#   1. macOS Keychain : security find-generic-password -a hermes -s obsidian-rest-api-key -w
#   2. Linux libsecret: secret-tool lookup service hermes account obsidian-rest-api-key

set -euo pipefail

usage() {
  echo "usage: $(basename "$0") <vault-relative-path> [content]   (content 생략 시 stdin에서 읽음)" >&2
  exit 1
}

[[ $# -ge 1 ]] || usage

NOTE_PATH="${1#/}" # 앞 슬래시 제거 — vault-relative 경로 강제

if [[ $# -ge 2 ]]; then
  CONTENT="$2"
else
  CONTENT="$(cat)"
fi

HOST="${OBSIDIAN_HOST:-127.0.0.1}"
PORT="${OBSIDIAN_PORT:-27124}"
METHOD="${OBSIDIAN_METHOD:-PUT}"

case "$METHOD" in
  PUT | POST) ;;
  *)
    echo "OBSIDIAN_METHOD 는 PUT 또는 POST 만 지원: ${METHOD}" >&2
    exit 1
    ;;
esac

get_api_key() {
  # macOS Keychain 우선
  if command -v security >/dev/null 2>&1; then
    security find-generic-password -a hermes -s obsidian-rest-api-key -w 2>/dev/null && return 0
  fi
  # Linux libsecret — canonical: service hermes account <secret-name>
  if command -v secret-tool >/dev/null 2>&1; then
    secret-tool lookup service hermes account obsidian-rest-api-key 2>/dev/null && return 0
  fi
  return 1
}

API_KEY="$(get_api_key)" || {
  echo "API key 조회 실패." >&2
  echo "  macOS : security add-generic-password -a hermes -s obsidian-rest-api-key -w '<KEY>'" >&2
  echo "  Linux : printf '%s' '<KEY>' | secret-tool store --label='Obsidian Local REST API' service hermes account obsidian-rest-api-key" >&2
  exit 1
}

# 경로 URL 인코딩 (공백/한글 파일명 대응) — '/' 는 보존
if command -v jq >/dev/null 2>&1; then
  ENC_PATH="$(printf '%s' "$NOTE_PATH" | jq -sRr '@uri' | sed 's|%2F|/|g')"
else
  ENC_PATH="$NOTE_PATH"
fi

# self-signed cert 이므로 -k (Tailscale/LAN 내부 전용 전제)
# content는 stdin(@-)으로 전달 — '@' / '-' 로 시작하는 본문도 안전
printf '%s' "$CONTENT" | curl -fsSk -X "$METHOD" \
  -H "Authorization: Bearer ${API_KEY}" \
  -H "Content-Type: text/markdown" \
  --data-binary @- \
  "https://${HOST}:${PORT}/vault/${ENC_PATH}"
