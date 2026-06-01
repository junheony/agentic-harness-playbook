# PR 요약

<!-- 무엇을, 왜 바꿨는지 한두 문장으로 -->

## 체크리스트

CONTRIBUTING.md의 PR 체크리스트 기준:

- [ ] shellcheck 통과 — `shellcheck -S warning scripts/*.sh` (셸 스크립트 변경 시)
- [ ] 라우터 테스트 통과 — `bash scripts/test-router.sh` (라우터 로직/테이블 변경 시)
- [ ] 문서 갱신 — 동작이 바뀌면 `docs/`, `playbook/`, `README.md` 반영
- [ ] 개인정보 없음 — 이름/회사/프로젝트명/지갑 주소/시크릿 redact (hygiene-scan 통과)
- [ ] 새 명령은 `--dry-run` 또는 confirmation 게이트 있음
- [ ] 마크다운 lint 깨끗함 — `markdownlint '**/*.md' --config .markdownlint.json`
