---
name: agentic-harness-playbook
description: 모바일-퍼스트 agentic coding 하네스 통합 플레이북. Mac Mini + Hermes + Claude Code (Anthropic) + opencode (Codex OAuth) + omo ulw + Superpowers + Obsidian vault + Paperclip companies 전체 스택 가이드. Trigger 조건: 새 환경 셋업, 재구축, 인프라 디버깅, 또는 "playbook" / "harness" / "스택" / "전체 구조" 같은 키워드 언급 시. 본문은 같은 디렉토리의 PLAYBOOK.md (2,400+ lines) 참조.
---

# Agentic Harness Playbook (Loader)

이 SKILL.md는 진입점이고, 실제 본문은 같은 디렉토리의 `PLAYBOOK.md` (2,100+ 줄)에 있다. Progressive disclosure 패턴 — 이 메타 파일은 짧게, 풀 가이드는 on-demand 로드.

## 스택 한눈에

```
L4  진입점         : iPhone Telegram Topics / SSH (Termius)
L3  메모리/메시징  : Hermes Gateway + MCP Bridge
L3' 지식베이스     : Obsidian Vault (CC + Daydream skill)
L3" 장기 자율운영  : Paperclip Company (routine/heartbeat)
L2  오케스트레이션 : CC native subagents | omo ulw (opencode)
L1  하네스         : Claude Code (Anthropic) ⊕ opencode (Codex)
L0  메서돌로지/스킬: Superpowers + 도메인 (xlsx/db/RE/vault)
```

## OAuth 정책 (절대 위반 금지)

- **Anthropic OAuth → Claude Code 안에서만** (2026-04 ToS 발효, 3rd-party 사용 시 정지)
- **OpenAI Codex OAuth → opencode / Hermes 어디든 OK** (OpenAI 공식 지원)
- 의심스러우면 API 키 fallback

## 풀 가이드 로딩

다음 조건 시 `PLAYBOOK.md` 전체 로드:

- 사용자가 명시적으로 "playbook 보여줘" / "스택 가이드"
- Phase 1~17 중 어느 한 단계의 디테일 필요
- 트러블슈팅
- 디렉토리 구조 / 참고 링크 조회

## 빠른 라우팅 참조

| Keyword              | 어디로                              |
|----------------------|-------------------------------------|
| `ulw` / `ultrawork`  | opencode + omo                      |
| `hpp ulw`            | opencode + omo hyperplan            |
| `brainstorm` / 설계  | CC + Superpowers                    |
| `vault` / 노트       | CC + obsidian + daydream            |
| `회사` / routine     | Paperclip API                       |
| `excel` / `xlsx`     | CC + xlsx skill                     |
| `EXPLAIN` / 쿼리     | CC + postgres + sql-pro             |
| `ghidra` / reverse   | opencode + reverse-engineering      |
| `상태` / `status`    | Hermes self                         |

전체 라우팅 매트릭스 → `~/.claude/skills/router/SKILL.md` 또는 `PLAYBOOK.md` § 0.

## 의존 스킬

이 플레이북은 다음 스킬들과 호환:

- `playbook-override` — 응답 스타일 규약
- `agentic-router` — 라우팅 결정 엔진
- `superpowers/*` — 메서돌로지 (brainstorming, TDD, debugging, code-review)
- `daydream` — Obsidian vault mining
- `xlsx`, `postgres`, `database-designer`, `sql-pro` — 데이터
- `ghidra-cli`, `ios-reverse-engineering` — RE
- `korean-crypto-tax` — 도메인 (<project-b>)

## 본문 위치

같은 디렉토리: `./PLAYBOOK.md`

Git: `~/.claude/skills/agentic-harness-playbook/` (recommended deployment)
