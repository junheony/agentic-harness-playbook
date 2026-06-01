# Paperclip Company: Research Lab

> Tier 1 권장. 가장 일찍 만들면 가장 빨리 ROI 나옴.

## Mission

도메인별 (예: 본인 관심 분야 3-5개) 일일 다이제스트 자동 생성 → vault에 저장 → 사용자 매일 아침 한 번 읽으면 됨.

## 의사결정 트리 평가

| Q | 답 |
|---|----|
| Q1. 매일 1회 이상 자동? | YES (매일 아침 다이제스트) |
| Q2. 멀티 역할? | YES (Scout 여러 도메인 + Synthesizer + Anti-bias Reviewer) |
| Q3. 외부 게시? | NO (내부 vault만) |
| Q4. 예측 가능? | 부분 (정해진 시간 + 적응 요소) |
| Q5. 비용? | $100/월 예상 |

→ **회사로 만들 가치 충분**

## 조직도

```
Research Lab
├─ Domain Scouts (병렬)
│  ├─ Scout A: <도메인 A>   (Claude Code + web research)
│  ├─ Scout B: <도메인 B>   (Claude Code + web research)
│  └─ Scout C: <도메인 C>   (Claude Code + web research)
│     Routine: 매일 07:00 KST 병렬 시작
│
├─ Synthesizer (Claude Code + daydream skill)
│  Trigger: 모든 Scout 완료 시
│  역할: 도메인 간 cross-link 발굴 (Karpathy 패턴)
│  출력: vault `03-Daily-Reports/YYYY-MM-DD.md`
│
└─ Anti-bias Reviewer (Claude Code, 다른 페르소나)
   Trigger: Synthesizer 완료 시
   역할: 본인 확증편향 체크, 반대 입장 제시
   출력: 같은 노트의 "반론" 섹션
```

## Routine 정의 (YAML)

```yaml
name: research_lab_daily
schedule: "0 7 * * *"   # 매일 07:00 KST
timeout: 1800           # 30분 hard limit
budget_monthly_usd: 100

agents:
  - id: scout_a
    role: domain_scout
    parallel_group: scouts
    harness: claude-code
    skills: [web-search, obsidian]
    prompt: |
      <도메인 A>의 지난 24시간 주요 이벤트를 수집해.
      신뢰도 태깅 (높음/중간/낮음/미상) 필수.
      vault `99-Inbox/scout-a-YYYY-MM-DD.md`에 임시 저장.
  
  - id: scout_b
    role: domain_scout
    parallel_group: scouts
    harness: claude-code
    skills: [web-search]
    prompt: |
      <도메인 B>의 지난 24시간 주요 이벤트를 수집해.
      (위와 동일 형식)
  
  - id: scout_c
    role: domain_scout
    parallel_group: scouts
    harness: claude-code
    skills: [web-search]
    prompt: |
      <도메인 C>의 지난 24시간 주요 이벤트를 수집해.
      (위와 동일 형식)
  
  - id: synthesizer
    role: integrator
    depends_on: [scout_a, scout_b, scout_c]
    harness: claude-code
    skills: [obsidian, daydream]
    prompt: |
      99-Inbox/scout-*-{{date}}.md 를 모두 읽고:
      1. 핵심 이벤트 5-10개로 압축
      2. 도메인 간 cross-link 발굴 (예: A의 X와 B의 Y가 연결)
      3. vault 03-Daily-Reports/{{date}}.md 에 정리
      4. 임시 파일 삭제
  
  - id: anti_bias
    role: reviewer
    depends_on: [synthesizer]
    harness: claude-code
    prompt: |
      03-Daily-Reports/{{date}}.md 를 읽고:
      1. 사용자의 확증편향 의심 부분 식별
      2. 반대 관점/대안 가설 제시
      3. 노트 끝에 "## 반론" 섹션 추가

approval:
  board_approval_required: false   # 내부만, vault에만 쓰니까

audit:
  log_path: ~/.paperclip/audit/research-lab/
  retention_days: 365
```

## 첫 운영 1주일 체크

- Day 1: routine 실행 → vault 노트 생성됐는지
- Day 3: 노트 품질 검토 → 부족하면 Scout 프롬프트 조정
- Day 7: 1주일치 다이제스트 비교 → 패턴/노이즈 파악
- Day 14: cron 비용 vs 가치 평가, 필요시 도메인 추가/제거

## 확장 아이디어

- Weekly Synthesizer (매주 일요일 1주일 요약)
- Monthly Trend Tracker (매월 1일 한 달 회고)
- Cross-domain hypothesis 자동 발굴
