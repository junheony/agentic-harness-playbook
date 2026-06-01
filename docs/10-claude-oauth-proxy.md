# Claude OAuth via omo_proxy (Off-Policy)

> ⚠️ **Off-policy 영역**. Claude Code의 OAuth 토큰을 opencode 등 3rd-party 도구에서 재사용하는 패턴. Anthropic ToS (2026-04 발효)에서 명시적으로 금지된 사용 방식.
>
> 본 문서는 **본인 계정 / 본인 책임 하에 사용한다는 전제**로 셋업 방법만 기록. 정지 시 매몰비용 큼.

## 왜 사람들이 이걸 하나

- Claude Pro/Max 구독 한도 안에서 opencode (또는 omo, multimodal-looker 등)에서 Claude 모델 호출 → API key 비용 별도 X
- prompt cache 9x 절감 효과 보존 (proxy가 cache_control 마커 보존)
- 같은 구독으로 여러 클라이언트 사용

## 왜 위험한가

- Anthropic ToS 위반 → 계정 정지 → Claude Pro/Max 구독 자체 사용 못 함
- 정지는 어카운트 단위. fork된 계정 X. 매몰비용 큼
- Anthropic이 추적 가능 (heuristic 또는 fingerprint)
- 2026-04 이후 enforcement 강화

## 동작 원리

```
opencode  ─→  http://127.0.0.1:34156/v1   ─→  https://api.anthropic.com
              (omo_proxy node.js)             (Claude OAuth via ~/.claude/.credentials.json)
                ↑
        cache_control 보존
        billing/session header 안정화
        OAuth refresh 자동 처리
```

[winglock/omo_proxy](https://github.com/winglock/omo_proxy) — 804 lines Node.js, built-in 모듈만 사용.

## 셋업 (Linux 서버 기준)

### 1. 의존성

- Node 18+
- Claude Code 데스크탑에 로그인된 호스트의 `~/.claude/.credentials.json` (chmod 600, ~300B)

### 2. credentials 이전

로컬 Mac에서:

```bash
scp -p ~/.claude/.credentials.json linux:~/.claude/.credentials.json
ssh linux 'chmod 600 ~/.claude/.credentials.json && stat -c "perms=%a size=%s" ~/.claude/.credentials.json'
```

### 3. proxy clone + 실행 검증

```bash
ssh linux 'git clone https://github.com/winglock/omo_proxy ~/omo_proxy'
ssh linux 'cd ~/omo_proxy && timeout 5 node proxy.js'
# 예상 출력:
#   [main] cc-proxy starting on 127.0.0.1:34156
#   [main] token available locally (expires: ...)
#   [main] ready. Configure OpenCode with:
#     ANTHROPIC_BASE_URL=http://127.0.0.1:34156/v1
#     ANTHROPIC_API_KEY=proxy-placeholder
```

### 4. systemd user unit

`examples/configs/omo-proxy.service.example` → `~/.config/systemd/user/omo-proxy.service`

```bash
systemctl --user daemon-reload
systemctl --user enable --now omo-proxy.service
systemctl --user status omo-proxy.service
```

### 5. opencode config

`~/.config/opencode/opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": ["oh-my-openagent"],
  "provider": {
    "anthropic": {
      "options": {
        "baseURL": "http://127.0.0.1:34156/v1",
        "apiKey": "proxy-placeholder"
      }
    }
  }
}
```

### 6. 검증

```bash
ssh linux 'export PATH=$HOME/.opencode/bin:$PATH && \
  echo "Reply with exactly: OK" | opencode run -m anthropic/claude-haiku-4-5'
# 응답: OK

ssh linux 'tail -5 ~/omo_proxy/proxy.log'
# [usage] in=1 total_in=N out=N cache_read=N cache_create=N
```

## prompt cache 검증

여러 번 같은 prefix로 호출하면 `cache_read` 가 점점 커지면서 청구 비용 9x 절감:

```
#1: cache_read=0      cache_create=16444  ← 첫 호출, prefix 쓰기
#2: cache_read=16444  cache_create=N      ← 두 번째부터 cache hit, 0.1x 청구
#3: cache_read=16444  cache_create=N
```

## 토큰 refresh

proxy.js가 자동 처리:

- `~/.claude/.credentials.json`의 access_token 만료 임박 → refresh_token으로 갱신 → 디스크에 write-back
- proxy 재시작해도 OAuth chain 살아있음

**만성 문제**: Mac 데스크탑 Claude Code도 같은 refresh token으로 회전 시도 → Mac이 먼저 갱신하면 서버 token이 invalidate되어 다음 사용 시 `invalid_grant` 에러.

**해결책: Mac launchd watch-and-sync**

`~/.claude/.credentials.json` 변경을 launchd가 감지 → 서버로 즉시 scp + omo-proxy restart.

설치:

```bash
# 1. sync script
cp scripts/sync-claude-creds.sh ~/bin/sync-claude-creds.sh
chmod +x ~/bin/sync-claude-creds.sh

# 2. launchd plist
cp examples/configs/com.user.claude-creds-sync.plist.example \
   ~/Library/LaunchAgents/com.user.claude-creds-sync.plist
# YOUR_USERNAME 경로 수정 (sed 또는 vim)

# 3. 로드
launchctl load ~/Library/LaunchAgents/com.user.claude-creds-sync.plist
launchctl list | grep claude-creds

# 4. 테스트 (touch credentials.json → 서버 mtime 즉시 갱신 확인)
touch ~/.claude/.credentials.json
sleep 3
ssh linux 'stat -c %y ~/.claude/.credentials.json'
# 로그: ~/.claude-creds-sync.log
```

mkdir-based atomic lock (`~/.claude-creds-sync.lockdir`) — 다중 trigger 방지. macOS/Linux 둘 다 동작.

수동 강제 refresh (script 없을 때):

```bash
scp -p ~/.claude/.credentials.json linux:~/.claude/.credentials.json
ssh linux 'chmod 600 ~/.claude/.credentials.json && systemctl --user restart omo-proxy'
```

## 한계 / 알려진 이슈

- **OAuth refresh 실패 시**: Anthropic이 device fingerprint 검사 강화하면 refresh 실패. credentials.json을 데스크탑에서 새로 만들어 옮겨야 함
- **rate limit**: Claude Max 구독 한도 안. ulw 자주 쓰면 일일 한도 빠르게 소진
- **로그 누적**: proxy.log가 매 요청 기록 → 주기적 rotate 필요 (logrotate 또는 cron)
- **단일 점**: proxy 죽으면 opencode가 Anthropic 호출 못 함. systemd `Restart=on-failure` 의존
- ⚠️ **Hermes ↔ omo_proxy tool execution 깨짐** (검증 발견): Hermes의 anthropic_adapter가 `127.0.0.1` 같은 third-party endpoint로 분류 → tool spec 다르게 전송 → Claude가 tool_use API 안 거치고 plain text로 JSON emit → 결과 사용자에게 raw 노출. **opencode 직접 호출은 정상** (opencode 자체 transport). Hermes가 Claude 모델 호출 필요하면 다른 우회 (예: hermes provider를 `anthropic_messages` transport 명시) 필요. 현재 Hermes는 `openai-codex` provider 권장.

## logrotate 추가 (권장)

```bash
sudo tee /etc/logrotate.d/omo-proxy <<EOF
/home/YOUR_USERNAME/omo_proxy/proxy.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
    copytruncate
}
EOF
```

## 관련 자료

- 원본 repo: [winglock/omo_proxy](https://github.com/winglock/omo_proxy)
- systemd unit example: [`examples/configs/omo-proxy.service.example`](../examples/configs/omo-proxy.service.example)
- README OAuth 정책 (왜 off-policy인가): [`../README.md`](../README.md) §OAuth 정책
