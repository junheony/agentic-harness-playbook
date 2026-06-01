# Architecture

## 7-레이어 스택

```
┌──────────────────────────────────────────────────────────────────────┐
│ L4  진입점                                                            │
│     • iPhone Telegram (Forum Topics: #ops/#dev/#research/...)        │
│     • SSH via Termius (Tailscale 진입)                                │
│     • 음성 (Telegram voice note → STT)                                │
├──────────────────────────────────────────────────────────────────────┤
│ L3  학습 / 메모리 / 메시징                                            │
│     Hermes 5 Pillar Core                                              │
│     ├─ Soul     : 페르소나 고정 (~/.hermes/SOUL.md)                   │
│     ├─ Memory   : 환경/교훈 (~/.hermes/MEMORY.md, 2,200자)            │
│     ├─ User     : 사용자 프로필 (~/.hermes/USER.md, 1,375자)          │
│     ├─ Skills   : 자동 생성/개선 (~/.hermes/skills/<name>/)           │
│     └─ Crons    : 6시간 heartbeat (review/consolidate)                │
│     + Gateway (20+ 채널: Telegram/Discord/Slack/...)                  │
│     + FTS5 cross-session recall                                       │
│     + Honcho dialectic user modeling                                  │
├──────────────────────────────────────────────────────────────────────┤
│ L3' 지식베이스                                                        │
│     Obsidian Vault (~/Documents/Obsidian Vault/)                      │
│     + obsidian-claude-code 플러그인 (WebSocket + HTTP/SSE)            │
│     + Daydream skill (cross-note connection mining)                   │
│     + 3-way 분리: Public / Private / Work                             │
├──────────────────────────────────────────────────────────────────────┤
│ L3" 장기 자율운영                                                     │
│     Paperclip Companies (localhost:3100 + MCP)                        │
│     + cron-trigger routines                                           │
│     + Board approval workflow                                         │
│     + Audit log (append-only)                                         │
├──────────────────────────────────────────────────────────────────────┤
│ L2  오케스트레이션                                                    │
│     • Claude Code native subagents (~/.claude/agents/)                │
│       - code-reviewer, test-automator, docs-architect,                │
│         architect-reviewer, debugger, error-detective                 │
│     • opencode omo (oh-my-openagent) — Sisyphus/Hephaestus/Oracle/... │
├──────────────────────────────────────────────────────────────────────┤
│ L1  하네스                                                            │
│     • Claude Code (Anthropic OAuth) ← 본진                            │
│     • opencode (OpenAI Codex OAuth) ← 확장                            │
├──────────────────────────────────────────────────────────────────────┤
│ L0  메서돌로지 / 도메인 스킬                                          │
│     • Superpowers (Jesse Vincent) — brainstorm/TDD/worktrees/...      │
│     • playbook-override — 6-7 step + 신뢰도 태깅 + ToT            │
│     • Domain: xlsx, postgres, ghidra, ios-RE, korean-crypto-tax       │
└──────────────────────────────────────────────────────────────────────┘
```

## Hermes 5 Pillar 깊이

### Pillar 1: Soul (`~/.hermes/SOUL.md`)

**목적**: 톤 드리프트 방지. 시간이 지나도 동일한 페르소나 유지.

**무엇 적나**:

- 정체성 (이름, 역할, 사용자와의 관계)
- 핵심 가치 (정확성 > 친절함 등)
- 의사소통 스타일 (응답 구조, 언어, 길이)
- 행동 경계 (금지 행동, 항상 수행 행동)
- 자기반성 트리거

**중요**: 세션 시작 시 system prompt에 frozen으로 주입. 세션 중에 거의 안 바뀜.

### Pillar 2: Memory (`~/.hermes/MEMORY.md`, 2,200자 한도)

**목적**: 환경/프로젝트 컨벤션/도구 quirks/교훈을 영구 기록.

**무엇 적나**:

- 디렉토리 구조
- 프로젝트 경로 매핑
- 코딩 컨벤션 (TDD 정책, 응답 구조 등)
- 도구별 주의사항
- 워크플로 패턴 (daily/weekly)
- 도메인 지식 (간단하게)
- Lessons learned
- Anti-patterns

**동작**:

- 세션 시작 시 frozen snapshot으로 주입
- 세션 중 새 사실 발견 시 디스크에 즉시 기록 (다음 세션부터 반영)
- 80% 도달 시 Hermes가 자동 consolidate (요약/압축)

### Pillar 3: User (`~/.hermes/USER.md`, 1,375자 한도)

**목적**: 사용자가 누구인지의 표면 정보.

**무엇 적나**:

- 이름/직업/언어/위치/타임존
- 의사소통 선호 (톤, 길이, 구조)
- 기술 프로필 (주력 언어, 도구)
- 도메인 전문성
- Things to Avoid (사이코펜시, 가격 예측 등)
- Active Projects (한 줄 요약만)

**동작**: Memory와 동일하지만 Honcho dialectic user modeling으로 더 정교한 갱신.

### Pillar 4: Skills (`~/.hermes/skills/<name>/SKILL.md`)

**목적**: 사용 중 자동 생성/개선되는 작업 패턴.

**자동 생성 트리거**:

1. 같은/유사 작업 3회 이상 반복 감지
2. 사용자 명시적 트리거 (`hermes skill remember "..."`)
3. Cron heartbeat 중 활동 분석

**자동 개선 동작**:

- 사용자가 결과 거부 → 다음 heartbeat에서 negative example로 추가
- 사용자가 명시적 칭찬 → positive example로 추가
- 스킬 사용 빈도 추적 → 적게 쓰이는 스킬은 삭제 후보

**Standard**: agentskills.io (공개 Skills Hub 호환). 좋은 스킬은 community에 공유 가능.

### Pillar 5: Crons (`~/.hermes/crons.yaml`)

**목적**: 6시간마다 heartbeat 트리거 → 자기개선 loop 가동.

**기본 태스크**:

- `skill_review`: 자동 생성된 스킬 검토 (유지/개선/삭제)
- `memory_consolidate`: MEMORY.md 80% 도달 시 압축
- `output_cleanup`: 임시 파일/오래된 로그 정리
- `status_file_write`: 시스템 상태 스냅샷

**커스텀 추가 가능**: 일일 백업, 외부 API 폴링 등.

## 컴포넌트 간 상호작용

### 데이터 흐름 (텍스트 명령)

```text
1. iPhone Telegram #<project-d> 토픽 → 메시지 "ulw 가스 최적화"
2. Telegram Bot API → Hermes Gateway (allowed_users/chats 검증)
3. Hermes Router SKILL.md 평가:
   - Rule 5 (#<project-d> 토픽) → workdir=~/dev/<project-d>
   - Rule 2 (ulw 키워드) → target=opencode-omo
4. Hermes Memory/Soul/User 컨텍스트 첨부
5. tmux session "oc-<project-d>" 생성 (없으면)
6. opencode 부팅 + ulw prefix prepend
7. opencode → Sisyphus 활성화 → 멀티 specialist 디스패치
8. Hephaestus (구현) + Oracle (감사) + Librarian (spec 참조) 병렬
9. 결과 → tmux output → Hermes가 모니터링
10. Hermes → Telegram #<project-d> 토픽에 결과 push
11. (옵션) Hermes Skills: 이 패턴 학습 → 다음번 더 빠르게
```

### 데이터 흐름 (보이스 명령)

```
1. iPhone Telegram #<project-a> 토픽 → 보이스 노트
2. Hermes Gateway → faster-whisper STT (도메인 lexicon 보정)
3. confidence < 0.7 → 텍스트로 재확인 요청
4. confidence >= 0.7 → 라우터 평가 (텍스트 명령과 동일)
5. 답변은 음성 또는 텍스트 (voice_response: true면 음성)
```

### Hermes ↔ Claude Code 통신

```
Claude Code 세션:
  └─ mcp__hermes__conversations_list / messages_send (MCP 도구)

Hermes:
  └─ tmux send-keys "cc-<topic>" "<prompt>" (Claude Code 세션 조작)

양방향:
  - Claude Code 결과 → Hermes Memory에 자동 기록 (configurable)
  - Hermes 자동 스킬 발견 시 → Claude Code의 ~/.claude/skills로 promote 가능
```

### Hermes ↔ Paperclip 차이

| | Hermes | Paperclip |
|--|--------|-----------|
| 자기학습 | ✅ 5 pillar + skill auto-create | ❌ (audit log만) |
| 시간축 | 사용자 모델 (다년) | 비즈니스 워크플로 (cron) |
| 트리거 | 사용자 메시지 / cron heartbeat | cron / webhook / API |
| 학습 단위 | 사용자에 대해 | 회사별 routine 효율 |
| 외부 액션 | 사용자 위임 받음 | Board approval 필수 |

**같이 쓰는 이유**: Hermes는 "너에 대해 학습", Paperclip은 "비즈니스 자동화". 다른 레이어.

## 보안 모델

### 시크릿 저장 우선순위

**macOS**:

1. **macOS Keychain** (`security add-generic-password`) — 최우선
2. **`.pgpass` 또는 `~/.ssh/config`** — 표준 방식
3. **`.env` (chmod 600)** — Keychain 못 쓸 때만

**Linux**:

1. **`secret-tool`** (GNOME libsecret / `libsecret-tools` 패키지) — 최우선  
   `secret-tool store --label='hermes' service hermes account telegram-bot-token`
2. **`pass`** (gpg 기반 패스워드 스토어) — libsecret 없을 때  
   `pass insert hermes/telegram-bot-token`
3. **`age`** 암호화 파일 또는 **`.env` (chmod 600)** — 최후 fallback

### Plaintext 절대 금지

- ❌ git에 커밋 (`.gitignore`로 방어)
- ❌ 환경변수에 `EXPORT POSTGRES_URL=postgresql://user:pass@...` (history/ps 노출)
- ❌ 로그에 echo
- ❌ Telegram 토픽에 텍스트로 전송

### Vault 분리

- `Obsidian Vault/` (메인) — AI access OK
- `Obsidian Vault-Private/` (세무/지갑/개인) — AI access 절대 금지
- `Obsidian Vault-Work/` (NDA 자산) — AI access 절대 금지

`privacy.exclude_paths` (Hermes config)로 강제.

### 코드 실행 격리

- 알 수 없는 출처 바이너리 → Docker 격리 (`--network=none --read-only`)
- RE 분석 산출물 → vault `05-RE-Reports/` 별도 폴더
- 자동 deploy/transfer → Paperclip Board approval ALWAYS 필수

## 확장성

### 추가하기 쉬운 것

- 새 도메인 스킬 (`~/.claude/skills/<domain>/`)
- 새 Telegram 토픽 (`topic_map.yaml`에 매핑 추가)
- 새 Paperclip 회사 (의사결정 트리 참고)
- 새 MCP 서버 (Hermes / Claude Code 양쪽 등록)

### 추가하기 어려운 것

- 새 채널 (Telegram 외) — Hermes는 지원하지만 보이스/토픽 UX 재설계 필요
- 새 모델 provider — opencode 측은 쉽지만 Hermes는 일부 기능 (auto-skill creation) provider 의존
- 멀티 머신 동기화 — v3 후보

## 다음에 읽을 것

- 단계별 셋업: [`03-execution-phase1-7.md`](03-execution-phase1-7.md)
- 6-에이전트 검증: [`05-verification-report.md`](05-verification-report.md)
- 본 가이드: [`../playbook/PLAYBOOK.md`](../playbook/PLAYBOOK.md)
