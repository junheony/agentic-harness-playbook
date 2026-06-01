# FAQ

## 일반

### Q: 이게 Cursor / Windsurf / Devin이랑 뭐가 달라요?

A: 다른 카테고리. 저것들은 IDE/Agent SaaS. 이건 reference architecture — 본인이 직접 셋업하고 통제. 장점은:

- 데이터 self-hosted (모든 vault/메모리가 본인 머신)
- OAuth 비용만 (구독료 외 추가 SaaS X)
- 폰 진입점 (위 도구들은 폰 UX 약함)
- Hermes의 5 pillar 자기학습 (다른 도구엔 없음)
- 일관된 라우팅 (어느 도구를 쓸지 결정 자동화)

단점:

- 셋업 4시간 (vs 5분)
- 본인이 운영 책임 (시크릿, 백업, 헬스체크)
- IDE 통합 약함 (Claude Code/opencode은 TUI 중심)

### Q: 왜 Hermes 위에 또 Paperclip을?

A: 다른 시간축 + 다른 추상화.

- **Hermes**: 너에 대한 학습 (사용자 모델). 매 대화에서 너를 더 잘 알게 됨.
- **Paperclip**: 비즈니스 워크플로 자동화 (회사). cron으로 일/주/월 단위 외부 작업 수행.

같이 쓰는 이유: 너가 잠자는 동안에도 Paperclip 회사들이 일하고, 결과는 Hermes를 통해 너에게 전달. 둘 다 영구지만 다루는 게 다름.

### Q: 토큰 비용 얼마?

A: 사용자 패턴에 따라 다름.

기본 (Claude Pro $20 + ChatGPT Plus $20):

- 가벼운 사용 (일일 ~30분): 구독 한도 내 충분
- 중간 사용 (일일 ~2시간): 한도 거의 채움
- 풀스로틀 (`ulw` 자주): 한도 초과 → upgrade 필요

권장:

- ChatGPT Pro ($200/월) — Codex 풀스로틀
- Claude Pro ($20) 또는 Max ($100~) — 사용량에 따라
- Paperclip 회사 routine: $50-300/월 (회사 수 + 빈도에 따라)

총 예상: 월 $250 ~ $600 (풀스로틀 사용자)

### Q: 윈도우에서도 되나요?

A: 부분 지원 (WSL2). 다음은 macOS 종속:

- launchd → systemd (Linux) 또는 Task Scheduler (Windows)
- macOS Keychain → secret-tool (Linux) 또는 Windows Credential Manager
- pmset → 다른 sleep 정책 도구

핵심 컴포넌트 (Hermes/Claude Code/opencode)는 cross-platform. 단 가이드는 macOS 기준.

### Q: 클라우드 VM에 깔 수도 있나요?

A: Yes. Hermes 공식 backend 6개 중 5개가 클라우드:

- Daytona / Modal (serverless persistence — idle 시 비용 거의 0)
- SSH / Docker / Singularity (전통적 VM)

Mac Mini 대신 $10-30/월 VPS로 대체 가능. 단:

- 보이스 STT 추가 비용 가능 (faster-whisper 호스팅)
- Tailscale은 동일하게 사용

---

## 보안

### Q: 모든 시크릿이 한 머신에 있는 게 안 위험한가?

A: 위험. 안전망 강화:

1. macOS Keychain (시크릿 분산 저장)
2. `chmod 600` 모든 자격증명 파일
3. FileVault 활성화 (디스크 암호화)
4. Tailscale로만 SSH 진입 (포트 22 열지 말 것)
5. 주간 백업 → 다른 머신 (백업도 암호화)
6. 토큰 회전 정책 (90일마다)
7. Codex/Anthropic OAuth는 device-auth로 발급 (revoke 가능)

가장 큰 리스크: Mac Mini 분실 / 도난. FileVault가 마지막 방어선.

### Q: Telegram 봇이 해킹당하면?

A: 즉시 행동:

1. BotFather에서 토큰 회수 (`/revoke`)
2. 모든 LaunchAgents 정지
3. `~/.hermes/logs/gateway.out` 검토 → 의심 명령 있나
4. 의심 시 Mac Mini 격리 (Tailscale exit nodes 차단)
5. 새 봇 생성 → allowed_users + allowed_chats 다시 화이트리스트

봇 토큰 leak 가능성:

- git에 실수 커밋 (`.gitignore` 방어)
- 클립보드 → 외부 도구 leak
- 백업이 암호화 안 됨

방어: `.env` 파일 git에 절대 X, 백업 암호화 필수.

### Q: AI가 내 vault에서 민감 정보를 외부로 유출할 수 있나?

A: 이론적으로 가능. 방어:

1. **Vault 3분리** (메인 / Private / Work)
2. **`privacy.exclude_paths`** Hermes config
3. **Telegram 토픽 분리** (`#tax`/`#wallets`는 별도 토픽 → 명시적 사용자 진입 시에만 컨텍스트 로드)
4. **외부 액션은 Board approval** (Paperclip)
5. **주기적 audit**: vault에 grep으로 민감 패턴 검색

---

## OAuth / 정책

### Q: Anthropic OAuth를 opencode에 꽂는 우회 있다던데?

A: 있음. **절대 권장 안 함.** 이유:

1. 2026-04 Anthropic ToS 명시 위반 (3rd-party 클라이언트 차단)
2. 실제 정지 사례 다수 — 한 번 정지되면 복구 어려움
3. 구독 (Pro $20 ~ Max $100) 매몰비용 큼
4. 단기 편의 vs 장기 안정성 trade — 명확히 후자가 가치 큼

대안: opencode + Codex OAuth는 100% 공식 지원. 둘 다 쓰면 됨.

### Q: Codex OAuth 정책 바뀌면?

A: API 키 폴백 경로가 모든 컴포넌트에 명시되어 있음:

```bash
# opencode
export OPENAI_API_KEY="sk-..."

# Hermes (config.yaml)
provider: openai_api  # vs openai (OAuth)
api_key: ${OPENAI_API_KEY}
```

전환에 ~10분 걸림.

### Q: 다른 모델 provider (Anthropic API, Gemini, local) 쓰고 싶음

A: Hermes는 다음 지원:

- Nous Portal (자체)
- OpenRouter (200+ 모델)
- NovitaAI, NVIDIA NIM, z.ai/GLM, Kimi/Moonshot, MiniMax
- HuggingFace, OpenAI, custom endpoint

opencode는 multi-provider 지원이 더 좋음.
Claude Code는 Anthropic만.

---

## 학습 / 사용 패턴

### Q: Hermes가 자기개선한다는 게 진짜 체감되나?

A: 1주일 후부터 체감, 1개월 후엔 확실. 패턴:

- Day 1-3: 매번 컨텍스트 재설명 필요 (USER.md가 비어있음)
- Day 4-7: USER.md/MEMORY.md 자동 갱신 시작
- Day 8-14: 자동 스킬 1-3개 생성
- Day 15-30: 자주 쓰는 작업 패턴 학습 완료
- 1-3개월: 사용자 패턴 모델이 정교해짐 (질문 방식만 봐도 톤 추정)

다만 Hermes 끄고 새로 깔면 처음부터. 백업 필수.

### Q: 어떤 작업을 어디로 보내야 할지 모르겠다

A: 라우터가 자동 분류. 명시적으로:

- 짧은 답변 / 정보 조회 → 그냥 텍스트 (Hermes self)
- 코딩 (단발) → `cc>` (Claude Code) 또는 자동 라우팅
- 코딩 (큰 변경) → `ulw` (opencode + omo)
- 보안 감사 → `hpp ulw` (hyperplan)
- 리서치 → `#research` 토픽 (자동으로 Claude Code + web)
- vault 검색 → "내가 예전에 쓴 X 노트 찾아줘"

자세히: `skills/router/SKILL.md`

### Q: TDD 항상 해야 하나요?

A: 아니. `playbook-override`의 예외 명시:

- 일회성 분석 스크립트
- 시각 검증 우선 UI
- 온체인 시뮬레이션 / 백테스트
- prompt engineering 작업

위 외엔 TDD 디폴트.

---

## 비용 / 운영

### Q: Paperclip 회사 만들 때 비용 폭주 막는 방법?

A:

1. Budget hard-stop per company (`budget_monthly_usd: 200` 명시)
2. Routine timeout 강제 (`timeout: 1800` 초)
3. Audit log 매주 리뷰 → 비싸기만 한 routine 제거
4. Sanity 알람 (`telemetry.alert_thresholds`)
5. 첫 운영 1주일은 적은 빈도로 시작 → 안정 후 늘리기

### Q: 백업 어떻게?

A: `scripts/backup.sh` — 매일 다음을 git private repo로:

- `~/.claude/` (subagents, plugins, config — auth.json 등 시크릿 자동 제외)
- `~/.hermes/` (skills/config — .env 및 SOUL/USER/MEMORY 자동 제외)
- `~/.paperclip/` (회사 정의, audit log)
- SOUL/USER/MEMORY는 별도 age 또는 gpg 암호화 아카이브로

기본 안전 동작: rsync denylist (auth.json, *.token, .env, .pgpass 등) + .gitignore 매 실행 강제 갱신 + push 시 현재 브랜치 자동 감지.

### Q: 멀티 머신 (Mac Mini + MBP + Linux server) 동기화는?

A: v2.1에선 미해결. v3 후보.

현재 임시 방안:

- 시크릿: 디바이스별 독립 발급 (한 머신 leak 시 영향 분리)
- SKILL.md: git private repo로 sync (모든 머신에서 pull)
- SOUL/USER/MEMORY: 마스터 머신 (Mac Mini)에서만, 다른 머신은 read-only mount
- Paperclip 회사: 한 머신 (보통 Mac Mini)에서만 실행

---

## 기여 / 커뮤니티

### Q: 본인 셋업을 fork해서 공개해도 되나?

A: MIT 라이센스라 OK. 단 시크릿/PII 빼고. 본인 도메인 매핑 익명화 필요.

### Q: 이 레포에 PR 환영하는 것?

A: [`CONTRIBUTING.md`](../CONTRIBUTING.md) 참고. 요약:

- 다른 OS (Linux, Windows WSL) 가이드 환영
- 새 도메인 스킬 환영
- 트러블슈팅 케이스 환영
- 본인 식별자/시크릿 포함 PR은 reject

### Q: 메인테이너에게 직접 연락?

A: 일반 질문은 GitHub Issues. 보안 이슈는 직접 (이메일/Telegram).

### Q: 한국어 docs만 있는데 영어 버전?

A: v3 후보. PR 환영. 한국어 → 영어 번역은 자동 번역 X (뉘앙스 보존 안 됨).

---

## 미해결 / 알려진 한계

1. **멀티 머신 동기화** — v3 후보
2. **Windows native** — WSL2만 부분 지원
3. **Korean Crypto Tax SKILL.md** 풀 버전 미공개 (개인 자산, v3 후보)
4. **분산 tracing** — 컴포넌트 간 trace_id 추적 미구현
5. **외부 독립 검증 부재** — verification report는 self-review. 실제 사용자 셋업 케이스 누적 필요
6. **Mobile-side UI** — Telegram 의존 (자체 앱 없음)
7. **Voice 응답 품질** — TTS는 OK이지만 한국어 자연스러움 영어보다 떨어짐

발견한 새 한계는 GitHub Issues로.
