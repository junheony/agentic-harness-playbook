# Quant Research-Action Loop (Paperclip Company 예시)

> 매일 자동으로 시장 데이터 수집 → 분석 → 리뷰 → 액션 게이트 → 실행 → 회고. 사람은 Board approval 게이트에서만 개입.

## 왜 이 패턴?

"agent가 쉬지 않고 일하는 시스템"을 만드는 가장 안전한 방법은:

1. **단방향 파이프라인** — 각 단계가 다음 단계의 입력을 파일로 남김 (idempotent)
2. **명시적 state machine** — 파일명에 status 인코딩 → 어디서 멈췄는지 자명
3. **Board approval 게이트** — 자금/외부 게시는 무조건 사람 승인
4. **Memory feedback loop** — 매 사이클 끝에 Hermes Memory에 한 줄 회고 → 다음 사이클부터 reviewer 컨텍스트로 들어감

이 패턴은 quant 도메인 외에도 적용 가능 (콘텐츠 생성, 보안 모니터링, 신규 상품 추천 등).

---

## 회사 정의

```yaml
name: quant-research-action-loop
description: 일일 시장 데이터 → 분석 → 리뷰 → 액션 게이트 → 실행 → 회고 루프
purpose: 시장 신호 발견 + 안전한 액션 실행 자동화

# 작업 디렉토리 (project-specific path)
workdir: ~/dev/<project-quant>

# 출력 경로 (vault 안)
output_root: ~/Documents/SecondBrain/09-Quant-Reports

# 알람/승인 채널
telegram_topic: "#ops"
board_approval_topic: "#ops"

# 의존 리소스
mcp_servers:
  - postgres   # 시계열 시장 데이터
  - filesystem # 보고서 read/write
  - paperclip  # routine 트리거
```

---

## State Machine

각 일일 리포트는 한 사이클에서 다음 상태를 거침. 파일명에 status 인코딩 → 어디서 멈췄는지 명시.

```
draft        → ingest 완료, 아직 reviewer 안 봄
reviewed     → reviewer 평가 끝, actions.json 생성됨
pending      → Board approval 대기
approved     → Board 승인됨, executor 진입 가능
executing    → executor 작업 중 (lock 역할)
done         → 사이클 정상 종료
failed       → 어느 단계든 실패 (audit log에 원인)
aborted      → Board 거부 또는 timeout
```

파일명: `YYYY-MM-DD-{slug}-{status}.md`
예: `2026-05-27-momentum-signals-reviewed.md`

---

## Routines (5개)

### Routine 1 — `ingest` (매일 06:00 KST)

**책임**: 시장 데이터 수집 + analyzer 1차 실행

```yaml
schedule: "0 21 * * *"   # UTC 21:00 = KST 06:00
timeout: 1800s            # 30분 hard cap
on_failure:
  - alert: telegram:#ops
  - mark: status=failed
  - abort_downstream: true

steps:
  - name: fetch_market_data
    run: |
      cd ~/dev/<project-quant>
      python -m quant.ingest \
        --date $(date +%Y-%m-%d) \
        --out ~/Documents/SecondBrain/09-Quant-Reports/$(date +%Y-%m-%d)/raw.parquet

  - name: run_analyzer
    run: |
      cd ~/dev/<project-quant>
      python -m quant.analyzer \
        --in  ~/Documents/SecondBrain/09-Quant-Reports/$(date +%Y-%m-%d)/raw.parquet \
        --out ~/Documents/SecondBrain/09-Quant-Reports/$(date +%Y-%m-%d)/report-draft.md

  - name: emit_metadata
    run: |
      cat > ~/Documents/SecondBrain/09-Quant-Reports/$(date +%Y-%m-%d)/meta.json <<EOF
      {
        "cycle_date": "$(date +%Y-%m-%d)",
        "status": "draft",
        "ingest_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
        "data_rows": $(wc -l < raw.parquet || echo 0)
      }
      EOF
```

**산출**: `09-Quant-Reports/2026-05-27/{raw.parquet, report-draft.md, meta.json}`

---

### Routine 2 — `review` (매일 06:30 KST, ingest 의존)

**책임**: reviewer agent (Claude Code)가 draft 평가 + signals 추출 + actions.json 생성

```yaml
schedule: "30 21 * * *"
depends_on: [ingest]
on_depends_failed: abort
timeout: 1200s

steps:
  - name: dispatch_reviewer
    run: |
      DATE=$(date +%Y-%m-%d)
      DIR=~/Documents/SecondBrain/09-Quant-Reports/$DATE

      # Claude Code 세션 띄워서 reviewer 작업 위임
      # (또는 hermes chat -p '...' 로 직접 호출)
      claude --workdir ~/dev/<project-quant> \
             --skill quant-reviewer \
             --prompt "Review $DIR/report-draft.md. Extract actionable signals (confidence >= 0.5).
                       Output JSON: [{signal_id, hypothesis, confidence, suggested_action, reasoning, risk}, ...]
                       Save to $DIR/actions.json.
                       Then write a 200-word executive summary to $DIR/report-reviewed.md
                       referencing the actions.json items by signal_id." \
             --max-tokens 30000

  - name: validate_actions_json
    run: |
      DATE=$(date +%Y-%m-%d)
      DIR=~/Documents/SecondBrain/09-Quant-Reports/$DATE
      jq -e 'type == "array" and length >= 0' $DIR/actions.json >/dev/null \
        || { echo "actions.json invalid"; exit 1; }

  - name: update_status
    run: |
      DATE=$(date +%Y-%m-%d)
      DIR=~/Documents/SecondBrain/09-Quant-Reports/$DATE
      jq '.status = "reviewed" | .review_at = "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"' \
        $DIR/meta.json > $DIR/meta.json.tmp && mv $DIR/meta.json.tmp $DIR/meta.json
```

**Reviewer skill (`~/.claude/skills/quant-reviewer/SKILL.md`)** — 별도 정의:

- 신호 강도 평가 기준 (confidence 0-1 스케일 정의)
- 알려진 false positive 패턴 (Hermes Memory에서 학습됨)
- 위험 라벨 (low/med/high) 분류 룰

---

### Routine 3 — `approval` (매일 07:00 KST, review 의존)

**책임**: actions.json의 confidence >= 0.7 항목 → 폰 Board approval

```yaml
schedule: "0 22 * * *"
depends_on: [review]
on_depends_failed: abort
timeout: 600s

# 자율 행동 X — 사람 승인 게이트
human_in_the_loop: true

steps:
  - name: filter_high_confidence
    run: |
      DATE=$(date +%Y-%m-%d)
      DIR=~/Documents/SecondBrain/09-Quant-Reports/$DATE
      jq '[.[] | select(.confidence >= 0.7)]' $DIR/actions.json > $DIR/actions-pending.json

  - name: dispatch_to_board
    run: |
      DATE=$(date +%Y-%m-%d)
      DIR=~/Documents/SecondBrain/09-Quant-Reports/$DATE
      COUNT=$(jq 'length' $DIR/actions-pending.json)

      if [[ "$COUNT" -eq 0 ]]; then
        # 승인 요청할 게 없음 → 사이클 done으로
        jq '.status = "done"' $DIR/meta.json > $DIR/meta.json.tmp && mv $DIR/meta.json.tmp $DIR/meta.json
        exit 0
      fi

      # Paperclip Board API 호출
      curl -fsS -X POST http://localhost:3100/api/board/approvals \
        -H "Content-Type: application/json" \
        -d @- <<EOF
      {
        "cycle_date": "$DATE",
        "company": "quant-research-action-loop",
        "title": "$COUNT actions to approve (confidence >= 0.7)",
        "actions_file": "$DIR/actions-pending.json",
        "summary_file": "$DIR/report-reviewed.md",
        "telegram_topic": "#ops",
        "timeout_hours": 8
      }
      EOF
```

**8시간 timeout**: 폰에 알람 갔는데 8시간 안에 응답 없으면 자동 abort (장 마감 후 의미 없음).

---

### Routine 4 — `execute` (Board 승인 webhook 트리거)

**책임**: 승인된 액션 실제 실행 (포지션 진입 / 외부 알림 / 보고서 게시 등)

```yaml
trigger: webhook
trigger_endpoint: /webhook/board-approved
timeout: 1800s

# Routine 4가 받는 payload:
#   { cycle_date, approved_signal_ids: [...], rejected_signal_ids: [...] }

steps:
  - name: validate_payload
    run: |
      # 승인된 signal_id만 actions.json에서 추출
      DATE="${PAPERCLIP_PAYLOAD_cycle_date}"
      DIR=~/Documents/SecondBrain/09-Quant-Reports/$DATE
      jq --argjson approved "${PAPERCLIP_PAYLOAD_approved_signal_ids}" \
         '[.[] | select(.signal_id as $id | $approved | index($id))]' \
         $DIR/actions.json > $DIR/actions-approved.json

  - name: dispatch_executor
    run: |
      DATE="${PAPERCLIP_PAYLOAD_cycle_date}"
      DIR=~/Documents/SecondBrain/09-Quant-Reports/$DATE

      # 각 action 타입별 분기 (executor agent 또는 직접)
      jq -c '.[]' $DIR/actions-approved.json | while read action; do
        TYPE=$(echo "$action" | jq -r '.suggested_action.type')
        case "$TYPE" in
          telegram_post)
            curl -fsS -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
              -d "chat_id=${BROADCAST_CHAT_ID}" \
              -d "text=$(echo "$action" | jq -r '.suggested_action.content' | jq -sRr @uri)"
            ;;
          db_write)
            python -m quant.executors.db_write "$action"
            ;;
          # ❌ 자금 이동/거래 액션은 본 예시에 의도적으로 미포함
          #    실제 사용 시 별도 가드 (size limit, kill switch, dry-run mode) 필수
          *)
            echo "Unknown action type: $TYPE" >&2
            ;;
        esac
        # 실행 결과 audit log
        echo "{\"signal_id\": $(echo "$action" | jq '.signal_id'), \"executed_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" \
          >> $DIR/executed.jsonl
      done

  - name: mark_done
    run: |
      DATE="${PAPERCLIP_PAYLOAD_cycle_date}"
      DIR=~/Documents/SecondBrain/09-Quant-Reports/$DATE
      jq '.status = "done" | .executed_at = "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"' \
        $DIR/meta.json > $DIR/meta.json.tmp && mv $DIR/meta.json.tmp $DIR/meta.json
```

---

### Routine 5 — `rollup` (매일 21:00 KST)

**책임**: 오늘 사이클 요약 → vault 일일 노트 + Hermes Memory feedback

```yaml
schedule: "0 12 * * *"   # UTC 12:00 = KST 21:00
timeout: 600s

steps:
  - name: generate_summary
    run: |
      DATE=$(date +%Y-%m-%d)
      DIR=~/Documents/SecondBrain/09-Quant-Reports/$DATE
      STATUS=$(jq -r '.status' $DIR/meta.json 2>/dev/null || echo "missing")
      EXECUTED=$(jq -r '.executed_at // "n/a"' $DIR/meta.json)
      ACTION_COUNT=$(jq 'length' $DIR/actions.json 2>/dev/null || echo 0)
      APPROVED_COUNT=$(jq 'length' $DIR/actions-approved.json 2>/dev/null || echo 0)

      cat > ~/Documents/SecondBrain/03-Daily-Reports/$DATE-quant-cycle.md <<EOF
      # Quant Cycle $DATE

      - **Status**: $STATUS
      - **Signals**: $ACTION_COUNT raw → $APPROVED_COUNT approved
      - **Executed at**: $EXECUTED
      - **Drilldown**: [[09-Quant-Reports/$DATE/report-reviewed]]
      - **Actions executed**: [[09-Quant-Reports/$DATE/executed.jsonl]]

      ## Lessons
      (다음 사이클 reviewer가 컨텍스트로 사용)
      EOF

  - name: feedback_to_hermes
    run: |
      DATE=$(date +%Y-%m-%d)
      DIR=~/Documents/SecondBrain/09-Quant-Reports/$DATE

      # 사이클 회고 한 줄 생성 (Claude Code가 작성)
      claude --skill hermes-memory-feedback \
             --prompt "오늘($DATE) quant 사이클을 한 줄(50자 이내)로 요약. 
                       다음 사이클 reviewer가 negative example로 쓸 만한 패턴이 있으면 그것 위주.
                       Output to ~/Documents/SecondBrain/03-Daily-Reports/$DATE-feedback.txt" \
             --max-tokens 200

      # Hermes Memory에 한 줄 추가 (Hermes가 다음 세션부터 컨텍스트로 흘림)
      LINE=$(cat ~/Documents/SecondBrain/03-Daily-Reports/$DATE-feedback.txt)
      hermes memory add "[quant-loop $DATE] $LINE" || true
```

---

## 실패 모드 + 복구

| 증상 | 원인 후보 | 자동 복구 | 사람 개입 필요? |
|------|----------|-----------|-----------------|
| ingest timeout | 데이터 소스 다운 | 다음 사이클 자동 재시도 | 24h 연속 실패 시 |
| review 출력 invalid JSON | reviewer skill 결함 | abort + 알람 | yes (skill 수정) |
| approval 8h timeout | 사용자 부재 | 자동 aborted, 사이클 종료 | optional (회고) |
| execute partial failure | 일부 액션 실패 | executed.jsonl에 success/fail 모두 기록 → rollup이 분석 | 실패 패턴 반복 시 |
| Hermes Memory 80% 도달 | consolidate 안 됨 | `hermes consolidate --force` 호출 | rare |

---

## 보안 게이트 체크리스트

이 회사가 **자율적으로** 다음 액션을 절대 못 함 (Board approval 필수):

- ❌ 자금 이동 / 거래 / 포지션 진입 (위 예시엔 의도적 미포함)
- ❌ 외부 채널 publish (X, public Telegram channel)
- ❌ 사용자 vault `01-Tax/`, `02-Wallets/`, `03-Personal/` 읽기/쓰기
- ❌ 새로운 MCP 서버 추가
- ❌ Hermes SOUL.md / USER.md 수정 (MEMORY.md는 한 줄 추가만 허용)

자율 허용:

- ✅ market data ingest (read-only)
- ✅ analyzer 실행
- ✅ `09-Quant-Reports/` 에 파일 쓰기
- ✅ Hermes Memory에 한 줄 추가
- ✅ Telegram #ops 토픽에 알람 push

---

## 첫 운영 1주일

1. **Day 1-3**: routine 1 (ingest)만 활성화. 사람이 매일 결과 확인. analyzer 출력이 노이즈인지 신호인지 평가
2. **Day 4-5**: routine 2 (review) 추가. reviewer skill 튜닝 (false positive 패턴 학습)
3. **Day 6**: routine 3 (approval) 추가. confidence threshold 조정 (0.7 → 너의 risk appetite에 맞게)
4. **Day 7**: routine 4 (execute) — 비파괴적 액션 (telegram post, db write) 부터. 자금 이동은 한 달 운영 후
5. **매 사이클**: rollup이 Hermes Memory에 feedback → 다음 사이클부터 reviewer 정확도 증가

**Tier 1 권장**: 이 회사 + Research Lab + Content Studio. 3개 모두 같은 패턴이라 한 번 익히면 추가 회사 쉬움.
