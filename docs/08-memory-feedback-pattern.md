# Memory Feedback Pattern

> Paperclip routine + omo specialist + Claude Code 작업이 **자기 개선**되도록 만드는 패턴.
> 매 사이클 끝에 한 줄 회고를 Hermes Memory에 추가 → 다음 세션부터 Soul/Memory/User 컨텍스트로 자동 흘러들어감.

## 왜 이 패턴?

"agent가 쉬지 않고 일하는 시스템"의 진짜 가치는 단순 자동화가 아님. **시간이 갈수록 정확도가 올라가야** 함. 그러려면 매 사이클 결과가 다음 사이클의 입력에 영향을 줘야 함.

Hermes의 5 pillar 중 **Memory + Skills**가 이걸 위한 layer. 그러나 자동으로 채워지진 않음. 패턴이 필요:

1. 매 routine rollup 단계에서 "오늘 잘했나/못했나" 한 줄 회고 작성
2. `hermes-feedback.sh`가 그 한 줄을 `MEMORY.md`의 Feedback Loop 섹션에 append
3. 다음 세션부터 Hermes가 frozen snapshot으로 주입 → reviewer/router/specialist가 컨텍스트로 가짐
4. 누적된 회고가 80% 도달하면 Hermes auto-consolidate가 요약/압축

## 한 줄 회고 형식

```
[<topic> <YYYY-MM-DD>] <50-200자 회고>
```

좋은 예:

- `[quant-loop 2026-05-27] momentum 시그널 3개 중 2개 정확, BTC funding rate 편향 1건 false. funding 임계치 조정 후보.`
- `[content-studio 2026-05-27] 22:00 routine timeout — vault 노트 35개 읽기 너무 길었음. context 사전 필터링 필요.`
- `[router 2026-05-27] "ulw" 키워드인데 #scratch 토픽이라 confirm 띄움 — UX 마찰. scratch 토픽은 confirm 면제 검토.`

나쁜 예:

- ❌ `잘됨` (정보 0)
- ❌ `analyzer 실행, 시그널 발견, telegram 전송` (단순 액션 로그 — feedback X)
- ❌ `사용자가 좋아할 듯` (사이코펜시)

## 어디서 누가 호출하나

### Paperclip routine rollup 단계 (자동)

각 회사의 마지막 routine (`rollup`)이 호출:

```yaml
# 예: quant-research-action-loop/Routine 5
steps:
  - name: feedback_to_hermes
    run: |
      DATE=$(date +%Y-%m-%d)
      # LLM이 한 줄 회고 생성 → 파일로
      claude --skill memory-feedback-writer \
             --prompt "..." \
             --output "$HOME/Documents/Obsidian Vault/03-Daily-Reports/$DATE-feedback.txt"

      # hermes-feedback.sh로 Memory에 commit
      ./scripts/hermes-feedback.sh quant-loop --from-file "$HOME/Documents/Obsidian Vault/03-Daily-Reports/$DATE-feedback.txt"
```

### Claude Code 세션 종료 시 (선택)

긴 코딩 세션(`ulw` 또는 hyperplan) 끝에 사용자가 직접:

```bash
./scripts/hermes-feedback.sh <project-d> "EIP-7702 호환 검증 17분. Oracle 감사가 가장 오래 걸림. 다음엔 librarian이 spec 먼저 캐싱."
```

또는 라우터에 별도 키워드 (예: `회고`, `learn from this`)로 자동 dispatch.

### 사용자 명시 트리거 (Telegram)

```
폰: "회고 quant 오늘 momentum 2/3 적중, funding 편향 1건"
→ router Rule X → hermes-feedback.sh quant-loop "momentum 2/3..."
```

## 누적 메모리 관리

`MEMORY.md` 2,200자 한도. 위 패턴으로 매일 ~5개 회고 add되면 약 2-3주 안에 80% 도달.

**Auto-consolidate trigger**:

- `hermes-feedback.sh` 가 매 호출 시 size 체크 → 80% 넘으면 `hermes consolidate --force` 자동 호출
- consolidate는 오래된 회고를 그룹핑/요약 → 새 회고 공간 확보

**Consolidate가 안 만지는 것**:

- Memory 본문 (Environment / Conventions / Tool Quirks 등) — 사용자가 직접 관리
- Anti-Patterns 섹션 — 누적된 교훈, 보존 우선

**Feedback Loop만 consolidate 대상**.

## Skills와의 연동

Hermes의 4번째 pillar (Skills)는 사용 패턴이 3회 반복 감지되면 자동으로 SKILL.md 생성. Feedback Loop가 입력으로 들어가면:

- 같은 negative pattern 반복 감지 → 자동 anti-skill (예: "BTC funding rate 0.1% 이하면 무시")
- 같은 positive pattern 반복 감지 → 자동 promotion 후보 (예: "vault 노트 먼저 search 후 작업하는 패턴이 효율 +30%")

→ `~/.hermes/skills/` 디렉토리에 새 스킬 후보 출현. 사용자가 weekly review에서 promote/discard 결정.

## 데이터 흐름 (한 사이클)

```
1. Paperclip routine 실행 → 산출물 (보고서, 트레이드, 콘텐츠 등)
2. routine rollup → 한 줄 회고 작성 (LLM 또는 룰 기반)
3. hermes-feedback.sh → MEMORY.md Feedback Loop 섹션에 append
4. (size 80% 시) hermes consolidate --force → 요약 압축
5. (다음 세션) Hermes가 frozen snapshot으로 컨텍스트 주입
6. router/reviewer/specialist가 이 컨텍스트로 판단
7. 6-시간 cron heartbeat → Hermes Skills 자동 검토 → 새 스킬 후보 출현
8. 사용자 weekly review → skill promote/discard
```

순환 X — 누적적 (각 사이클이 다음 사이클을 더 똑똑하게).

## 안티-패턴

- ❌ **모든 routine 결과를 통째로 memory에**: 노이즈. 한 줄 회고만.
- ❌ **자동 회고가 LLM 풀자유**: 톤 drift. `memory-feedback-writer` 스킬로 형식 강제.
- ❌ **consolidate 끄기**: 메모리 가득 차면 새 정보 못 받음. auto-consolidate 강제.
- ❌ **사용자에게 매번 회고 묻기**: 마찰. routine rollup이 자동으로 + 사용자는 weekly review에서 검토.
- ❌ **여러 topic 한 줄에 섞기**: `[a,b,c]` 같이. 각 topic별 독립 한 줄.

## 검증

매주 일요일 (또는 매 6시간 cron heartbeat 직후) 다음 확인:

```bash
# MEMORY.md 크기 추세
wc -c ~/.hermes/MEMORY.md

# Feedback Loop 섹션 line count
sed -n '/^## Feedback Loop/,/^## /p' ~/.hermes/MEMORY.md | grep -c "^- \["

# 새 skill 후보
ls -lt ~/.hermes/skills/ | head -5

# 오래된 회고가 consolidate 됐는가
grep -c "^### Consolidated" ~/.hermes/MEMORY.md
```

이 4개가 모두 변화하고 있으면 feedback loop가 살아있음. 1주일째 정지면 어느 routine이 rollup을 안 호출하는지 점검.

## 관련 자료

- 패턴 구현: [`scripts/hermes-feedback.sh`](../scripts/hermes-feedback.sh)
- 적용 예시: [`examples/paperclip-companies/quant-research-action-loop.example.md`](../examples/paperclip-companies/quant-research-action-loop.example.md) Routine 5
- Hermes 5 pillar 본문: [`playbook/PLAYBOOK.md`](../playbook/PLAYBOOK.md) Phase 3
- Memory consolidate 메커니즘: [`docs/02-architecture.md`](02-architecture.md) §Hermes 5 Pillar
