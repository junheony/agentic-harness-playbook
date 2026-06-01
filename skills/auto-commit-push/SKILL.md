---
name: auto-commit-push
description: Use when the user says "커밋해" / "push" / "올려" / "commit and push" / "결과 저장" in a working directory context, or when an agent task completes and changes are on disk. Calls scripts/agent-commit-push.sh to create an agent/<task>-<timestamp> branch, commit, and push to origin. Returns the GitHub branch URL.
priority: 700
---

# Auto Commit + Push

agent 작업 후 변경된 파일들을 `agent/<task>-<ts>` branch로 commit + push.
사용자가 폰에서 한 줄로 트리거 → Mac에서 git fetch로 즉시 받음.

## 트리거

다음 키워드 중 하나 매치:

- "커밋해", "커밋해줘", "푸시해", "올려", "올려줘"
- "commit", "push", "commit and push", "save to git"
- "결과 저장", "변경사항 저장"
- agent의 post-task hook이 자동 호출 (사용자 요청 없이도)

## 동작

```
bash ~/agentic-harness/scripts/agent-commit-push.sh \
  --repo "$WORKDIR" \
  --task "$TASK_DESCRIPTION" \
  --agent "$CURRENT_AGENT"
```

**파라미터 결정**:

- `$WORKDIR` — 현재 활성 토픽의 `topic_map.yaml` workdir 또는 명시 위치
- `$TASK_DESCRIPTION` — 사용자의 최근 명령 (예: "핵심 모듈 가스 최적화") 또는 agent task name
- `$CURRENT_AGENT` — Sisyphus / Hephaestus / Oracle / sonnet / opus 등

## 응답 형식

성공 시 Telegram 답장 형식:

```
📦 commit + push 완료
  repo: <project-slug>
  task: <task description>
  branch: agent/<task-slug>-20260528-013000

  GitHub: https://github.com/<github-user>/<slug>/tree/agent/<task-slug>-20260528-013000
  compare: https://github.com/<github-user>/<slug>/compare/main...agent/<task-slug>-20260528-013000

  Mac에서 받기:
    cd ~/dev/<slug>
    git fetch && git checkout agent/<task-slug>-20260528-013000
```

변경사항 없을 시:

```
✓ 변경사항 없음 — commit/push skip
```

push 실패 시 (네트워크 / 인증):

```
⚠ commit OK, push 실패 — 네트워크 또는 SSH key 확인
   로컬 branch는 살아있음: agent/<task-slug>-<ts>
   수동 push: cd <repo> && git push -u origin <branch>
```

## 안전 가드

- 절대 `main` 또는 `master` branch에 직접 commit X — 항상 `agent/*` branch
- timestamp 포함이라 branch 충돌 X
- 사용자 명시 명령 ("force push to main") 없으면 destructive 작업 X
- secret이 포함된 파일은 `.gitignore` 의존 — agent가 .env / *.token 같은 거 만들면 자동 제외

## 예외 케이스

| 상황 | 처리 |
|------|------|
| 현재 디렉토리가 git repo 아님 | 에러 응답 + "git init 또는 cd <git-repo> 필요" |
| remote 'origin' 없음 | commit만, push skip + 안내 |
| dirty working tree (사용자가 미커밋 변경 있는 채로 agent 작업) | 일단 add + commit (agent branch에 다 들어감). 사용자 review 시 분리 가능 |
| 큰 binary 파일 (>50MB) | .gitignore 권고 또는 LFS 안내 |

## 관련 자료

- 헬퍼 스크립트: [`scripts/agent-commit-push.sh`](../../scripts/agent-commit-push.sh)
- 패턴 문서: [`docs/12-agent-push-automation.md`](../../docs/12-agent-push-automation.md)
- branch convention: [`docs/11-mac-linux-sync-git.md`](../../docs/11-mac-linux-sync-git.md)

## 예시 흐름

```
폰 (Telegram #project-a):
  "핵심 모듈 가스 30% 절감 + 테스트도"
   ↓
Hermes router → opencode 세션 (oc-project-a, workdir=~/dev/project-a)
   ↓
Sisyphus → Hephaestus (코드 작성) → Oracle (감사) → 테스트 통과
   ↓
사용자 (폰):
  "커밋해"
   ↓
이 스킬 (auto-commit-push) 발동:
  WORKDIR=~/dev/project-a
  TASK="핵심 모듈 가스 30% 절감"
  → agent-commit-push.sh 호출
   ↓
폰 (응답):
  📦 commit + push 완료
    branch: agent/gas-optimization-20260528-013000
    GitHub: https://github.com/<github-user>/project-a/tree/agent/...
```
