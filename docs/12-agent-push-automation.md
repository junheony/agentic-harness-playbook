# Agent Push Automation

> Agent 작업 끝나면 자동으로 commit + branch + push. 사용자는 Mac에서 git pull로 결과 받음.

## 왜 필요한가

(B) Git 중심 sync 패턴에서 agent 결과를 Mac에서 보려면 push가 필요. 매 작업마다 사용자가 ssh 들어가서 수동 commit/push는 마찰 큼. 자동화 패턴 필요.

## 헬퍼: `scripts/agent-commit-push.sh`

agent의 wrapper 또는 post-task hook이 호출:

```bash
./scripts/agent-commit-push.sh \
  --repo ~/dev/my-app \
  --task "gas optimization for orderbook" \
  --agent sisyphus
```

**동작**:

1. repo에 변경사항 없으면 early return
2. branch 생성: `agent/<task-slug>-<YYYYMMDD-HHMMSS>`
3. add + commit (메시지에 task / agent / timestamp)
4. push origin (옵션, default true)
5. 원래 branch로 복귀 (agent 다음 작업에 영향 X)

**옵션**:

- `--no-push` — commit만 (네트워크 없을 때)
- `AGENT_BRANCH_PREFIX=agent` (default)
- `AGENT_AUTO_PUSH=true` (default)

## 호출 패턴 — 3가지

### 패턴 A: opencode session 종료 hook

opencode TUI 종료 또는 ulw 사이클 끝날 때:

```bash
# ~/.config/opencode/hooks/post-session.sh
#!/usr/bin/env bash
WORKDIR=$(pwd)
TASK="${OPENCODE_LAST_PROMPT:-session-end}"
~/agentic-harness/scripts/agent-commit-push.sh \
  --repo "$WORKDIR" \
  --task "$TASK" \
  --agent "opencode-sisyphus"
```

opencode 1.x hook 시스템 활용 (있으면) 또는 wrapper script.

### 패턴 B: Hermes skill (작업 단위)

Hermes의 사용자 정의 skill로 추가:

```markdown
---
name: auto-commit-push
description: 작업 완료 후 자동 commit + branch push (B 패턴). 사용자가 "커밋해" / "push" 키워드 또는 자동 트리거.
---
# Auto Commit Push

작업이 끝나면 자동으로:
1. agent-commit-push.sh 호출 (repo / task / agent 인자)
2. 결과를 Telegram에 반환 (branch URL 포함)

호출:
  bash ~/agentic-harness/scripts/agent-commit-push.sh --repo $WORKDIR --task "$TASK" --agent "$AGENT"
```

사용자가 폰에서 "커밋해" 한 마디 → 이 skill 발동.

### 패턴 C: cron rollup (매일 정리)

매일 자정에 모든 활성 repo의 변경사항을 sweep:

```bash
# crontab: 0 0 * * * /home/<user>/agentic-harness/scripts/cron-agent-sweep.sh
for repo in ~/dev/*/.git; do
  REPO="${repo%/.git}"
  TASK="daily rollup $(date +%Y-%m-%d)"
  ~/agentic-harness/scripts/agent-commit-push.sh \
    --repo "$REPO" --task "$TASK" --agent "cron-sweep"
done
```

## Branch 라이프사이클

```
agent 작업
   ↓
agent/quant-orderbook-opt-20260528-013000   ← agent-commit-push.sh가 생성
   ↓ (사용자가 보고 결정)
사용자가 review:
   - Mac: git fetch && git checkout agent/quant-orderbook-opt-20260528-013000
   - Cursor / VS Code에서 diff 확인
   - 옵션 1: main으로 merge → git checkout main && git merge --no-ff agent/...
   - 옵션 2: 변경 요청 → 폰에서 "이 부분 수정해" → 새 agent branch
   - 옵션 3: discard → git branch -D agent/...
   ↓ (혹은 자동 merge 룰)
정기 cleanup:
   - 30일 이상 inactive agent branch 자동 삭제
   - PR로 변환 후 GitHub Actions에서 자동 test 통과 시 auto-merge
```

## 자동 merge 룰 (옵션)

특정 패턴은 사용자 review 없이 main에 자동 merge:

```yaml
# ~/.hermes/agent-merge-rules.yaml
auto_merge:
  - branch_pattern: "agent/lint-fix-*"
    files_only: ["*.py", "*.ts", "*.md"]  # 위험 파일 변경 X
    require_ci: true                       # GitHub Actions 통과 필수
  - branch_pattern: "agent/dep-update-*"
    require_ci: true
    require_no_breaking: true              # semver minor / patch만

manual_review_required:
  - branch_pattern: "agent/refactor-*"
  - files_pattern: ["src/auth/**", "migrations/**"]
  - branch_pattern: "agent/*-2026-12-*"   # 연말 emergency
```

실제 자동 merge는 GitHub Actions workflow로 구현 (다음 사이클).

## 인증 (push 시 GitHub 인증)

[`docs/11-mac-linux-sync-git.md`](11-mac-linux-sync-git.md) §"GitHub 인증" 참고:

- **권장**: SSH deploy key per repo
- 대안: GitHub PAT in secret-tool

agent-commit-push.sh 자체는 git remote에 인증이 박혀있다고 가정 (deploy key 또는 PAT URL).

## Telegram 알람

push 성공 시 Telegram #ops 토픽에 알람 (선택). agent-commit-push.sh에 다음 추가:

```bash
# 끝부분에
if [[ "$AUTO_PUSH" == "true" ]] && [[ -n "$REPO_HTTP" ]]; then
  TG_TOKEN=$(secret-tool lookup service hermes account telegram-bot-token)
  OPS_CHAT=$(grep TELEGRAM_OPS_CHAT_ID ~/.hermes/.env | cut -d= -f2)
  MSG="📦 agent push: \`${BRANCH}\`\nrepo: \`${REPO_HTTP##*/}\`\nbranch: ${REPO_HTTP}/tree/${BRANCH}"
  curl -fs -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${OPS_CHAT}" \
    --data-urlencode "text=${MSG}" \
    --data-urlencode "parse_mode=Markdown" >/dev/null
fi
```

## 자주 묻는 질문

**Q: agent가 자기 작업물 자체에 만족 못 해서 commit 망설일 수 있나?**  
A: agent-commit-push.sh는 "변경 있으면 무조건 branch에 푸시"라 dramatic하지 않음. branch이므로 사용자 review 단계가 안전망. 진짜 만족 못 하는 agent라면 `--no-push`로 commit만 하고 다음 사이클에 amend.

**Q: 같은 task로 여러 번 호출하면 branch 충돌?**  
A: branch 이름에 timestamp 들어가서 절대 충돌 X. 한 task에 여러 branch 생기지만 사용자가 가장 최근 branch만 review.

**Q: 큰 binary (model weights, 데이터 dump) 들어가면?**  
A: `.gitignore` 잘 짜놔야 함. agent가 큰 파일 만들면 .gitignore 미리 추가하거나 LFS 또는 별도 cloud storage. `agent-commit-push.sh` 자체엔 size 가드 없음 — 추가 가능.

**Q: 모바일에서 review 가능?**  
A: GitHub mobile 앱에서 PR/branch 보고 작은 변경은 web editor로 merge 가능. 큰 변경은 Mac에서.

## 다음 단계

- `scripts/agent-commit-push.sh` opencode/Hermes hook에 등록
- 사용자 정의 Hermes skill `auto-commit-push` 작성 (`~/.hermes/skills/auto-commit-push/SKILL.md`)
- GitHub Actions으로 자동 merge 룰 구현
- daily rollup cron 등록
