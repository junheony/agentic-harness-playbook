# Troubleshooting

자주 만나는 문제 + 해결. 본문 PLAYBOOK §20에 분산되어 있는 케이스를 한 곳에 모음.

## 진단 우선순위

문제 만났을 때 순서:

1. `./scripts/healthcheck.sh` 실행 → 어느 컴포넌트가 죽었는지 확인
2. 죽은 컴포넌트의 로그 확인 (`~/.hermes/logs/`, `~/.claude/logs/`, `~/.opencode/logs/`)
3. 본 문서에서 증상 검색
4. 검색 결과 없으면 GitHub Issues

---

## Codex OAuth

### "Authentication failed" / 로그인 안 됨

```bash
# 1. 토큰 파일 손상 확인
cat ~/.codex/auth.json 2>/dev/null || echo "FILE MISSING"

# 2. 클린 재시도
codex logout
rm -f ~/.codex/auth.json
codex login --device-auth

# 3. 그래도 실패 시 ChatGPT Plus/Pro 구독 활성 확인
# https://chatgpt.com/settings → Subscription
```

### "command not found: codex"

```bash
which npm
npm config get prefix
# Apple Silicon: /opt/homebrew, Intel Mac: /usr/local

# PATH 확인 (zshrc 또는 bashrc)
echo $PATH | grep -E "/opt/homebrew/bin|/usr/local/bin"

# 누락이면 추가:
echo 'export PATH="/opt/homebrew/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### device-auth 5분 타임아웃

```bash
# 정상 — 5분 내 입력 안 하면 만료
# 재시도:
codex logout
rm -f ~/.codex/auth.json
codex login --device-auth
# 이번엔 폰 미리 열어두고 빨리 입력
```

---

## opencode

### 인터랙티브 모드 freeze (Ctrl+C 안 먹음)

```bash
# 강제 종료
pkill -9 opencode
# 또는
ps aux | grep opencode
kill -9 <PID>
```

### `ulw`가 작동 안 함

원인 후보:

1. omo 설정 누락 — `ls ~/.config/opencode/oh-my-openagent.jsonc`
2. omo 비활성화 — `ultrawork.enabled: true` 확인
3. 서브에이전트 내부에서 호출 (작동 X — main 세션에서만)

```bash
# 검증
cat ~/.config/opencode/oh-my-openagent.jsonc | jq .ultrawork.enabled
# true 여야 함
```

### Codex OAuth 플러그인 못 찾음

```bash
# 재설치
npx -y opencode-openai-codex-auth@latest

# 설정 파일 확인
cat ~/.config/opencode/opencode.jsonc | jq .plugin
# ["opencode-openai-codex-auth@latest"] 포함되어야
```

---

## Hermes

### 새 세션에서 이전 사실 잊어버림

```bash
# 1. Memory/User 파일 확인
cat ~/.hermes/MEMORY.md
cat ~/.hermes/USER.md

# 2. 사용자가 "기억해" 명시했는지 — Hermes는 임의로 기록 안 함
# 명시적으로:
hermes chat -p "Add to memory: <중요한 사실>"

# 3. 또는 직접 편집
nano ~/.hermes/MEMORY.md
```

### MEMORY 95%+ 표시 / 응답 느림

```bash
# 강제 consolidation
hermes consolidate --force

# 또는 수동 편집
nano ~/.hermes/MEMORY.md
# 중복 제거, 오래된 사실 정리
```

### 자동 스킬이 생성 안 됨

```bash
# config 확인
grep "auto_creation" ~/.hermes/config.yaml
# auto_creation: true 여야

# 수동 트리거
hermes skill remember "이 작업 패턴 기억해"
```

### 자동 스킬이 너무 많음 (노이즈)

```bash
# threshold 상향
nano ~/.hermes/config.yaml
# skills.creation_threshold: 3 → 5 또는 10

# 무용 스킬 제거
hermes skill list
hermes skill delete <skill-name>
```

### Soul 톤이 흔들림

원인: SOUL.md가 너무 추상적이거나 모순됨.

```bash
nano ~/.hermes/SOUL.md
# 더 구체적인 톤 예시 추가:
# "응답 끝에 항상 신뢰도 태그 (높음/중간/낮음/미상)"
# "사이코펜시 절대 금지 (예: '좋은 질문입니다' 같은 빈말 X)"
```

### Cron heartbeat 안 돌음

```bash
# config 확인
grep -A 5 "crons:" ~/.hermes/config.yaml
# enabled: true 여야

# launchd 등록 확인
launchctl list | grep hermes
# 출력 없으면 Phase 6 재실행

# 수동 트리거
hermes cron run heartbeat
```

---

## Telegram 봇

### 봇이 토픽 메시지를 못 받음

분기 진단:

```bash
# 1. Privacy mode 확인 (가장 흔한 원인)
# 폰 BotFather → /mybots → 선택 → Bot Settings → Group Privacy
# → "DISABLED" 여야

# 2. 봇이 Admin 권한?
# 폰 그룹 → 설정 → Administrators → 봇 있나? 권한 모두 체크됐나?

# 3. allowed_users/allowed_chats 매칭
cat ~/.hermes/.env | grep TELEGRAM
# user_id 매칭: @userinfobot에서 본인 ID 확인

# 4. Hermes gateway 실행 중?
launchctl list | grep hermes
pgrep -f "hermes gateway"

# 5. Hermes 로그
tail -30 ~/.hermes/logs/gateway.out
tail -30 ~/.hermes/logs/gateway.err
```

### 봇 토큰 leak 의심

```bash
# 즉시 BotFather에서 회수
# 폰 BotFather → /mybots → 선택 → API Token → Revoke current token

# 새 토큰 발급 후
security delete-generic-password -a hermes -s telegram-bot-token 2>/dev/null
security add-generic-password -a hermes -s telegram-bot-token -w "<NEW_TOKEN>"

# launchd 재시작
launchctl unload ~/Library/LaunchAgents/com.nousresearch.hermes.gateway.plist
launchctl load ~/Library/LaunchAgents/com.nousresearch.hermes.gateway.plist
```

---

## mini-router (Hermes 없이 Telegram 라우팅)

[`mini-router/README.md`](../mini-router/README.md) 트랙으로 셋업한 경우의 대표 증상.

### 서비스가 crash-loop (RestartSec 간격으로 계속 재시작)

가장 흔한 원인: **secret-tool attribute가 store/lookup 간 다름** → 토큰 lookup이 빈 값 → bot.py 즉시 종료 → systemd `Restart=on-failure` 무한 반복.

```bash
# 진단
journalctl --user -u mini-router -n 30
systemctl --user status mini-router.service

# canonical attribute는 store/lookup 모두 `service hermes account <secret-name>`:
secret-tool lookup service hermes account telegram-bot-token
# 출력이 없으면 다른 attribute 조합으로 저장된 것 — canonical로 재저장:
printf '%s' '<BOT_TOKEN>' | secret-tool store --label='Telegram bot' \
  service hermes account telegram-bot-token

systemctl --user restart mini-router.service
```

### `$HOME`이라는 literal 디렉토리가 생김 / 경로 못 찾음

systemd의 `EnvironmentFile=`은 셸이 아니라서 **`$HOME` 같은 변수를 확장하지 않는다**. `~/.hermes/.env`에 `TOPIC_MAP_PATH=$HOME/.hermes/topic_map.yaml`처럼 적으면 bot이 literal `"$HOME/..."` 문자열을 경로로 받음 — 작업 디렉토리 아래에 `$HOME`이라는 이름의 디렉토리가 생기는 것이 전형적 증상.

```bash
# 해결: .env에는 절대 경로만 (변수/~ 사용 금지)
grep -n '\$HOME\|~' ~/.hermes/.env
sed -i "s|\$HOME|/home/YOUR_USERNAME|g" ~/.hermes/.env
systemctl --user restart mini-router.service
```

### topic map이 조용히 매칭 안 됨 (모든 메시지가 default 세션으로)

에러 없이 전부 `TMUX_DEFAULT_SESSION`으로만 가면 topic_map 스키마 문제. canonical 스키마는 [`examples/configs/topic-map.example.yaml`](../examples/configs/topic-map.example.yaml) 참고:

```yaml
topics:
  ops:
    topic_id: 3          # scripts/topic-discover.sh 로 확인한 숫자
    workdir: "~/dev/ops"
    session: "oc-ops"    # mini-router가 attach할 tmux 세션
```

체크리스트:

1. 사람이 읽는 이름 키(`ops:`)를 쓸 땐 **`topic_id` (숫자) 필드 필수** — 없으면 어떤 thread에도 매칭 안 됨
2. 또는 키 자체를 thread id 문자열(`"12":`)로 직접 써도 됨 (bot.py 양쪽 지원)
3. `.env`의 `TOPIC_MAP_PATH`가 실제 파일을 가리키는지 (`ls "$TOPIC_MAP_PATH"`)
4. yaml 파싱 실패는 로그에 `topic_map 읽기 실패` warning으로만 남음 — journalctl 확인

### 그룹 토픽 메시지가 봇에 아예 안 옴

BotFather privacy mode가 ON이면 Forum topic의 일반 메시지가 봇에게 전달되지 않는다.

1. BotFather → `/setprivacy` → 봇 선택 → **Disable**
2. 변경 후 봇을 그룹에서 제거했다가 다시 추가해야 반영되는 경우 있음
3. 봇을 그룹 Admin으로 두면 privacy mode와 무관하게 모든 메시지 수신

### 보이스 노트가 라우팅 안 됨

정상 동작 — **mini-router v1은 텍스트 전용**. STT(보이스) 경로는 Hermes gateway가 필요하다. 폰 키보드 받아쓰기로 텍스트 입력하거나, 보이스가 필요하면 Hermes 트랙(Phase 3~4)으로 업그레이드.

---

## launchd (Mac Mini 상시 가동)

### "Background Items Added" 알람 (macOS Sequoia+)

```
시스템 설정 → General → Login Items
→ "Allow in Background" 섹션에서 Hermes 항목 활성화
```

### 무한 재시작 루프

```bash
# 증상: ps -ef | grep hermes 했을 때 같은 PID가 계속 바뀜
# 원인: KeepAlive: true 가 빠른 크래시도 무한 재시작

# 즉시 stop
launchctl unload ~/Library/LaunchAgents/com.nousresearch.hermes.gateway.plist

# plist 수정 (v2.1 패턴)
nano ~/Library/LaunchAgents/com.nousresearch.hermes.gateway.plist
# KeepAlive를 다음으로:
# <key>KeepAlive</key>
# <dict>
#   <key>SuccessfulExit</key><false/>
#   <key>Crashed</key><true/>
# </dict>
# <key>ThrottleInterval</key><integer>30</integer>

launchctl load ~/Library/LaunchAgents/com.nousresearch.hermes.gateway.plist
```

### `command not found` (Apple Silicon)

원인: plist의 PATH에 `/opt/homebrew/bin` 누락.

```bash
nano ~/Library/LaunchAgents/com.nousresearch.hermes.gateway.plist

# EnvironmentVariables → PATH 수정:
# <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
# (/opt/homebrew/bin 맨 앞)

# 재로드
launchctl unload <plist>
launchctl load <plist>
```

### 재부팅 후 launchd 항목 사라짐

원인: plist가 `~/Library/LaunchAgents/`가 아닌 다른 경로에.

```bash
ls ~/Library/LaunchAgents/
# com.nousresearch.hermes.gateway.plist 있어야

# 없으면 재설치
hermes gateway install
```

---

## MCP 연결

### "hermes: failed to connect" (Claude Code)

```bash
# 1. 등록 확인
claude mcp list
# hermes 항목이 있어야

# 2. 없으면 등록
claude mcp add hermes --scope user -- hermes mcp serve

# 3. Claude Code 재시작 필수 (MCP는 세션 시작 시 로딩)
# macOS: Claude Code 앱 Cmd+Q → 재실행
```

### MCP 도구 호출이 빈 응답

```bash
# 직접 stdio 테스트
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | hermes mcp serve
# JSON 응답에 tools 배열 있어야

# 없으면 Hermes 자체 문제 — 재시작
launchctl unload <plist>
launchctl load <plist>
```

---

## Postgres / Database

### "password authentication failed"

```bash
# .pgpass 확인 (v2.1 권장 패턴)
cat ~/.pgpass
# hostname:port:database:username:password 형식
# 권한 600
ls -la ~/.pgpass
# -rw------- 여야

# .pgpass 없으면 생성
echo "localhost:5432:mydb:myuser:mypass" >> ~/.pgpass
chmod 600 ~/.pgpass
```

### `mcp-server-postgres` 연결 안 됨

```bash
# 환경변수 확인
echo $PGHOST $PGPORT $PGUSER $PGDATABASE
# PGPASSWORD는 절대 export 하지 말 것 — .pgpass에서 자동

# 직접 테스트
psql -h localhost -U myuser -d mydb -c "SELECT 1"
# 성공해야 MCP도 작동
```

---

## Obsidian

### MCP 연결 끊김

원인: Obsidian 데스크탑 종료 (가장 흔함). 모바일 Obsidian만 켜져 있으면 MCP 작동 안 함.

```bash
# Mac Mini에서 Obsidian 항상 실행
# 시스템 설정 → 일반 → 로그인 시 항목 → Obsidian 추가

# 또는 launchd로 자동 실행
```

### "vault not found"

```bash
# Obsidian 플러그인 설정 → Vault path 확인
# ~/Documents/Obsidian Vault/ 인가?

# Hermes config의 exclude_paths가 vault 전체 제외하고 있는지 확인
grep -A 3 "exclude_paths" ~/.hermes/config.yaml
```

### 민감 정보가 검색 결과에 노출됨

긴급:

1. `vault 분리` 패턴 적용 (Phase 15 v2.1)
2. `Obsidian Vault-Private/` 별도 vault로 이동
3. Hermes config exclude_paths 강화
4. AI에게 명시: "내가 'tax', 'wallet', 'private' 키워드 묻기 전엔 그쪽 파일 검색 X"

---

## Paperclip

### Routine 안 돌음

분기 진단:

```bash
# 1. Paperclip 서버 실행 중?
curl http://localhost:3100/api/health
# 200 OK 아니면 서버 죽음

# 2. 죽었으면 재시작
launchctl unload ~/Library/LaunchAgents/com.paperclip.server.plist
launchctl load ~/Library/LaunchAgents/com.paperclip.server.plist

# 3. cron 표현식 검증
# https://crontab.guru/ 에서 확인

# 4. agent stuck 또는 timeout?
# Paperclip UI (localhost:3100) → audit log 확인

# 5. API key 만료?
# 회사 설정 → credentials → 갱신
```

### Board approval 메시지 안 옴

```bash
# Paperclip 설정 → approval_channel 확인
# "telegram:<user_id>" 형식 맞나?

# Hermes 측에서 메시지 받는지 확인
tail ~/.hermes/logs/gateway.out | grep paperclip
```

---

## 일반 디버깅

### "어디서 에러가 났는지 모르겠다"

```bash
# 전체 로그 한 번에
tail -50 ~/.hermes/logs/*.{out,err,log} \
       ~/.claude/logs/*.log \
       ~/.opencode/logs/*.log \
       ~/.paperclip/logs/*.{out,err} 2>/dev/null

# 또는 healthcheck로
./scripts/healthcheck.sh
```

### 디스크 가득 참

```bash
# 큰 디렉토리 찾기
du -sh ~/.hermes ~/.claude ~/.opencode ~/.paperclip ~/Library/Caches/*

# 로그 정리
find ~/.hermes/logs -name "*.log" -mtime +30 -delete
find ~/.claude/logs -name "*.log" -mtime +30 -delete
find ~/.opencode/logs -name "*.log" -mtime +30 -delete

# Ghidra workspace
rm -rf /Volumes/dev/_ghidra_workspace/*.bak
```

### "재부팅 후 모두 망가졌다"

이게 가장 흔한 큰 사고. 순서대로:

```bash
# 1. healthcheck 먼저
./scripts/healthcheck.sh

# 2. launchd 항목 모두 확인
launchctl list | grep -E "(hermes|paperclip)"

# 3. sleep 정책 확인 (재부팅 후 reset 됐을 수도)
pmset -g | head -5

# 4. Tailscale 자동 시작 확인
tailscale status

# 5. OAuth 자격증명 살아있나
codex login status
ls -la ~/.codex/auth.json
```

---

## GitHub Issue 올릴 때

위 케이스에 없으면 Issue 환영. 포함할 정보:

- OS: macOS 14.x / Linux Ubuntu 22.04 / etc
- 도구 버전: `codex --version`, `hermes --version`, `claude --version`
- 재현 명령
- 기대 동작 vs 실제 동작
- 로그 (시크릿 redact)
- `healthcheck.sh` 출력
