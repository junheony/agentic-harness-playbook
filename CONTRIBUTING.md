# Contributing

이 레포는 **reference architecture**다. 누군가의 production stack 그대로 옮기는 게 아니라, 자신의 환경에 맞게 fork해서 쓰는 게 디폴트.

그래도 다음 기여는 환영:

## 환영하는 기여

### 1. 다른 환경 가이드

- Linux (Ubuntu/Debian/Arch) 셋업
- NixOS declarative 셋업
- Windows WSL2 셋업 (launchd → systemd 변환 등)
- Cloud VM (Hetzner, DigitalOcean, AWS) 셋업

PR 위치: `docs/environments/<os-name>.md`

### 2. 새 도메인 스킬

- 본인 도메인 (예: 게임 dev, 데이터 사이언스, devops)에 fit한 SKILL.md
- `skills/<domain-name>/SKILL.md` 형태로

### 3. Paperclip 회사 골격

- 새로운 비즈니스 워크플로 매핑
- `examples/paperclip-companies/<workflow>.example.md`
- **반드시 익명화** — 본인 식별자, 회사명, 거래 정보 X

### 4. 트러블슈팅 보강

- 본인이 만난 실제 문제 + 해결
- `docs/06-troubleshooting.md`에 케이스 추가

### 5. 검증 보고서 개선

- 6에이전트 관점에서 발견한 새 issue
- `docs/05-verification-report.md`

### 6. 번역

- README 영어 버전
- 다른 언어 (일본어, 중국어 등)

## 받지 않는 기여

- **시크릿/자격증명 포함 PR** — 자동 리젝트
- **특정 SaaS 종속도 늘리는 변경** — 이 레포의 self-hosted 철학과 충돌
- **Anthropic OAuth를 opencode/Hermes에 꽂는 우회** — ToS 위반
- **익명화 안 된 개인 사례** — 실제 거래, 실제 지갑 주소, 실명 등
- **무관한 도구 광고** — 본인이 만든 거 홍보용은 사양

## PR 체크리스트

PR 보내기 전:

- [ ] `.gitignore`로 시크릿 차단되어 있나? (자동 검증 권장)
- [ ] 본인 식별자 (이름, 회사, 프로젝트명, 지갑 주소) redact?
- [ ] 새 명령은 `--dry-run` 또는 confirmation 게이트 있나?
- [ ] 새 자격증명 저장은 Keychain 또는 `.pgpass` 패턴 따르나?
- [ ] 마크다운 lint 깨끗한가? (`markdownlint **/*.md`)
- [ ] 추가 의존성이 있다면 OAuth 정책과 충돌 안 하나?

## 커밋 메시지

Conventional Commits:

- `feat:` 새 기능/스킬/가이드
- `fix:` 명령 오류, 트러블슈팅 보강
- `docs:` 문서만 변경
- `refactor:` 구조 개선 (행동 변화 X)
- `chore:` 의존성, 메타데이터
- `security:` 시크릿 leak 방지, 권한 강화 등

## 코드 스타일

- Shell 스크립트: `set -euo pipefail` 강제, `shellcheck` 통과
- Markdown: 한국어 본문 + 영어 코드/명령. 코드 블록에 language 태그 필수
- YAML: 2-space indent
- 파일 끝 newline

## Issue 가이드

새 issue 올릴 때:

- **버그**: 환경 (OS, 도구 버전), 재현 명령, 기대 동작 vs 실제 동작, 로그
- **기능 요청**: 어떤 워크플로/유스케이스 해결하는지, 왜 기존으로 안 되는지
- **트러블슈팅**: docs/06-troubleshooting.md 먼저 확인 후, 거기 없으면 issue

## 행동 강령

- 이 레포는 [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) (Contributor Covenant 2.1 요약 한국어판)를 따른다. 정중하게 — 비판은 OK, 인신공격 X.
- 프로젝트와 무관한 주제의 토론은 issue/PR에서 자제 — 기술적 컨텍스트에 집중.
- 보안 취약점은 public issue가 아니라 [SECURITY.md](SECURITY.md)의 비공개 제보 경로 (GitHub Security Advisories)로.

## 라이센스

PR로 기여한 코드는 [MIT 라이센스](LICENSE) 하에 공개됨에 동의한 것으로 간주.
