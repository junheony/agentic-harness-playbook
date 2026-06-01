# mini-router

Telegram → tmux/opencode forwarder. Hermes를 안 깐 상태에서도 Telegram 라우팅 동작시키는 minimal 버전.

## 책임

- Telegram bot polling (long polling)
- 화이트리스트 (user_id / chat_id) 검증
- 라우팅 룰 subset (cc>/oc> prefix, ulw 키워드, default forwarding)
- tmux 세션 자동 생성 + send-keys로 명령 forwarding

## 보안 모델

이 봇을 켜는 순간 **Telegram 계정 = 서버 원격 명령 채널**이 됩니다. 봇에게 메시지를 넣을 수 있는 사람은 서버의 코딩 하네스(opencode/claude)에 명령을 넣을 수 있고, 하네스는 shell 명령을 실행할 수 있습니다. 그래서:

- **Telegram 계정 2FA 필수.** 계정이 탈취되면 공격자가 그대로 서버에 명령을 보낼 수 있습니다 — "봇 접근 = 서버 접근"으로 간주하고 관리하세요.
- **`TELEGRAM_ALLOWED_USERS` 필수.** 미설정 시 봇이 기동을 거부합니다. `TELEGRAM_ALLOWED_CHATS`로 채팅방까지 제한하는 것을 권장.
- **raw shell 기본 차단.** forwarding 대상 세션이 `oc-*`/`cc-*` 하네스 세션이 아니면 거부합니다 (Telegram이 임의 bare shell 채널이 되는 것 방지). 정말 필요할 때만 `ALLOW_RAW_SHELL_SESSIONS=1`.
- 토큰은 파일 대신 secret-tool(Linux) / Keychain(macOS)에 저장.

## 한계 (v1) — 정직 버전

- **텍스트 전용.** 음성 노트(STT)·사진은 처리하지 못하고 정중히 거절 답장합니다 — 음성 경로는 Hermes가 필요합니다.
- **결과 push 없음.** 결과는 ssh로 `tmux a -t <session>` 수동 attach. v2에서 tmux pipe-pane 출력 캡처 → Telegram push 예정.
- **cold start 시 첫 명령이 씹힐 수 있음.** 세션을 방금 만든 경우 CLI 부팅 대기(`BOOT_WAIT_SECS`, 기본 3초) 후 전송하고, 답장에 cold start 사실을 표시합니다. CLI가 그래도 부팅 중이었다면 명령을 재전송하세요.
- Forum topic 매핑은 `TOPIC_MAP_PATH` yaml 로드 시만 동작
- Hermes Memory feedback 미연동

## 사전 준비 (BotFather)

1. @BotFather에서 봇 생성 → 토큰 확보
2. 그룹/Forum topic 라우팅을 쓰려면 `/setprivacy` → **Disable** (privacy mode OFF). 켜져 있으면 그룹의 일반 메시지가 봇에게 전달되지 않아 topic 라우팅이 동작하지 않습니다.

## 설치 (Linux 서버, systemd)

```bash
cd ~/agentic-harness-playbook/mini-router
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# 시크릿 (attribute 순서 canonical: service hermes account telegram-bot-token)
printf '%s' '<BOT_TOKEN>' | secret-tool store --label='Telegram mini-router' service hermes account telegram-bot-token
# 확인
secret-tool lookup service hermes account telegram-bot-token

# 로그 디렉토리 + env
mkdir -p ~/.hermes/logs
cp env.example ~/.hermes/.env
$EDITOR ~/.hermes/.env   # user_id / chat_id 채우기
chmod 600 ~/.hermes/.env

# systemd user unit
mkdir -p ~/.config/systemd/user
cp ../examples/configs/mini-router.service.example ~/.config/systemd/user/mini-router.service
# 주의: unit 파일 안의 /home/YOUR_USERNAME/agentic-harness 는 placeholder —
#       실제 클론 경로(예: /home/<username>/agentic-harness-playbook)로 수정
systemctl --user daemon-reload
systemctl --user enable --now mini-router.service
journalctl --user -u mini-router -f
```

## 설치 (macOS, launchd)

```bash
cd ~/agentic-harness-playbook/mini-router
pip3 install -r requirements.txt

# 시크릿 (macOS Keychain)
security add-generic-password -a hermes -s telegram-bot-token -w '<BOT_TOKEN>' -U

mkdir -p ~/.hermes/logs
cp env.example ~/.hermes/.env
chmod 600 ~/.hermes/.env

# launchd user agent — examples/configs/com.user.mini-router.plist.example 의
# 주석에 설치 절차 전체가 있음 (YOUR_USERNAME 치환 → LaunchAgents 복사 → bootstrap)
cp ../examples/configs/com.user.mini-router.plist.example ~/Library/LaunchAgents/com.user.mini-router.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.user.mini-router.plist
```

## 라우팅 룰 (v1 subset of skills/router/SKILL.md)

| 패턴 | 라우팅 |
|------|--------|
| `cc>` / `cc:` prefix | tmux cc-<topic> 세션 (topic 세션이 oc-*면 cc-*로 전환) |
| `oc>` / `oc:` prefix | tmux oc-<topic> 세션 (topic 세션이 cc-*면 oc-*로 전환) |
| `ulw` / `ultrawork` 키워드 | oc-<topic> + 'ulw ' prepend |
| `상태` / `status` (단문) | mini-router self-status echo back |
| topic의 `default_harness: self` | echo back (Hermes 필요 안내, forwarding 안 함) |
| 그 외 | topic 세션 또는 TMUX_DEFAULT_SESSION (default: oc-default) |

세션 이름이 `oc-*`/`cc-*`가 아니면 forwarding을 거부합니다 (보안 모델 참고).

topic 매핑 스키마는 `examples/configs/topic-map.example.yaml` 참고. `topic_id`는 `scripts/topic-discover.sh`로 확인.

## 테스트

```bash
# repo 루트에서 — 3rd-party 의존성 불필요 (telegram/yaml은 테스트가 stub 주입)
python3 -m unittest discover -s mini-router/tests -v
```

## TODO (v2)

- tmux pipe-pane 으로 출력 캡처 → Telegram 결과 push
- topic_map.yaml의 토픽별 workdir 풀 지원
- Hermes Memory feedback 통합
- Forum thread 안에서 답장 (reply_to_message_thread_id)
