# Paperclip Company: Content Studio

> Tier 1 권장. 콘텐츠 크리에이터/KOL이라면 가장 큰 시간 절감.

## Mission

일일 콘텐츠 초안 자동 작성 → 사용자 승인 → 외부 게시 (X, Telegram 채널 등).

## 의사결정 트리 평가

| Q | 답 |
|---|----|
| Q1. 매일 1회 이상 자동? | YES (일일 포스팅) |
| Q2. 멀티 역할? | YES (Researcher + Curator + Drafter + Editor) |
| Q3. 외부 게시? | YES (X, Telegram 채널) |
| Q4. 예측 가능? | 예측 가능 + 적응 (시장 이벤트 대응) |
| Q5. 비용? | $100-300/월 |

→ **회사로 만들 가치 충분 + Board approval ALWAYS 필수**

## 조직도

```
Content Studio
├─ Market Researcher (Claude Code + web search + obsidian)
│  Routine: 매일 21:00 KST (다음날 콘텐츠 준비)
│  역할: 오늘 시장/도메인 주요 이벤트 수집 → vault에 임시 저장
│
├─ Trend Curator (Claude Code + daydream)
│  Trigger: Researcher 완료 시
│  역할: vault의 과거 노트와 cross-link → 본인 시그니처 관점 발굴
│
├─ Content Drafter (Claude Code + playbook-override 톤)
│  Trigger: Curator 완료 시
│  역할: 본인 톤으로 3개 포스트 초안 (한글 + 영문 티커)
│  출력: vault `04-Content-Drafts/YYYY-MM-DD.md`
│
└─ Final Editor (사용자 본인 = Board)
   Board approval: ALL DRAFTS
   Action: 승인 시 → X API + Telegram 채널 자동 게시
```

## Routine 정의 (YAML)

```yaml
name: content_studio_daily
schedule: "0 21 * * *"   # 매일 21:00 KST
timeout: 2400            # 40분
budget_monthly_usd: 200

agents:
  - id: researcher
    role: market_researcher
    harness: claude-code
    skills: [web-search, obsidian]
    prompt: |
      오늘의 <도메인> 주요 이벤트 수집:
      1. 가격 움직임 (단, 가격 예측 단정 금지)
      2. 주요 발표/뉴스
      3. 커뮤니티 화제
      신뢰도 태깅 필수.
      vault 99-Inbox/research-{{date}}.md
  
  - id: curator
    role: trend_curator
    depends_on: [researcher]
    harness: claude-code
    skills: [obsidian, daydream]
    prompt: |
      research-{{date}}.md + 지난 30일 본인 노트 cross-reference.
      본인 시그니처 관점 (예: "1년 전 비슷한 패턴이 있었다") 발굴.
      vault 99-Inbox/curated-{{date}}.md
  
  - id: drafter
    role: content_drafter
    depends_on: [curator]
    harness: claude-code
    skills: [playbook-override]
    prompt: |
      curated-{{date}}.md 기반으로 3개 포스트 초안:
      1. 짧은 트윗 (280자)
      2. 중간 스레드 (3-5 트윗)
      3. 텔레그램 채널 긴 포스트 (500자)
      
      제약:
      - 가격 예측 단정 금지
      - "절대" / "확실" / "무조건" 사용 금지
      - 본인 보유 포지션 공개 금지
      
      vault 04-Content-Drafts/{{date}}.md

approval:
  board_approval_required: true   # ALL DRAFTS
  approval_channel: "telegram:<your_user_id>"
  approval_timeout_hours: 12      # 12시간 내 승인 안 하면 게시 안 함

actions_on_approval:
  - publish_to_x:
      api_key_from: keychain:x-api-key
      account: "<your_handle>"
  - publish_to_telegram_channel:
      channel_id: "<channel_id>"

audit:
  log_path: ~/.paperclip/audit/content-studio/
  retention_days: 365
  include_drafts: true   # 거부된 초안도 보관
```

## 금지 규칙 (절대 위반 금지)

- 가격 예측 단정 X
- "절대" / "확실" / "무조건" 같은 단정어 X  
- 보유 포지션 공개 X (legal risk)
- 사용자가 직접 검토 안 한 글 자동 게시 X
- 동일 콘텐츠 24시간 내 X와 Telegram 동시 게시 X (피로감)
- 광고 의뢰 받은 토큰을 일반 콘텐츠로 위장 X (FTC/공정위 가이드라인)

## Board Approval UX

승인 시 Telegram DM:

```
[Content Studio Daily Draft]
2026-05-27 KST

Draft 1 (Tweet):
"<내용>"

Draft 2 (Thread, 4 tweets):
...

Draft 3 (Telegram long-form):
...

승인:
✅ All 3 → 모두 게시
✏️ Edit → 수정 요청 (메시지로)
❌ Reject → 폐기
```

응답 안 하면 12시간 후 자동 폐기 (안전 디폴트).

## 운영 첫 1주일 체크

- Day 1: 초안 품질 검토 → Drafter 프롬프트 조정
- Day 3: 톤/시그니처 일관성 확인
- Day 7: X 분석 (조회수, 인게이지) → 어느 포맷이 잘 먹는지
- Day 14: 광고/협찬 콘텐츠 분리 정책 명확화
- Day 30: 콘텐츠 캘린더 자동화 가능성 검토

## 안전망

- 외부 게시 액션 전 사용자 명시 승인 (`✅` 또는 명시 텍스트)
- API key는 macOS Keychain (`security` CLI)
- audit log 365일 보관
- 거부된 초안도 보관 → 패턴 학습용
- 매주 audit 리뷰 (자동 게시 사고 없었는지)
