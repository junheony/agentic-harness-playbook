---
name: new-project-bootstrap
description: Use when starting a new project from zero. Enforces 4-phase workflow — Discovery (Superpowers brainstorming) → DDD (ubiquitous language + bounded contexts + aggregates + events) → Clean Architecture skeleton (domain/application/adapters/frameworks) → first walking-skeleton plan (Superpowers writing-plans). Triggers on "새 프로젝트", "new project", "프로젝트 시작", "bootstrap", "DDD로 짜자", "클린 아키텍처" 키워드 또는 빈 디렉토리에서 처음 작업할 때.
priority: 800
---

# New Project Bootstrap (DDD + Clean Architecture)

신규 프로젝트를 zero에서 시작할 때 5-phase 워크플로를 강제한다. 한 단계 건너뛰면 다음 단계 진입 금지.

## 왜 이 스킬?

신규 프로젝트의 80% 실패는 **Why가 명확하지 않은 채 코드부터 짜기 시작해서**. Superpowers `brainstorming`이 Why를 잡지만, 구조 (어떻게 코드를 배치할지)는 안 강제함. 이 스킬이 그 갭을 메움.

DDD + Clean Architecture를 강제하는 이유:

- **DDD**: 도메인 복잡도가 일정 이상이면 ubiquitous language + bounded context가 의사소통 비용을 한 자릿수 줄임
- **Clean Architecture**: 의존성 방향을 안쪽으로만 강제하면 frameworks 교체가 ripple 없이 가능 (HTTP → CLI, ORM → 다른 DB 등)

도메인 복잡도가 낮은 (CRUD 한 테이블 짜리) 프로젝트에는 오버킬. 그런 건 이 스킬 발동 X — Superpowers `brainstorming` + `writing-plans`로 충분.

## 5-Phase 워크플로

### Phase 0 — Infra Bootstrap (Phase A 진입 전 실행)

**목표**: GitHub repo + 양쪽 머신 clone + Telegram 토픽을 1회성으로 셋업.  
**트리거**: 사용자 의도가 확정되면 바로 (brief.md 한 줄, 또는 프로젝트 이름만 있어도 충분).

**옵트아웃**: 아래 중 하나면 Phase 0 skip:

- "프로젝트 이미 GitHub에 있어"
- "로컬 only"
- `--skip-infra` 플래그

**부분 실행** 가능: "GitHub은 됐고 clone만", "토픽 매핑만" 명시 시 해당 스텝만 실행.

---

#### 0-1. GitHub repo 생성

```bash
gh repo create <github-user>/<slug> \
  --private \
  --description "<brief 한 줄>" \
  --add-readme
```

- `<slug>`: kebab-case 프로젝트 이름 (예: `my-app`)
- 기본 private. 사용자가 "public으로" 명시하면 `--public`으로 변경
- `--description`: Phase A의 brief.md 첫 줄에서 추출, 아직 없으면 프로젝트명 임시 사용
- README는 Phase A 완료 후 `Why 한 문장`으로 덮어씀

#### 0-2. 양쪽 머신 clone

SSH key `id_ed25519_github` 이미 등록 가정. 순서대로 실행:

```bash
# Linux 서버 (ssh alias "linux")
ssh linux 'git clone git@github.com:<github-user>/<slug>.git ~/dev/<slug>'

# Mac (로컬)
git clone git@github.com:<github-user>/<slug>.git ~/dev/<slug>
```

clone 실패 시 SSH key 등록 여부 확인: `ssh -T git@github.com`

#### 0-3. Telegram 토픽 안내 (사용자 액션 필요)

에이전트가 사용자에게 다음을 안내:

```
Telegram 슈퍼그룹에서 + 버튼 → 새 토픽 이름 '<slug>' 으로 생성해주세요.
그 토픽에서 봇에게 메시지 한 줄 보내주세요 (예: "register").
```

토픽 매핑 자동화 2가지 방법 중 선택:

1. **자동**: 봇이 메시지 수신 시 `scripts/topic-discover.sh --watch` 가 백그라운드 폴링 → 자동 캡처
2. **수동**: `ssh linux 'cd ~/agentic-harness && ./scripts/topic-discover.sh'` 실행 후 프롬프트에 입력

#### 0-4. topic_map.yaml 업데이트

`topic-discover.sh`가 채우거나, 에이전트가 직접 `yq`로 삽입:

```yaml
topics:
  <slug>:
    topic_id: <thread_id>          # topic-discover.sh 또는 사용자가 채움
    chat_id: <YOUR_TELEGRAM_CHAT_ID>        # 슈퍼그룹 chat_id (환경변수 또는 config)
    workdir: "~/dev/<slug>"
    default_harness: "opencode"    # Phase A에서 선언한 의도로 덮어쓰기 가능
    skills_extra: []               # 도메인 추정 후 채움
    description: "<brief 한 줄>"
    registered_at: "<ISO 8601>"
```

#### 0-5. 초기 commit

```bash
cd ~/dev/<slug>
# .gitignore: 언어 확정 전이면 범용 템플릿 (Node+Python+macOS)
curl -sL https://www.toptal.com/developers/gitignore/api/macos,python,node > .gitignore
# README.md: Phase A 완료 전 placeholder
echo "# <slug>\n\n> Why (Phase A에서 채움)" > README.md
git add .gitignore README.md
git commit -m "chore: initial scaffold (Phase 0 infra bootstrap)"
git push
```

Linux 서버에서 `git pull` 로 동기화.

#### 0-6. 자동화 헬퍼 스크립트

복잡한 순서를 한 명령으로 실행하려면:

```bash
./scripts/new-project-bootstrap-infra.sh <slug> "<brief 한 줄>"
```

스크립트 위치: `agentic-harness/scripts/new-project-bootstrap-infra.sh`  
(0-1 ~ 0-5를 순서대로 실행 + 실패 시 중단 + 완료 요약 출력)

---

**Phase 0 종료 조건**:

- [ ] GitHub repo 생성 확인 (`gh repo view <github-user>/<slug>` 성공)
- [ ] Linux clone 확인 (`ssh linux 'ls ~/dev/<slug>'` 성공)
- [ ] Mac clone 확인 (`ls ~/dev/<slug>` 성공)
- [ ] Telegram 토픽 액션 대기 OR `topic_map.yaml`에 `<slug>` entry 존재
- [ ] 초기 commit push 완료

**완료 출력 형식**:

```
Infra Bootstrap 완료
  GitHub: https://github.com/<github-user>/<slug>
  Linux:  ~/dev/<slug> (clone OK)
  Mac:    ~/dev/<slug> (clone OK)
  Telegram topic: 사용자 액션 대기
  topic_map: <slug> entry 추가됨

다음: Phase A (Discovery) — Superpowers /brainstorming 호출
```

---

### Phase A — Discovery (Superpowers brainstorming 호출)

**목표**: Why + What을 텍스트로 박아넣기. 코드 한 줄도 X.

이 phase는 Superpowers의 `brainstorming` 스킬을 그대로 호출. 산출물:

- `docs/discovery/brief.md` — 1페이지짜리 (problem / users / success criteria / non-goals)
- `docs/discovery/stakeholders.md` — 핵심 이해관계자 + 각자의 관심사
- `docs/discovery/competitors.md` — 비교 대상 (있을 시)

**Phase A 종료 조건**:

- [ ] Why 한 문장이 brief.md 상단에 있음
- [ ] Success criteria 3-5개가 측정 가능한 형태로 적혔음
- [ ] Non-goals (이 프로젝트가 안 하는 것) 명시
- [ ] 사용자 본인이 brief.md 읽고 "맞다" 확인

이 4개 다 ✓ 안 되면 Phase B 진입 금지.

---

### Phase B — DDD Discovery (이 스킬이 직접 진행)

**목표**: 도메인을 코드보다 먼저 모델링.

산출물:

- `docs/domain/ubiquitous-language.md` — 핵심 용어 5-20개 + 정의 + (선택) 영어/한국어 매핑
- `docs/domain/bounded-contexts.md` — 2-5개 컨텍스트 + 경계 + 컨텍스트 간 관계 (Partnership / Customer-Supplier / Anti-corruption layer / Shared kernel 등)
- `docs/domain/aggregates.md` — 각 컨텍스트의 aggregate root + invariants + 라이프사이클
- `docs/domain/events.md` — 컨텍스트 간 통신용 domain events (이름 + payload 스키마 + 발생 조건)

**진행 방식**:

1. Phase A의 brief를 읽고 후보 용어 추출 → 사용자와 1:1 확인하며 ubiquitous language 확정
2. 용어를 그룹핑 → bounded contexts 후보 도출 → 사용자와 경계 확정
3. 각 context에서 "수정 시 invariant를 깨지 않으려면 어디까지 한 transaction이어야 하나?" → aggregate
4. context 간 "이 일이 일어나면 저쪽이 알아야 함" → domain event

**Phase B 종료 조건**:

- [ ] ubiquitous-language.md의 모든 용어가 다음 phase의 코드 식별자(class/function/module 이름)와 1:1 대응
- [ ] 각 bounded context가 1개 이상의 aggregate 가짐
- [ ] 각 aggregate가 invariant (불변식) 1개 이상 명시
- [ ] context 간 결합이 event 또는 anti-corruption layer로 명시됨 (직접 의존 X)

---

### Phase C — Clean Architecture Skeleton (이 스킬이 디렉토리 + 파일 생성)

**목표**: 의존 방향이 안쪽으로만 흐르는 디렉토리 구조. 첫 코드는 아직 X (skeleton만).

기본 디렉토리 구조 (언어 무관 패턴):

```
<project-root>/
├─ src/
│  ├─ domain/                  # Layer 1 (innermost) — 다른 어떤 layer도 import X
│  │  ├─ <context-a>/
│  │  │  ├─ aggregates/        # aggregate root entities
│  │  │  ├─ value_objects/     # immutable values
│  │  │  ├─ events/            # domain events
│  │  │  └─ services/          # domain services (when behavior doesn't fit one aggregate)
│  │  └─ <context-b>/
│  │     └─ ...
│  │
│  ├─ application/             # Layer 2 — domain만 import 가능
│  │  ├─ use_cases/            # 1 file per use case (UC1_create_X, UC2_update_Y, ...)
│  │  ├─ ports/                # interface (ABC / protocol) for adapters
│  │  │  ├─ repositories/
│  │  │  └─ external/
│  │  └─ dtos/                 # data transfer between application and adapters
│  │
│  ├─ adapters/                # Layer 3 — application + domain import 가능
│  │  ├─ inbound/              # controllers (HTTP / CLI / message handler)
│  │  └─ outbound/             # gateways (DB repository impl / external API client)
│  │
│  └─ frameworks/              # Layer 4 (outermost) — 모든 layer import 가능
│     ├─ web/                  # FastAPI / Flask / Express / etc.
│     ├─ db/                   # SQLAlchemy / Prisma / etc. 설정
│     ├─ cli/                  # CLI entry
│     └─ config/               # 환경설정, DI wiring
│
├─ tests/
│  ├─ unit/                    # domain + application (NO I/O, NO framework deps)
│  ├─ integration/             # adapters (real DB / real HTTP, but in-process)
│  └─ e2e/                     # frameworks (full stack)
│
├─ docs/
│  ├─ discovery/               # Phase A
│  └─ domain/                  # Phase B
│
├─ plans/                      # Phase D + 이후 모든 plans (Superpowers writing-plans)
├─ Makefile                    # 표준 명령 (test / lint / run)
├─ README.md                   # 한 문장 Why + 빠른 시작
└─ <build-config>              # pyproject.toml / package.json / Cargo.toml / ...
```

**언어별 의존 방향 강제 도구**:

- Python: `import-linter` config 자동 생성 (`.importlinter`)
- TypeScript: `dependency-cruiser` config (`.dependency-cruiser.js`)
- Rust: cargo workspace + `cargo deny`
- Go: `go-cleanarch` 또는 manual review

이 스킬은 위 도구 중 적절한 것 1개의 starter config를 자동 생성.

**Phase C 종료 조건**:

- [ ] 디렉토리 구조 완성
- [ ] `domain/`에서 framework 식별자 (FastAPI, SQLAlchemy 등) `import` 0건 — linter로 확인
- [ ] 각 layer마다 `README.md` 한 페이지 (책임 + 의존 방향 명시)
- [ ] `Makefile`의 `test`/`lint` 타겟 동작 (tests/ 비어있어도 lint는 pass)

---

### Phase D — Walking Skeleton (Superpowers writing-plans 호출)

**목표**: 첫 use case 1개를 e2e로 통과시키는 plan 작성 → TDD로 구현.

"Walking skeleton" = 가장 얇은 수직 슬라이스 (frameworks → adapters → application → domain → 다시 frameworks로 응답). 비즈니스 가치 X여도 OK, 단 stack 전체가 일관되게 동작.

산출물:

- `plans/0001-walking-skeleton.md` — Superpowers `writing-plans` 포맷
- 첫 use case의 unit test (failing) + 통과시킬 최소 코드

**Phase D 종료 조건**:

- [ ] `plans/0001-walking-skeleton.md` 작성 완료 + 사용자 승인
- [ ] 첫 use case의 unit test → red → green → refactor 완료
- [ ] e2e test 1개 통과 (HTTP request → DB write → response, 또는 동등 패턴)
- [ ] CI (있다면) 통과

Phase D 종료하면 이 스킬은 종료. 이후 모든 use case는 Superpowers `test-driven-development` + `writing-plans` 직접 사용.

---

## 강제 규칙 (모든 phase 공통)

1. **Phase 건너뛰기 금지** — 각 phase 종료 조건 다 못 채우면 다음 phase 진입 X
2. **도메인 모델이 frameworks를 모름** — `src/domain/`에서 ORM/HTTP/CLI 식별자 import 절대 X
3. **Aggregate 경계 = transaction 경계** — DDD 핵심 invariant
4. **Walking skeleton 먼저, scale 나중** — 첫 use case가 e2e 통과한 다음에 두 번째 use case 시작
5. **모든 use case에 TDD** — 예외는 `playbook-override` 스킬의 4개 케이스만 (일회성 / 시각 UI / 백테스트 / prompt eng)
6. **ubiquitous language ↔ code 식별자 1:1** — Phase B의 용어가 코드의 class/function 이름과 정확히 일치 (영어 번역 매핑은 docs에)

---

## 트리거 키워드

이 스킬은 다음 상황에서 발동:

- 명시 키워드: "새 프로젝트", "프로젝트 시작", "new project", "bootstrap", "DDD", "클린 아키텍처", "clean architecture"
- 빈 디렉토리에서 `claude` 또는 `opencode`가 처음 호출됨
- 기존 프로젝트지만 사용자가 "이거 다시 짜자" 명시

발동되면 첫 응답은 다음 형식:

```
[New Project Bootstrap] 시작합니다.

Phase 0: Infra Bootstrap (예상 5분)
  → GitHub repo 생성 + 양쪽 머신 clone + Telegram 토픽 안내
  → 자동화: ./scripts/new-project-bootstrap-infra.sh <slug> "<brief>"

  skip 하려면: "로컬 only" 또는 "infra 건너뛰어" 라고 말해주세요.

Phase A: Discovery (예상 20-40분)
  → Superpowers /brainstorming 스킬을 호출합니다.
  → 산출물: docs/discovery/brief.md

준비되면 첫 질문에 답해주세요:
"이 프로젝트로 누가 무엇을 할 수 있게 됩니까? 한 문장으로."
```

---

## 다른 스킬과의 통합

| 스킬 / 스크립트 | 호출 시점 |
|----------------|----------|
| `new-project-bootstrap-infra.sh` | Phase 0 — GitHub repo + clone + topic_map |
| `topic-discover.sh` | Phase 0-3 — Telegram 토픽 thread_id 캡처 |
| `brainstorming` (Superpowers) | Phase A 진입 시 |
| `writing-plans` (Superpowers) | Phase D 진입 시 |
| `test-driven-development` (Superpowers) | Phase D 이후 모든 use case |
| `verification-before-completion` (Superpowers) | 각 phase 종료 조건 검증 시 |
| `playbook-override` (repo 내장) | 응답 스타일 (6-7 step, 신뢰도 태깅) 유지 |
| `agentic-router` (repo 내장) | "새 프로젝트" 키워드 → 이 스킬로 라우트 |

---

## 안티-패턴 (이 스킬이 막는 것)

- ❌ "일단 FastAPI 깔고 시작" — Phase A 전에 framework 선택 X
- ❌ "ORM 모델이 곧 도메인 모델" — `domain/`에서 `from sqlalchemy import ...` 금지
- ❌ "use case가 컨트롤러 안에" — `application/use_cases/`에 분리 강제
- ❌ "모든 use case 한 번에 짜자" — walking skeleton 통과 전엔 두 번째 use case 금지
- ❌ "테스트는 나중에" — Phase D에서 TDD 강제

---

## 새 프로젝트 vs 기존 프로젝트 리팩토링

이 스킬은 **신규 프로젝트** 전용. 기존 프로젝트를 DDD/CA로 옮기고 싶다면 별도 스킬 `legacy-to-clean-arch` (TBD) 필요. 그 스킬은:

1. 기존 코드에서 ubiquitous language를 역추출 (현재 식별자 분석)
2. bounded context 후보 도출
3. strangler fig pattern으로 점진 마이그레이션 plan

지금은 미구현. 필요하면 별도 요청.

---

## 산출물 한눈에

이 스킬 한 사이클이 끝나면 새 프로젝트 디렉토리에 다음이 존재:

```
<project>/
├─ docs/discovery/{brief, stakeholders, competitors}.md   # Phase A
├─ docs/domain/{ubiquitous-language, bounded-contexts,
│              aggregates, events}.md                      # Phase B
├─ src/{domain, application, adapters, frameworks}/       # Phase C
├─ tests/{unit, integration, e2e}/                        # Phase C
├─ plans/0001-walking-skeleton.md                         # Phase D
├─ .importlinter | .dependency-cruiser.js | ...           # Phase C (의존 방향 lint)
├─ Makefile                                                # Phase C
└─ README.md (Why 한 문장 + 빠른 시작)                    # Phase A
```

이 시점에 첫 use case가 e2e 통과 상태 → 두 번째 use case부터는 Superpowers TDD 사이클로 진행.
