# Docs Index — 읽는 순서 가이드

> `docs/` 폴더 17개 문서의 목적 / 대상 / 읽는 시점을 한 곳에 정리. 처음이라면 이 문서 → `01-overview.md` 순서로.

## 문서 번호 vs Phase 번호

혼동 주의 — **docs 번호와 Phase 번호는 다르다**:

- **Phase 1~17**: 셋업 진행 단계. 본문은 [`playbook/PLAYBOOK.md`](../playbook/PLAYBOOK.md)에 통합 (PLAYBOOK §2 = Phase 1, §3 = Phase 2, ... §18 = Phase 17 — 섹션 번호가 Phase 번호보다 1 크다).
- **docs/01~17**: 주제별 보조 문서. `docs/03`이 Phase 1~7 실행 가이드, `docs/04`가 Phase 8~17 링크 매핑이고, 나머지는 아키텍처/운영/트러블슈팅 등 독립 주제.

## 읽기 순서 표

| 파일 | 대상 독자 | 언제 읽나 |
|------|----------|-----------|
| [`01-overview.md`](01-overview.md) | 전원 | 맨 처음 — 전체 그림 + 시간축 스택 + 추천 진행 순서 |
| [`02-architecture.md`](02-architecture.md) | 설계가 궁금한 사람 | 셋업 전 또는 병행 — 7-레이어 스택, Hermes 5 pillar, 보안 모델 |
| [`03-execution-phase1-7.md`](03-execution-phase1-7.md) | 셋업 실행자 | Week 1 — Phase 1~7 (인프라 베이스) 복붙 진행 |
| [`04-execution-phase8-17.md`](04-execution-phase8-17.md) | 셋업 실행자 | Week 2~4 — Phase 8~17의 PLAYBOOK 섹션 매핑 |
| [`05-verification-report.md`](05-verification-report.md) | 신뢰성 검토자 | 셋업 전후 아무 때나 — 6-페르소나 self-review 결과 |
| [`06-troubleshooting.md`](06-troubleshooting.md) | 전원 | 문제가 생겼을 때 — 컴포넌트별 증상/해결 |
| [`07-faq.md`](07-faq.md) | 전원 | 궁금할 때 — 비용/보안/정책/한계 |
| [`08-memory-feedback-pattern.md`](08-memory-feedback-pattern.md) | 운영자 (Hermes) | Phase 3 이후 — 자기개선 loop 만들기 |
| [`09-agent-instrumentation.md`](09-agent-instrumentation.md) | 운영자 (대시보드) | 대시보드 쓸 때 — agent lifecycle 계측 패턴 |
| [`10-claude-oauth-proxy.md`](10-claude-oauth-proxy.md) | 고급 (off-policy) | 선택 — Claude OAuth proxy. ToS 위반 리스크 숙지 후 |
| [`11-mac-linux-sync-git.md`](11-mac-linux-sync-git.md) | 멀티 머신 사용자 | Mac + Linux 서버 병행 시 — git 중심 sync |
| [`12-agent-push-automation.md`](12-agent-push-automation.md) | 멀티 머신 사용자 | docs/11 다음 — agent 자동 commit/push |
| [`13-mission-control-operations.md`](13-mission-control-operations.md) | 운영자 (대시보드) | 대시보드 셋업 시 — Hermes 네이티브 대시보드 (구 Canvas 파이프라인은 deprecated) |
| [`14-mobile-vault-sync.md`](14-mobile-vault-sync.md) | Obsidian 사용자 | Phase 15 전후 — 폰 vault sync 옵션 비교 |
| [`15-obsidian-vault-integration.md`](15-obsidian-vault-integration.md) | Obsidian 사용자 | Phase 15 — vault mirror + Hermes obsidian skill |
| [`16-obsidian-rest-api-write.md`](16-obsidian-rest-api-write.md) | Obsidian 사용자 (고급) | docs/15 이후 — agent의 vault 직접 write (옵션) |
| [`17-external-workflow-delegation.md`](17-external-workflow-delegation.md) | 고급 | 라우터 익숙해진 뒤 — 외부 워크플로 엔진 위임 |

## 온보딩 트랙 2가지

### 트랙 A — Hermes 포함 (풀 스택)

보이스(STT), 5 pillar 자기학습, Telegram 회신까지 전부 원하는 경우:

1. [`01-overview.md`](01-overview.md) → [`03-execution-phase1-7.md`](03-execution-phase1-7.md) (Phase 1~7 순서대로)
2. [`04-execution-phase8-17.md`](04-execution-phase8-17.md) 매핑 따라 PLAYBOOK Phase 8~17
3. 운영 단계: [`08`](08-memory-feedback-pattern.md) / [`13`](13-mission-control-operations.md) / [`15`](15-obsidian-vault-integration.md)

### 트랙 B — Hermes 없이 (mini-router)

Hermes 설치가 막히거나 (Phase 3 TBD 참고) 최소 구성으로 시작하고 싶은 경우:

1. [`01-overview.md`](01-overview.md) → [`03-execution-phase1-7.md`](03-execution-phase1-7.md)의 Phase 1~2 (Codex OAuth + opencode)
2. Phase 3~4 대신 **Phase 4b**: [`mini-router/README.md`](../mini-router/README.md) — Telegram → tmux 포워딩 최소 버전
3. 한계 숙지: v1은 텍스트 전용 + 결과 회신 미구현 (`ssh` + `tmux attach`로 확인)
4. 이후 필요해지면 트랙 A의 Phase 3 (Hermes)으로 업그레이드 — topic map 스키마가 호환되므로 매핑 재사용 가능

트러블슈팅은 트랙 무관하게 [`06-troubleshooting.md`](06-troubleshooting.md).
