# Phase 1~7 실전 실행 가이드

> 폰에서 Termius로 Mac Mini SSH → 단계별 복붙 진행용.  
> 각 단계마다 **명령 → 예상 출력 → 트러블슈팅** 형태.

---

## 사전 준비 (5분)

```bash
# Mac Mini SSH 진입 (Tailscale 이름 또는 IP)
ssh user@<mac-mini-host>

# 작업 디렉토리
mkdir -p ~/dev ~/scratch $WORKDIR_ROOT/_tools
cd ~

# 필수 도구 체크
which brew node pnpm uvx git tmux jq
# 모두 경로가 나와야 함. 없으면:
#   brew → /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
#   node → brew install node
#   pnpm → npm i -g pnpm
#   uvx  → brew install uv
#   tmux → brew install tmux
#   jq   → brew install jq
```

---

## Phase 1 — Codex OAuth (10분)

### 1.1 Codex CLI 설치

```bash
npm i -g @openai/codex
codex --version
# Codex CLI vX.X.X 같은 출력
```

### 1.2 OAuth 로그인 (device-auth 권장)

```bash
codex login --device-auth
```

**예상 출력**:

```
Please visit: https://chatgpt.com/auth/device
Enter code: XXXX-XXXX

Waiting for authentication...
```

→ 폰 브라우저로 `https://chatgpt.com/auth/device` 이동 → 코드 입력 → ChatGPT 로그인 → 권한 승인

```
✓ Authentication successful
Credentials saved to ~/.codex/auth.json
```

### 1.3 상태 검증

```bash
codex login status
echo "Exit code: $?"
# Exit code: 0 (성공)

# 가벼운 테스트
echo "hello" | codex exec "이 입력을 그대로 출력해줘"
# hello (또는 비슷한 응답)
```

### 1.4 트러블슈팅

| 증상 | 원인 | 해결 |
|------|------|------|
| `command not found: codex` | PATH 문제 | `which npm` + `npm config get prefix` 확인, PATH에 `/usr/local/bin` 또는 `/opt/homebrew/bin` 추가 |
| `Authentication failed` | 구독 미인식 | ChatGPT Plus/Pro 구독 확인. Free 플랜은 Codex 미포함 |
| `device-auth flow timeout` | 5분 내 코드 입력 안 함 | 재시도: `codex logout && codex login --device-auth` |
| `~/.codex/auth.json` 권한 에러 | 권한 600 아님 | `chmod 600 ~/.codex/auth.json` |

---

## Phase 2 — opencode + Codex OAuth 플러그인 (10분)

### 2.1 opencode 본체 설치

**안전 패턴** (curl|bash 직행 대신 fetch → inspect → run):

```bash
curl -fsSL https://opencode.ai/install -o /tmp/opencode-install.sh
less /tmp/opencode-install.sh   # 내용 확인
bash /tmp/opencode-install.sh

# 또는 공식 GitHub README의 패키지 매니저 설치 안내 따르기:
#   https://github.com/anomalyco/opencode#install

which opencode
opencode --version
```

### 2.2 Codex OAuth 플러그인 설치

```bash
npx -y opencode-openai-codex-auth@latest
```

**예상 동작**:

- `~/.config/opencode/opencode.jsonc` 자동 생성/패치
- `~/.codex/auth.json` 감지 → 자동 연결

### 2.3 설정 파일 검증

```bash
cat ~/.config/opencode/opencode.jsonc
```

다음이 포함되어야 함:

```jsonc
{
  "plugin": ["opencode-openai-codex-auth@latest"],
  "model": "openai/${MODEL_LARGE}",
  ...
}
```

없거나 불완전하면 PLAYBOOK.md § 3.2의 풀 설정으로 덮어쓰기.

### 2.4 동작 테스트

```bash
opencode run "echo \$(date)" --model=openai/${MODEL_LARGE} --variant=max
```

**예상**: 현재 시각 출력 (Codex가 한 줄 답변)

### 2.5 인터랙티브 모드 검증

```bash
opencode
```

TUI 진입 → `Tell me what you can do` 입력 → 응답 받으면 성공.

`Ctrl+C` 또는 `/exit`로 종료.

---

## Phase 3 — Hermes 설치 (15분)

### 3.1 설치

> **TBD**: 본 가이드 작성 시점에 안정적인 설치 스크립트 URL은 사용자가 직접 확인 필요.
> 공식 위치: <https://github.com/NousResearch/hermes-agent> README의 install 섹션.
> 본인이 받은 install script는 직접 실행 전 반드시 내용 검토.
>
> **Hermes 설치가 막히면 → Phase 4b (mini-router)로 진행**: 설치 스크립트가 불안정하거나 환경이 안 맞으면 Phase 3~4를 건너뛰고 [`mini-router/README.md`](../mini-router/README.md)의 최소 구성 (Telegram → tmux 포워딩)으로 시작할 수 있다. v1은 텍스트 전용이지만 "폰 → 서버 명령" 기본 흐름은 동일하게 동작. 이후 Hermes가 설치되면 topic map을 그대로 재사용해 업그레이드.

```bash
# 1. 공식 레포 README에 안내된 설치 패턴을 따른다
#    (브루 / pipx / 빌드 from source 중 사용자 환경에 맞는 것)
# 2. curl|sh 직행을 권하지 않음. 다음 패턴이 안전:
#    curl -fsSL <official-install-url> -o /tmp/hermes-install.sh
#    less /tmp/hermes-install.sh
#    sh /tmp/hermes-install.sh

# 설치 후
which hermes
hermes --version
```

### 3.2 모델 등록

```bash
hermes model
```

**대화형 프롬프트**:

```
Select provider:
> OpenAI
  Anthropic
  Local (Ollama)
  ...

Reuse Codex auth from ~/.codex/auth.json? [Y/n]: Y

Select default model:
> ${MODEL_LARGE} (variants: max, high, medium)
  ${MODEL_BALANCED} (variants: max, high, medium)
  ...
```

### 3.3 config.yaml 작성

```bash
mkdir -p ~/.hermes
nano ~/.hermes/config.yaml
```

PLAYBOOK.md § 4.2의 풀 YAML 복사. 핵심 (최소 동작 버전):

```yaml
provider: openai
model: ${MODEL_LARGE}
variant: max

memory:
  persistent: true
  auto_skill: true
  skill_dir: ~/.hermes/skills

voice:
  stt: faster-whisper
  push_to_talk: true

telegram:
  allowed_users: []   # 일단 비워두고 Phase 4에서 채움
  topic_routing: true

mcp_servers:
  filesystem:
    command: npx
    args: ["-y", "@modelcontextprotocol/server-filesystem", "/Volumes/dev"]
```

### 3.4 검증

```bash
hermes chat
# > echo test
# 응답 받으면 성공

# MCP 도구 로딩
hermes mcp test
# filesystem ✓
```

`/exit` 종료.

---

## Phase 4 — Telegram bot + Forum Topics (20분)

### 4.1 BotFather에서 봇 생성

폰 Telegram:

1. `@BotFather` 대화
2. `/newbot` → 이름 입력 → username 입력 (예: `<your-bot-name>`)
3. 토큰 받음 (예: `7123456789:AAH...`) — **이걸 안전하게 저장**
4. `/setprivacy` → 본인 봇 선택 → **Disable**
5. `/setjoingroups` → 본인 봇 선택 → **Enable**

### 4.2 user_id 확인

폰 Telegram:

1. `@userinfobot` 대화
2. `/start` 입력 → 본인 user_id 받음 (예: `123456789`)

### 4.3 봇 토큰 + user_id 저장

```bash
# Keychain (Mac 권장)
security add-generic-password -a hermes -s telegram-bot-token \
  -w "7123456789:AAH..."

# 또는 .env (덜 안전)
cat >> ~/.hermes/.env << 'EOF'
TELEGRAM_BOT_TOKEN=7123456789:AAH...
TELEGRAM_ALLOWED_USERS=123456789
EOF
chmod 600 ~/.hermes/.env
```

config.yaml에서 `allowed_users` 채우기:

```bash
nano ~/.hermes/config.yaml
# telegram.allowed_users: [123456789]
```

### 4.4 Hermes gateway setup

```bash
hermes gateway setup
```

**대화형**:

```
Select platform: Telegram
Bot token: (자동 감지 또는 입력)
✓ Bot @<your-bot-name> connected
```

### 4.5 슈퍼그룹 + Topics 생성 (폰)

Telegram 앱:

1. 새 그룹 생성 → 이름 `<your-agentic-hq>`
2. 본인만 멤버
3. 봇 추가 + Admin (모든 권한)
4. 그룹 설정 → "Topics" → Enable
5. 토픽 생성 (각각 +):
   - `ops`
   - `<project-a>`
   - `<project-b>`
   - `<project-c>`
   - `<project-d>`
   - `research`
   - `scratch`

### 4.6 topic_map.yaml 작성

```bash
nano ~/.hermes/topic_map.yaml
```

(PLAYBOOK.md § 5.7 풀 버전 또는 최소):

```yaml
topics:
  general: { workdir: "~/dev" }
  ops: { workdir: "~/dev/ops" }
  scratch: { workdir: "~/scratch" }
```

봇이 토픽 만들어진 걸 인식하면 topic_id 자동 채워줌. `hermes status` 또는 `hermes topic list`로 확인.

### 4.7 검증

폰 Telegram → `#scratch` 토픽 → "echo test" 입력 → 봇이 답변하면 성공.

### 4.8 트러블슈팅

| 증상 | 원인 | 해결 |
|------|------|------|
| 봇이 토픽 메시지 못 받음 | Privacy mode ON | BotFather `/setprivacy` → Disable |
| 봇이 그룹 추가 거부됨 | join groups OFF | BotFather `/setjoingroups` → Enable |
| 봇이 "권한 없음" 답변 | 그룹 Admin 아님 | 그룹 설정에서 봇을 Admin으로 + 모든 권한 |
| `allowed_users` 차단 메시지 | user_id 안 맞음 | `@userinfobot`에서 user_id 재확인 |

---

## Phase 5 — Claude Code MCP 브리지 (5분)

```bash
# Mac Mini ssh 후
which claude
# /usr/local/bin/claude 등

# 워크디렉토리 (글로벌 스코프)
claude mcp add hermes --scope user -- hermes mcp serve

# 확인
claude mcp list
# hermes: hermes mcp serve - ✓ Connected
```

### Claude Code 재시작

Claude Code 앱이 macOS에서 돌고 있다면 종료 후 재실행.

### 검증

Claude Code 세션 안에서:

```
> mcp__hermes__conversations_list
```

토픽 목록 반환되면 성공.

---

## Phase 6 — 상시 가동 (10분)

### 6.1 Sleep 비활성화

```bash
sudo pmset -a sleep 0
sudo pmset -a disksleep 0
sudo pmset -a displaysleep 10
sudo pmset -a womp 1
sudo pmset -a autorestart 1

# 검증
pmset -g
# sleep        0
# displaysleep 10
# disksleep    0
```

### 6.2 Hermes launchd 등록

```bash
hermes gateway install
```

자동으로 `~/Library/LaunchAgents/com.nousresearch.hermes.gateway.plist` 생성.

```bash
launchctl list | grep hermes
# com.nousresearch.hermes.gateway    <PID>    0

# 강제 시작 (혹시 RunAtLoad가 안 먹은 경우)
launchctl load ~/Library/LaunchAgents/com.nousresearch.hermes.gateway.plist
```

### 6.3 검증

```bash
# 프로세스 살아있나
ps aux | grep "hermes gateway"

# 로그
tail -f ~/.hermes/logs/gateway.out
# Telegram listener active 같은 메시지
```

다른 터미널 또는 폰에서:

```bash
# Mac Mini 강제 재부팅 후 살아남는지
sudo reboot
```

재부팅 완료 → SSH 다시 → `launchctl list | grep hermes` → 살아있으면 성공.

### 6.4 Linux 서버 변형 (systemd user unit + linger)

워크호스가 Mac Mini가 아니라 Linux 서버면 pmset/launchd 대신 systemd:

```bash
# 1. linger 활성화 — 로그아웃/재부팅 후에도 user unit 유지
loginctl enable-linger $USER
loginctl show-user $USER | grep Linger
# Linger=yes

# 2. systemd user unit 등록 (예: hermes-gateway)
mkdir -p ~/.config/systemd/user
# ~/.config/systemd/user/hermes-gateway.service 작성 후:
systemctl --user daemon-reload
systemctl --user enable --now hermes-gateway.service

# 3. 검증
systemctl --user status hermes-gateway.service
journalctl --user -u hermes-gateway -f

# 4. (노트북/데스크탑을 서버로 쓸 때만) sleep 비활성화
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
```

재부팅 후 `systemctl --user status hermes-gateway.service`가 active면 성공 — linger가 없으면 SSH 세션 종료 시 unit도 함께 죽으니 1번을 빠뜨리지 말 것.

mini-router 트랙이면 같은 패턴의 unit 예시가 [`examples/configs/mini-router.service.example`](../examples/configs/mini-router.service.example)에 있다. Hermes 네이티브 대시보드는 [`examples/configs/hermes-dashboard.service.example`](../examples/configs/hermes-dashboard.service.example) 참고.

### 6.5 Tailscale ACL (옵션, 권장)

`~/Library/Application Support/Tailscale/policy.hujson` 편집 또는 admin console에서:

PLAYBOOK.md § 7.4의 ACL 적용. 핵심: agent-host (Mac Mini) ↔ agent-client (iPhone) 통신만 허용.

---

## Phase 7 — 검증 시나리오 (10분)

### 시나리오 A: 텍스트 명령

폰 Telegram `#scratch`:

```
Mac Mini 디스크 사용량 알려줘
```

**기대 응답**: 봇이 df -h 결과 요약 표시 (예: "Volume 50%, /Volumes/dev 32%")

### 시나리오 B: 보이스 노트

폰 Telegram `#scratch` (마이크 버튼 길게 누르고 녹음):

```
"맥미니 메모리 사용량 알려줘"
```

**기대 흐름**:

1. 봇이 STT (faster-whisper) → 텍스트로 변환
2. Hermes 처리 → 메모리 정보 페치
3. 같은 토픽에 답변

### 시나리오 C: 위임 (간단)

폰 Telegram `#scratch`:

```
cc> ~/dev/ops 디렉토리에 hello.md 파일 만들고 "Hello World" 적어줘
```

**기대 흐름**:

1. Router가 `cc>` prefix 인식 → Claude Code 강제
2. tmux 세션에 `claude` 띄우고 명령 전달
3. CC가 파일 생성
4. #scratch 토픽에 "생성 완료" 회신

검증:

```bash
ls ~/dev/ops/
# hello.md
cat ~/dev/ops/hello.md
# Hello World
```

### 시나리오 D: SSH TUI 폴백

폰 Termius:

```bash
ssh user@<mac-mini-host>
tmux ls
# cc-scratch: 1 windows ...

tmux a -t cc-scratch
# 직접 Claude Code TUI 진입
```

---

## 완료 시 상태

체크리스트:

- [ ] `codex login status` exit 0
- [ ] `opencode run ...` 응답
- [ ] `hermes chat` 응답
- [ ] Telegram 봇 #scratch 토픽 응답
- [ ] `claude mcp list`에서 hermes Connected
- [ ] `launchctl list | grep hermes`에서 프로세스 살아있음
- [ ] 재부팅 후에도 위 모두 유지

여기까지 완료되면 **Phase 1~7 인프라 베이스 완성**. 다음 Phase 8 (Superpowers) 부터는 본문 PLAYBOOK.md 참조.

---

## 자주 만나는 큰 함정 (실수 사례)

1. **Apple Silicon PATH**: `/opt/homebrew/bin`이 launchd plist의 EnvironmentVariables PATH에 없으면 hermes 시작 실패. plist 편집 필수.

2. **Tailscale 미설치 상태**에서 외부 진입 시도 → 실패. Phase 0 (사전 준비)에서 Tailscale 셋업 확인.

3. **봇 토큰 leak**: GitHub commit에 토큰 들어가면 → 즉시 BotFather `/revoke` + 새 토큰 발급. `~/.hermes/.gitignore`에 `.env` 추가 필수.

4. **`pmset sleep 0`은 USB 키보드/마우스 안 깨움 동작에 영향**. 헤드리스 Mac Mini면 OK, 모니터+키보드 쓰면 displaysleep만 0이 아닌 적당한 값.

5. **MCP는 세션 시작 시 로딩**. `claude mcp add` 후 Claude Code 재시작 안 하면 도구 안 보임.

6. **여러 launchd 인스턴스**: `hermes gateway install` 두 번 실행하면 중복 등록. 의심 시:

   ```bash
   launchctl list | grep hermes  # 한 줄만 나와야 정상
   # 두 개 이상이면:
   launchctl unload ~/Library/LaunchAgents/com.nousresearch.hermes.gateway.plist
   # 그 후 다시 load
   ```

7. **macOS Sequoia (15+) 알람**: 첫 launchd 등록 시 "Background Items Added" 시스템 알람. 무시하지 말고 시스템 설정 → General → Login Items → Allow 확인.

---

## 다음 단계

이 Phase 1~7 완료 후:

1. PLAYBOOK.md § 9 (Phase 8 - Superpowers) 진행
2. § 10 (Phase 9 - omo)
3. § 11 (Phase 10 - Router SKILL.md → 이 패키지의 `skills/router/SKILL.md` 사용)
4. § 12-14 (도메인 스킬)
5. § 16 (Phase 15 - Obsidian)
6. § 17 (Phase 16 - Paperclip)

각 Phase는 독립적으로 가능. 우선 1~7만으로도 "폰에서 봇으로 명령 → Mac Mini 작업" 기본 흐름 동작.
