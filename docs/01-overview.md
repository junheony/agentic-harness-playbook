# Overview — One-Page Summary

## 한 줄 요약

**iPhone 보이스 → Telegram Topic → Hermes 라우팅 → Claude Code 또는 opencode/omo → 결과를 같은 토픽으로 회신.** 그 위에 Obsidian vault, Paperclip 자율 회사, 6-에이전트 검증 보고서.

## 시간축으로 본 스택

| 시간축 | 도구 | 상태 |
|--------|------|------|
| 분~시간 (작업) | omo `ulw` (opencode 내부) | 휘발성, 학습 X |
| 시간 (세션) | Claude Code / opencode | 휘발성 |
| 시간~일 (cron) | Paperclip routine | 영구, 비즈니스 워크플로 |
| **다년 (사용자 모델)** | **Hermes 5 pillar** | **영구, 자기학습** |
| 영구 (지식) | Obsidian vault | 영구, 사용자 큐레이션 |

**핵심 통찰**: 다른 모든 도구는 작업/세션/cron 단위로만 살지만, Hermes만 **너에 대한 모델을 다년에 걸쳐 deepening**한다. 이게 5 pillar의 가치.

## 핵심 결정 사항

1. **OAuth 정책 (절대)**: Anthropic OAuth는 Claude Code에서만, OpenAI Codex OAuth는 opencode + Hermes에서. ToS 위반 우회 금지.
2. **모바일 진입점**: Telegram Forum Topics (멀티 토픽 = 멀티 프로젝트)
3. **상시 가동**: 워크호스 서버 (Mac Mini 또는 Linux)가 24/7 구동 — macOS: launchd / Linux: systemd user unit + Tailscale + sleep 비활성화
4. **하네스 분리**: Claude Code = 본진 / opencode + omo = 확장 폭발 트랙
5. **메모리 통일**: Hermes의 SOUL/USER/MEMORY가 모든 컨텍스트의 원점

## 셋업 시간

- Phase 1~7 (인프라 베이스): ~80분 (가이드 따라 + 검증 시나리오 4개)
- Phase 8 (메서돌로지): ~20분 (Superpowers 양쪽 하네스 배포)
- Phase 9 (omo): ~10분
- Phase 10~14 (스킬): 필요한 거부터 점진. 도메인별 ~10-30분
- Phase 15 (Obsidian): ~30분 (이미 vault 있다고 가정)
- Phase 16 (Paperclip): ~30분 인프라 + 회사 정의는 본인 진행
- Phase 17 (통합 검증): ~30분

**합계: 약 4시간 (인프라 베이스) + 1주일 (Paperclip 회사 정의 + Hermes 학습 안정화)**

## 무엇이 잘 되나

- **폰에서 진짜 코딩 가능**: 보이스로 "이 모듈 가스 최적화" → 17분 후 PR 받기
- **시간이 지나면 더 잘됨**: Hermes 자동 스킬 + 메모리 → 1주일 후부터 체감
- **자율 운영**: Paperclip routine으로 일일 리포트, 콘텐츠 초안, 알람 등 자동
- **지식 누적**: Obsidian vault + Daydream으로 cross-link 발굴
- **검증된 안정성**: 6-에이전트 리뷰로 critical 12건 발견 후 정정

## 무엇이 잘 안 되나 (한계)

- 신규 사용자의 cognitive load 높음 — Hermes 5 pillar 개념이 처음엔 낯섦
- 모든 시크릿 관리는 본인 책임 (가이드는 안전 패턴만 제공)
- 비용 예측 어려움 — `ulw` 자주 쓰면 토큰 소비 폭증 가능
- 멀티 머신 동기화 미해결 (v3 후보)
- Windows native 미지원 (WSL2 부분 지원)

## 추천 진행 순서

### Week 1: 인프라

- Day 1-2: Phase 1~7 셋업, Telegram bot 동작 검증
- Day 3-5: 폰으로 일상 사용 (#scratch 토픽 + 텍스트/보이스)
- Day 6-7: SOUL/USER/MEMORY 본인 정보로 채우기

### Week 2: 메서돌로지

- Day 1-2: Phase 8 Superpowers 설치
- Day 3-4: Phase 9 omo + `ulw` 첫 시도
- Day 5-7: 본인 평소 워크플로 → 라우팅 패턴 익히기

### Week 3: 도메인 + 라우터

- Day 1: Phase 10 라우터 SKILL.md 활성화
- Day 2-5: Phase 11~14 중 본인에게 필요한 도메인부터
- Day 6-7: 실전 사용 + 라우팅 결과 점검

### Week 4: 지식 + 자율

- Day 1-2: Phase 15 Obsidian
- Day 3-5: Phase 16 Paperclip 인프라 + 첫 회사 (`Research Lab` 권장)
- Day 6-7: Phase 17 통합 검증 + 1주일 운영 후 회고

## 다음에 읽을 것

- 자세한 셋업 명령: [`docs/03-execution-phase1-7.md`](03-execution-phase1-7.md)
- 아키텍처 깊이: [`docs/02-architecture.md`](02-architecture.md)
- 풀 가이드: [`playbook/PLAYBOOK.md`](../playbook/PLAYBOOK.md)
- 6에이전트 검증: [`docs/05-verification-report.md`](05-verification-report.md)
- 트러블슈팅: [`docs/06-troubleshooting.md`](06-troubleshooting.md)
- FAQ: [`docs/07-faq.md`](07-faq.md)
