# Security Policy

이 레포는 self-hosted agentic coding 인프라의 reference architecture다. 셋업 스크립트가 시크릿(봇 토큰, OAuth 자격증명)을 다루므로, 보안 이슈 제보를 진지하게 받는다.

## 지원 범위

| 대상 | 지원 여부 |
|------|-----------|
| `main` 브랜치 (최신) | 지원 |
| 태깅된 과거 버전 | 미지원 — 항상 최신 `main` 기준으로 제보 |

정식 버전 태깅 전이므로, 취약점 수정은 `main`에만 반영된다.

## 취약점 제보 방법

**공개 issue로 올리지 말 것.** 대신:

1. 레포의 **Security 탭 → "Report a vulnerability"** (GitHub Security Advisories, 비공개 제보)를 사용한다.
2. 제보에 포함할 것: 영향 받는 파일/스크립트 경로, 재현 절차, 예상 영향 (시크릿 노출 / 명령 주입 / 권한 상승 등), 가능하면 수정 제안.

별도 보안 이메일은 운영하지 않는다 — GHSA 경로가 유일한 비공개 제보 채널이다.

## 응답 목표

- **접수 확인**: 7일 이내
- **심각도 판정 + 대응 계획 공유**: 14일 이내
- **수정 반영**: 심각도에 따라 조정 (시크릿 노출 계열은 최우선)

개인 메인테이너가 운영하는 레포이므로 상업 프로젝트 수준의 SLA는 아니지만, 위 목표를 지키려 노력한다.

## 스코프

이 레포가 직접 소유한 것만 해당:

- `scripts/` 셸 스크립트 전체 (특히 `install-all.sh`의 시크릿 처리, `backup.sh`/`restore-backup.sh` 암호화 경로)
- `mini-router/` (Telegram 봇 — allowlist 우회, 명령 주입 등)
- `examples/configs/` 설정 예시 (안전하지 않은 기본값, 권한 과다)
- 문서가 안내하는 시크릿 저장 패턴 (Keychain / secret-tool / pass / `.pgpass`)

## 스코프 밖 (out of scope)

- **외부 프로젝트 자체의 취약점**: Hermes, opencode, omo, omo_proxy, Claude Code, Codex CLI, Obsidian 및 그 플러그인 — 각 프로젝트의 보안 채널로 직접 제보할 것. 단, *이 레포의 문서/스크립트가 그 도구들을 안전하지 않게 쓰도록 안내하는 경우*는 스코프 안이다.
- 사용자가 fork 후 직접 수정한 구성에서만 발생하는 문제
- 물리적 접근 또는 이미 탈취된 계정을 전제로 한 시나리오

## 제보자 크레딧

원하면 수정 공지(CHANGELOG / advisory)에 제보자 크레딧을 남긴다. 익명 희망 시 그대로 존중.
