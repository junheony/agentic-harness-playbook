# External Workflow Delegation — 직접 만들지 말고 호출

> 우리 stack의 핵심 원칙: 검증된 외부 워크플로우 엔진을 **상황에 맞게 호출**. 매번 직접 구현하면 유지보수 부담 + 바퀴 재발명.

## 왜

우리가 만든 것 (mini-router, dashboard, agent-commit-push)도 결국 "여러 도구를 묶는 orchestration". 새 워크플로우 엔진이 나오면 직접 파헤쳐 재구현하기보다, **router에 키워드 → 호출 매핑만 추가**하면 됨.

## 사용 가능한 외부 워크플로우 엔진 2종

### 1. Claude Code Dynamic Workflows (Anthropic)

[code.claude.com/docs/ko/workflows](https://code.claude.com/docs/ko/workflows)

- **무엇**: JS 스크립트가 수십~수백 subagent를 조율. Claude가 작성, 런타임이 백그라운드 실행. 세션은 응답성 유지.
- **subagent/skill과 차이**: 계획을 **코드로 이동** — 루프/분기/중간결과를 스크립트가 보유, Claude context엔 최종 답변만.
- **언제**: 코드베이스 전체 버그 스윕 / 500파일 마이그레이션 / cross-validation 리서치 / adversarial 계획.
- **제약**: 최대 16 동시 agent, 실행당 1000 agent, 사용자 입력 X (agent 권한 prompt만 일시정지). Claude Code v2.1.154+ 필요.

**호출법**:
| 방법 | 명령 |
|------|------|
| 번들 워크플로우 | `/deep-research <질문>` |
| 단일 작업을 workflow로 | 프롬프트에 `workflow` 단어 포함 |
| 세션 전체 자동 | `/effort ultracode` (xhigh reasoning + 자동 workflow 조율) |
| 저장 (재사용) | `/workflows` → `s` → `.claude/workflows/` 또는 `~/.claude/workflows/` |

### 2. LazyCodex / omo (code-yeongyu)

[github.com/code-yeongyu/lazycodex](https://github.com/code-yeongyu/lazycodex) — `oh-my-openagent`의 codex 버전. **우리가 이미 쓰는 omo와 같은 뿌리** (`bunx --package oh-my-openagent omo install --platform=codex`).

opencode 세션에 3개 workflow 명령 추가:

| 명령 | 동작 | 사용 |
|------|------|------|
| `$ulw-loop "task"` | Oracle-verified 완료까지 self-referential loop. ultrawork 모드 500회, normal 100회 cap | "끝까지 반복해서 완성해" |
| `$ulw-plan "what"` | Prometheus 전략 planner → `plans/<slug>.md` 작성. **product code 안 씀** | "계획부터 세워줘" |
| `$start-work [plan]` | plan의 모든 checkbox 완료까지 실행 → "ORCHESTRATION COMPLETE" 출력 | "이 plan 실행해" |

(LazyCodex 정식 출시 2026-06 예정, 현재 OpenCode용. 우리는 이미 omo 설치되어 있어 omo 명령으로 동일 사용 가능)

## Router 매핑 (skills/router/SKILL.md Rule 2b)

| 상황 (폰 명령 키워드) | 호출 |
|---------------------|------|
| "끝까지 반복", "완료까지", "ulw-loop" | opencode `$ulw-loop "task"` |
| "계획 짜줘", "plan", "전략", "prometheus" | opencode `$ulw-plan "what"` |
| "작업 시작", "plan 실행", "start-work" | opencode `$start-work [plan]` |
| "전체 코드베이스", "대규모 마이그레이션", "workflow" | Claude Code dynamic workflow (`workflow` prepend) |
| "deep research", "깊은 조사", "교차 검증" | Claude Code `/deep-research` |

## 선택 기준 (어느 엔진?)

```
작업 유형?
├─ opencode 안 코딩 (구현/리팩토링/디버그)
│   ├─ 완료까지 자동 반복 → omo $ulw-loop
│   ├─ 계획만 먼저 → omo $ulw-plan
│   └─ 기존 plan 실행 → omo $start-work
├─ 코드베이스 전체 (대규모 마이그레이션/감사)
│   └─ Claude Code dynamic workflow
├─ 웹 리서치 / 교차검증
│   └─ Claude Code /deep-research
└─ 단순 병렬 burst → 기존 ulw (Rule 2)
```

## 우리 stack의 위치

```
폰 명령
  ↓
Hermes router (Rule 2b)
  ↓ 상황 판단
  ├─ omo workflow ($ulw-loop / $ulw-plan / $start-work)  ← opencode 세션 안
  ├─ Claude Code dynamic workflow (workflow 키워드)       ← Claude Code 세션
  └─ Claude Code /deep-research                          ← Claude Code 세션
  ↓
결과 → auto-commit-push (agent/<task> branch)
```

즉 우리가 만든 건 **router + git 자동화 + 모바일 진입점 + 메모리** 이고, 실제 heavy lifting (대규모 조율)은 **검증된 외부 엔진에 위임**.

## 적용 시 주의

- **비용**: workflow는 수십~수백 agent 생성 → 토큰 폭증. confirm gate 필수 (router에 Confirm=yes)
- **버전**: Claude Code v2.1.154+ (dynamic workflow), omo 최신 (lazycodex 명령)
- **omo 설치 확인**: `~/.config/opencode/oh-my-openagent.json` 존재 + opencode plugin 등록
- **Claude Code workflow는 Linux 서버에 claude CLI 있을 때만** (현재 서버엔 미설치 — opencode/omo 위주)

## 관련 자료

- router 매핑: [`skills/router/SKILL.md`](../skills/router/SKILL.md) Rule 2b
- Claude Code workflows: <https://code.claude.com/docs/ko/workflows>
- LazyCodex: <https://github.com/code-yeongyu/lazycodex>
- omo (이미 설치): <https://github.com/code-yeongyu/oh-my-openagent>
