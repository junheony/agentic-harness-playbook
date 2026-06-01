#!/usr/bin/env bash
# hermes-feedback.sh
# Paperclip routine 끝(rollup phase)에 호출. 오늘 사이클을 한 줄로 요약 후
# Hermes Memory에 추가 → 다음 세션부터 reviewer/router 컨텍스트로 흘러들어감.
#
# 사용:
#   ./scripts/hermes-feedback.sh <topic> <one-line-summary>
#   echo "summary" | ./scripts/hermes-feedback.sh <topic>
#   ./scripts/hermes-feedback.sh <topic> --from-file <path>
#
# 환경변수:
#   HERMES_CMD       hermes binary path (default: hermes)
#   MAX_LINE_LEN     line truncation (default: 200)
#   DRY_RUN=1        memory 추가 X, 출력만

set -uo pipefail

HERMES_CMD="${HERMES_CMD:-hermes}"
MAX_LINE_LEN="${MAX_LINE_LEN:-200}"
DRY_RUN="${DRY_RUN:-0}"

if [[ $# -lt 1 ]]; then
  cat >&2 <<EOF
Usage:
  $0 <topic> <one-line-summary>
  echo "summary" | $0 <topic>
  $0 <topic> --from-file <path>

Topic 예시: quant-loop, content-studio, research-lab, dashboard, project-bootstrap
EOF
  exit 1
fi

TOPIC="$1"; shift

# 입력 소스 결정
if [[ $# -eq 0 ]]; then
  if [[ ! -t 0 ]]; then
    SUMMARY=$(cat)
  else
    echo "ERROR: no summary provided (arg, stdin, or --from-file)" >&2
    exit 1
  fi
elif [[ "$1" == "--from-file" ]]; then
  shift
  [[ -r "${1:-}" ]] || { echo "ERROR: cannot read file $1" >&2; exit 1; }
  SUMMARY=$(<"$1")
else
  SUMMARY="$*"
fi

# 정규화: 공백 정리, 개행 제거, 길이 자르기
SUMMARY=$(printf '%s' "$SUMMARY" | tr -d '\r' | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g; s/^[[:space:]]+//; s/[[:space:]]+$//')
if [[ ${#SUMMARY} -gt $MAX_LINE_LEN ]]; then
  SUMMARY="${SUMMARY:0:$MAX_LINE_LEN}..."
fi

[[ -z "$SUMMARY" ]] && { echo "ERROR: empty summary after normalization" >&2; exit 1; }

DATE=$(date +%Y-%m-%d)
LINE="[$TOPIC $DATE] $SUMMARY"

if [[ "$DRY_RUN" == "1" ]]; then
  echo "[dry-run] would add to Hermes Memory:"
  echo "  $LINE"
  exit 0
fi

# Hermes CLI 우선, 없으면 MEMORY.md 직접 append (chmod 600 유지)
if command -v "$HERMES_CMD" >/dev/null 2>&1; then
  if "$HERMES_CMD" memory add "$LINE" 2>/dev/null; then
    echo "✓ Memory updated via $HERMES_CMD"
    exit 0
  fi
  echo "⚠ hermes memory add 실패, MEMORY.md 직접 append로 fallback" >&2
fi

MEM_FILE="$HOME/.hermes/MEMORY.md"
# MEMORY.md 없으면 자동 생성 (Hermes 셋업 안 됐어도 feedback 누적 시작)
if [[ ! -f "$MEM_FILE" ]]; then
  mkdir -p "$(dirname "$MEM_FILE")"
  cat > "$MEM_FILE" <<'TPL'
# Memory
> 환경/프로젝트/도구 노트. Hermes가 자동 갱신. 2,200자 한도 (consolidate 트리거).

## Feedback Loop
(routine rollup이 매 사이클 끝에 한 줄 추가)

TPL
  chmod 600 "$MEM_FILE"
fi

# MEMORY.md의 "## Feedback Loop" 섹션을 만들거나 그 아래 append
if ! grep -q "^## Feedback Loop" "$MEM_FILE"; then
  printf '\n## Feedback Loop\n(routine rollup이 매 사이클 끝에 한 줄 추가)\n\n' >> "$MEM_FILE"
fi

# 80% 임계치 체크 — MEMORY.md가 2200자 한도라고 가정
BYTES=$(wc -c <"$MEM_FILE")
LIMIT=2200
if (( BYTES * 100 / LIMIT > 80 )); then
  echo "⚠ MEMORY.md ${BYTES}/${LIMIT} bytes (>80%) — consolidate 필요" >&2
  if command -v "$HERMES_CMD" >/dev/null 2>&1; then
    echo "  → 시도: $HERMES_CMD consolidate --force"
    "$HERMES_CMD" consolidate --force 2>/dev/null || true
  fi
fi

# append
{
  printf -- '- %s\n' "$LINE"
} >> "$MEM_FILE"

# 권한 유지
chmod 600 "$MEM_FILE" 2>/dev/null || true

echo "✓ MEMORY.md updated (append): $LINE"
