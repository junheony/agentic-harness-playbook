# Memory

> 환경 노트, 프로젝트 컨벤션, 도구 quirks, 교훈. 2,200자 한도.  
> Hermes가 사용 중에 자동 갱신함. 처음엔 짧게 시작.

## Environment

- 메인 dev 머신: <MACHINE> (예: Mac Mini Apple Silicon)
- 작업 디렉토리: `~/dev` (또는 외장 SSD 경로)
- 24/7 가동 (launchd + Tailscale + sleep 비활성화)
- 백업: `~/.{claude,hermes,paperclip,codex}` → daily git push to private repo

## Project Paths

| 프로젝트       | 경로                              | 비고                         |
|----------------|-----------------------------------|------------------------------|
| <PROJECT_A>    | ~/dev/<PROJECT_A>                 | <KEY_DETAIL>                 |
| <PROJECT_B>    | ~/dev/<PROJECT_B>                 | <KEY_DETAIL>                 |
| <PROJECT_C>    | ~/dev/<PROJECT_C>                 | <KEY_DETAIL>                 |

## Conventions

### Coding

- TDD: Superpowers 디폴트, 예외 (일회성 스크립트, 시각 UI, prompt eng) 명시 시
- 응답 구조: 6-7 step (결론→핵심→배경→분석→사실→검증→요약)
- 신뢰도 태깅: 모든 사실 (높음/중간/낮음/미상)
- 한국어 본문 + 영어 코드

### Git

- 브랜치: `feat/`, `fix/`, `refactor/`, `chore/`
- 커밋: Conventional Commits
- PR: code-reviewer 서브에이전트 검토 후 머지

### File Naming

- 일일 노트: `YYYY-MM-DD-<topic>.md`
- 스킬: `SKILL.md` + `references/` 폴더

## Tool Quirks

- **opencode**: `ulw` 키워드는 main 세션에서만 작동 (서브에이전트 X)
- **Hermes**: SOUL/USER/MEMORY는 세션 시작 시 frozen snapshot. 중간 갱신은 디스크엔 즉시, 컨텍스트엔 다음 세션부터
- **omo**: hpp ulw (hyperplan)는 무거움 — 보안 감사처럼 검증이 핵심인 작업만
- **Claude Code MCP**: 세션 시작 시 로딩. 수정 후 재시작 필요
- **Telegram bot**: privacy mode Disabled + allowed_chats 화이트리스트 필수
- **launchd**: Apple Silicon 시 PATH에 `/opt/homebrew/bin` 우선 안 두면 명령 못 찾음
- **Postgres**: 자격증명은 `.pgpass` 또는 Keychain, 절대 connection string에 plaintext X

## Workflow Patterns

### Daily

- 09:00 KST: Paperclip "Research Lab" routine 실행 → vault에 다이제스트
- 21:00 KST: Content Studio routine → 다음날 콘텐츠 초안 (Board approval 후 게시)

### Weekly

- 월요일: Paperclip audit log 리뷰
- 매주 Hermes skills 검토 (자동 생성된 것 중 promote/delete 결정)
- 일요일: 백업 검증 (`~/.claude/`, `~/.hermes/` git push 확인)

## Domain Knowledge

### <DOMAIN_1> (예: DeFi)

- <KEY_FACT_1>
- <KEY_FACT_2>

### <DOMAIN_2>

- <KEY_FACT_1>

## Lessons Learned

(Hermes가 사용 중 추가하는 영역. 초기엔 비워두기)

- (yyyy-mm-dd): 첫 교훈
- (yyyy-mm-dd): 두 번째 교훈

## Anti-Patterns

같은 실수 반복 방지:

- `chmod 777`로 권한 문제 해결하지 말 것 (보안)
- Postgres URL에 password 넣지 말 것 (Phase 12 v2.1 정정)
- `.env` 파일 git에 커밋하지 말 것
- Anthropic OAuth를 opencode/Hermes에 꽂지 말 것 (ToS)
- 알 수 없는 출처 바이너리를 호스트에서 직접 분석하지 말 것 (Phase 13)
