#!/usr/bin/env bash
# test-router.sh
# Router SKILL.md의 라우팅 룰을 unit-test 한다.
#
# 동작 원리:
#   - test_cases.txt 의 각 줄 (`<input>|<expected_target>` 형식) 을 읽는다
#   - 정해진 패턴 매칭 로직(이 스크립트가 router SKILL.md의 룰을 mirror)으로 라우팅 결과를 계산
#   - 결과를 expected와 비교
#
# 본 스크립트는 router 룰 변경 시 회귀 테스트용. router SKILL.md를 직접 파싱하지는 않음 —
# 룰 동기화는 수동. router 룰 변경 시 본 스크립트도 같이 수정해야 함.

set -uo pipefail

if [[ -t 1 ]]; then
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; NC=$'\033[0m'
else
  RED=''; GREEN=''; NC=''
fi

TESTS_FILE="${1:-$(dirname "$0")/test_cases.txt}"

# 라우팅 함수 (router SKILL.md의 Rule 1-7 로직을 단순화 mirror)
classify() {
  local msg="$1"
  local msg_lower
  msg_lower=$(printf '%s' "$msg" | tr '[:upper:]' '[:lower:]')

  # Rule 1: 명시 prefix
  case "$msg" in
    "cc:"*|"cc>"*) echo "claude-code"; return ;;
    "oc:"*|"oc>"*) echo "opencode"; return ;;
    "hm:"*|"hm>"*) echo "hermes-self"; return ;;
    "pc:"*|"pc>"*) echo "paperclip"; return ;;
    "ob:"*|"ob>"*) echo "obsidian"; return ;;
  esac

  # Rule 2: ulw / hyperplan
  if echo "$msg_lower" | grep -qE '\b(hpp\s*ulw|hyperplan)\b'; then
    echo "opencode-omo-hyperplan"; return
  fi
  if echo "$msg_lower" | grep -qE '\b(ulw|ultrawork|풀세트|폭주)\b'; then
    echo "opencode-omo"; return
  fi

  # Rule 6: read-only / status (paperclip 생성 의도 단어가 같이 오면 Rule 4로 양보)
  if echo "$msg_lower" | grep -qE '(상태|지금 뭐|현재|status|로그|last log|에러 있어|잔고|포지션|pnl)'; then
    echo "hermes-self"; return
  fi
  if echo "$msg_lower" | grep -qE '(오늘 일정|예약)' && ! echo "$msg_lower" | grep -qE '(만들어|추가|새 |create)'; then
    echo "hermes-self"; return
  fi

  # Rule 3: methodology
  if echo "$msg_lower" | grep -qE '(brainstorm|설계|기획|discovery)'; then
    echo "claude-code+brainstorming"; return
  fi
  if echo "$msg_lower" | grep -qE '(tdd|red-green|테스트부터)'; then
    echo "claude-code+tdd"; return
  fi
  if echo "$msg_lower" | grep -qE '(리뷰|code review|pr 검토)'; then
    echo "claude-code+code-reviewer"; return
  fi
  if echo "$msg_lower" | grep -qE '(debug|디버그|에러 분석|crash)'; then
    echo "claude-code+debugger"; return
  fi

  # Rule 4: domain
  if echo "$msg_lower" | grep -qE '(excel|xlsx|csv|재무 모델|dcf|pivot)'; then
    echo "claude-code+xlsx"; return
  fi
  if echo "$msg_lower" | grep -qE '(schema|migration|explain|postgres|mysql|query plan|slow query)'; then
    echo "claude-code+postgres"; return
  fi
  if echo "$msg_lower" | grep -qE '(ghidra|reverse|disassembl|binary|crackme)'; then
    echo "opencode+reverse-engineering"; return
  fi
  if echo "$msg_lower" | grep -qE '(vault|노트|obsidian|daydream)'; then
    echo "claude-code+obsidian"; return
  fi
  if echo "$msg_lower" | grep -qE '(회사|agent team|routine|스케줄|cron|매일|매주)'; then
    echo "paperclip"; return
  fi

  echo "ambiguous"
}

# 기본 test cases
if [[ ! -f "$TESTS_FILE" ]]; then
  cat > "$(dirname "$0")/test_cases.txt" <<'EOF'
# 형식: <input>|<expected_target>
# (라인 시작 # 은 주석)
cc> 이 함수 리팩토링|claude-code
oc> opencode 직접|opencode
ulw 보안 감사|opencode-omo
ultrawork 전체 모듈 가스 최적화|opencode-omo
hpp ulw 보안 감사|opencode-omo-hyperplan
hyperplan 컨센서스|opencode-omo-hyperplan
brainstorm 새 기능 설계|claude-code+brainstorming
TDD로 함수 작성|claude-code+tdd
이 PR 리뷰해줘|claude-code+code-reviewer
debug 이 crash|claude-code+debugger
xlsx로 DCF 모델 작성|claude-code+xlsx
postgres EXPLAIN ANALYZE 결과|claude-code+postgres
ghidra로 바이너리 reverse|opencode+reverse-engineering
vault에서 어제 노트 찾아|claude-code+obsidian
새 routine 만들어줘 매일 9시|paperclip
지금 뭐 돌고 있어|hermes-self
상태|hermes-self
EOF
  TESTS_FILE="$(dirname "$0")/test_cases.txt"
  echo "test_cases.txt 생성됨 — 본 기본 케이스로 진행"
fi

pass=0; fail=0
while IFS= read -r line; do
  [[ -z "$line" || "$line" == \#* ]] && continue
  input="${line%%|*}"
  expected="${line##*|}"
  actual=$(classify "$input")
  if [[ "$actual" == "$expected" ]]; then
    printf '%s✓%s %-50s → %s\n' "$GREEN" "$NC" "$input" "$actual"
    pass=$((pass+1))
  else
    printf '%s✗%s %-50s → got=%s, expected=%s\n' "$RED" "$NC" "$input" "$actual" "$expected"
    fail=$((fail+1))
  fi
done < "$TESTS_FILE"

echo
echo "PASS=$pass FAIL=$fail"
(( fail == 0 ))
