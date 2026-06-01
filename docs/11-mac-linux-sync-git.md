# Mac ↔ Linux Sync — Git 중심 패턴

> 양쪽 머신에서 같은 프로젝트를 만지되 충돌 없이 동기화. Tailscale 위에서 git push/pull로 운영.

## 왜 (B) Git 중심?

세 가지 옵션 중 git이 가장 안전한 이유:

1. **agent 작업이 명시적 commit 단위로 가시화** — review/revert 가능
2. **conflict가 PR 단위로 명확** (실시간 sync는 silent conflict 가능)
3. **GitHub 자체가 백업** — Mac과 Linux 모두 잃어도 복구 가능
4. **branch 분리로 사용자/agent 격리** — 사용자가 main, agent가 `agent/*` branch
5. **표준 워크플로** — 새 도구 학습 X

trade-off: agent 결과 보려면 commit/push 사이클 필요. 마찰 있음. → 자동화로 줄임.

## 디렉토리 컨벤션

```text
Mac (개발 머신):
  ~/projects/<project>/         ← 사용자 작업 클론 (본인 개발 디렉토리)
       │
       ├─ origin = github.com:user/<project>.git
       └─ branch: main (사용자 작업), 가끔 PR review

Linux 서버 (24/7 prod):
  ~/dev/<project>/              ← agent 작업 클론
       │
       ├─ origin = 같은 GitHub repo
       ├─ branch: agent/* (agent 자동 push), main (pull로 받음)
       └─ Hermes/opencode 가 여기서 작업
```

토픽 매핑 (`~/.hermes/topic_map.yaml`)도 Linux 경로 가리킴:

```yaml
topics:
  my-app:
    topic_id: 12
    chat_id: <YOUR_TELEGRAM_CHAT_ID>
    workdir: "~/dev/my-app"      # Linux 경로
    default_harness: "opencode"
    skills_extra: ["postgres"]
```

## 셋업 (신규 프로젝트 단위)

### 새 프로젝트 만들 때

```bash
# 1. GitHub에서 빈 repo 생성 (또는 우리 new-project-bootstrap skill이 처리)
gh repo create user/<project> --private --clone=false

# 2. Mac (개발 머신)
cd ~/projects/
git clone git@github.com:user/<project>.git
cd <project>
# Cursor / VS Code 열고 brainstorming/DDD/etc.

# 3. Linux (agent 작업용)
ssh linux
cd ~/dev/
git clone git@github.com:user/<project>.git
# Telegram 토픽 만들고 topic-discover.sh 로 매핑
```

## 일상 워크플로

### Mac에서 작업 → Linux agent로 위임

```bash
# Mac: 일반 작업
cd ~/projects/<project>
# 편집 / commit / push

git add . && git commit -m "feat: setup" && git push

# Telegram에서 agent에게 명령
# 봇: "#my-app 토픽에서 'ulw 이 모듈 가스 최적화'"
# Hermes router → Linux ~/dev/my-app/ 에서 opencode + omo

# Linux agent가 작업 끝나면 자동 commit + push 'agent/optimize-gas-<ts>' branch
# (다음 섹션의 push 자동화 참고)

# Mac에서 결과 받기
git fetch
git checkout agent/optimize-gas-<ts>
# review 후 main으로 merge
```

### 사용자가 폰에서 명령 → 결과는 Mac/폰 어디서나

```
폰 (Telegram #my-app): "리포트 작성해줘"
   ↓
Hermes → Linux ~/dev/my-app/
   ↓
opencode + omo (Sisyphus → Hephaestus → Oracle)
   ↓
파일 변경 / 보고서 작성
   ↓
agent post-commit hook → git commit + branch push
   ↓
Mac: git pull → 변경사항 즉시 보임
폰: Hermes 채팅에 결과 요약
```

## Agent push 자동화 (다음 섹션)

agent가 작업 끝났을 때 자동으로 commit + branch push가 핵심. 패턴은 [`docs/12-agent-push-automation.md`](12-agent-push-automation.md) 참고 (TBD).

## Branch 컨벤션

| Branch prefix | 누가 | 목적 |
|----------------|------|------|
| `main` | 사용자 (또는 PR merge) | source of truth |
| `agent/<task>-<ts>` | agent 자동 | 한 task 단위 작업. PR로 review 또는 자동 merge |
| `agent/draft/<task>` | agent (실험) | 첫 시도. 사용자 검토 전엔 review 요청 X |
| `feature/<name>` | 사용자 | 큰 기능 작업 |
| `fix/<issue>` | 사용자/agent | 버그 수정 |
| `chore/agent-rollup-<date>` | rollup routine | 매일 자동 sweep + 정리 |

## GitHub 인증 (Linux 서버)

agent가 GitHub에 push하려면 인증 필요:

### 옵션 A: SSH deploy key (repo별)

```bash
# Linux 서버
ssh-keygen -t ed25519 -f ~/.ssh/<project>_deploy -C "<project>-agent"
cat ~/.ssh/<project>_deploy.pub
# → GitHub repo Settings → Deploy keys → Add (write 권한)

# ~/.ssh/config에 host 별 매핑
cat >> ~/.ssh/config <<EOF
Host github-<project>
  HostName github.com
  User git
  IdentityFile ~/.ssh/<project>_deploy
  IdentitiesOnly yes
EOF

# origin URL 변경
cd ~/dev/<project>
git remote set-url origin git@github-<project>:user/<project>.git
```

장점: repo별로 권한 격리. 한 키 lost되어도 영향 1개 repo.
단점: 새 repo마다 새 deploy key 필요.

### 옵션 B: GitHub PAT (fine-grained)

```bash
# GitHub Settings → Developer settings → Personal access tokens → Fine-grained
# Scope: 해당 repo의 contents:write, metadata:read
# 발급된 PAT를 secret-tool에:

printf '%s' '<PAT>' | secret-tool store \
  --label='GitHub agent push' \
  service hermes account github-pat

# 사용 시 (git push 전):
export GH_TOKEN=$(secret-tool lookup service hermes account github-pat)
gh auth login --with-token <<< "$GH_TOKEN"  # 1회
# 또는 git remote에 token 박기 (보안 약함):
# git remote set-url origin https://oauth2:${GH_TOKEN}@github.com/user/<project>.git
```

장점: 모든 repo 공통 token 1개로 운영 가능.
단점: token leak 시 모든 repo 영향 (fine-grained면 일부 격리).

권장: **deploy key (옵션 A)** — 보안 격리 우선. 새 repo 셋업이 1-2분이라 큰 부담 아님.

## Conflict 처리

**예방**:

- agent는 `main`에 직접 commit X — 항상 `agent/*` branch
- Mac 작업도 가능하면 `feature/*` 또는 `fix/*` branch
- main으로의 merge는 PR 또는 명시적 merge

**발생 시**:

- agent의 branch가 main에서 분기 → 자동 rebase 시도 → conflict면 사용자에게 알람
- Telegram bot에 알람: "agent/X branch가 main과 conflict. ssh로 진입해서 resolve 요청"

## 백업

기존 `scripts/backup.sh`가 매일 git push로 백업. (B) 패턴과 자연스럽게 어울림 — backup repo는 별도 private repo 또는 같은 repo의 다른 branch.

## 자주 묻는 질문

**Q: Mac에서 빠른 편집하려면?**  
A: Cursor / VS Code 그대로 사용. main에 commit 후 push. Linux는 다음 작업 때 pull.

**Q: agent가 작업하는 중에 내가 같은 파일 만지면?**  
A: 같은 branch면 conflict. branch 분리 권장. agent는 자기 `agent/*` branch만 만짐.

**Q: pull/push가 너무 잦아서 token 한도 걱정?**  
A: GitHub 가입 PAT는 시간당 5000+ 호출 가능. 일상 사용엔 충분.

**Q: agent가 자기 main으로 직접 push해도 되는 작업은?**  
A: 추천 X. 일관성을 위해 모든 agent 작업은 branch + 사용자 merge. 단, 명백한 chore (lint fix, dep update)는 자동 merge OK 룰 만들 수 있음.

## 다음 단계

- [`docs/12-agent-push-automation.md`](12-agent-push-automation.md) — agent post-task hook으로 자동 commit/push
- [`scripts/agent-commit-push.sh`](../scripts/agent-commit-push.sh) — opencode/Hermes가 호출하는 helper
- 새 프로젝트 시작 시 `new-project-bootstrap` skill이 양쪽 clone + topic 매핑 자동 처리
