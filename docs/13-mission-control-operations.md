# Mission Control 운영 (Linux 생성 + Mac vault sync)

> ⚠️ **DEPRECATED**: 이 문서의 dashboard-tick / dashboard-sync 파이프라인 (Obsidian Canvas 칸반)은 **Hermes 네이티브 대시보드로 대체됨**. 신규 셋업이라면 바로 아래 "Hermes 네이티브 대시보드 (권장)" 섹션만 따라하면 된다. 이하 Canvas 파이프라인은 Hermes 없이 운영하거나 Obsidian 칸반 view가 꼭 필요한 경우를 위한 레거시 참고용.
>
> Obsidian Canvas 칸반 대시보드의 실제 운영 가이드. Linux server가 데이터 생성, Mac이 vault sync.

## Hermes 네이티브 대시보드 (권장)

Hermes에는 Kanban / Office / Memory / Skills / Schedules view + 브라우저 안 TUI chat이 포함된 빌트인 웹 대시보드가 있다. 아래 Canvas 파이프라인 (tick → render → rsync → Obsidian) 전체가 필요 없어진다:

```bash
# Linux (systemd user unit)
cp examples/configs/hermes-dashboard.service.example \
   ~/.config/systemd/user/hermes-dashboard.service
systemctl --user daemon-reload
systemctl --user enable --now hermes-dashboard.service
loginctl enable-linger $USER   # 로그아웃 후에도 유지

# 검증
systemctl --user status hermes-dashboard.service
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:9119
# 200
```

- 바인딩은 `127.0.0.1:9119` (localhost 전용) — API key가 네트워크에 노출되지 않음
- Mac/폰에서 볼 때는 SSH 터널: `ssh -N -L 9119:localhost:9119 <server>` → 브라우저에서 `http://localhost:9119`
- unit 상세 (옵션 설명 포함): [`examples/configs/hermes-dashboard.service.example`](../examples/configs/hermes-dashboard.service.example)

---

이하는 레거시 Canvas 파이프라인 (deprecated).

## 아키텍처

```
Linux 서버 (24/7)
  systemd timer (60s)
    └─ dashboard-tick.service
        ├─ scripts/agents-state.sh     → ~/.hermes/agents-state.json
        ├─ scripts/canvas-render.sh    → ~/dashboard-output/00-Mission-Control/Mission-Control.canvas
        └─ scripts/dashboard-render.sh → ~/dashboard-output/00-Mission-Control/dashboard.md
                                              │
                                              ▼ (rsync, 60s)
Mac
  launchd StartInterval=60
    └─ scripts/dashboard-sync.sh
        └─ rsync linux:~/dashboard-output/ → ~/Documents/Obsidian Vault/00-Mission-Control/
                                              │
                                              ▼
        Obsidian (Mac + 폰) — vault sync
        → Mission-Control.canvas 칸반 view
        → dashboard.md 텍스트 view
```

end-to-end latency: 0-120초 (Linux 생성 + Mac sync 각 60초).

## Linux 측 설치

```bash
# 1. systemd user units (examples/configs/dashboard-tick.{service,timer}.example)
mkdir -p ~/.config/systemd/user
cp examples/configs/dashboard-tick.service.example \
   ~/.config/systemd/user/dashboard-tick.service
cp examples/configs/dashboard-tick.timer.example \
   ~/.config/systemd/user/dashboard-tick.timer
# 경로 치환 (YOUR_USERNAME → 실제 사용자)

# 2. 출력 디렉토리
mkdir -p ~/dashboard-output/00-Mission-Control

# 3. enable + start
systemctl --user daemon-reload
systemctl --user enable --now dashboard-tick.timer

# 4. 검증
systemctl --user list-timers --no-pager | grep dashboard-tick
systemctl --user start dashboard-tick.service   # 첫 tick 강제 실행
ls -la ~/dashboard-output/00-Mission-Control/
#   → Mission-Control.canvas + dashboard.md 생성됨
```

unit 내용:

```ini
# dashboard-tick.service
[Service]
Type=oneshot
ExecStart=/bin/bash /home/YOUR_USERNAME/agentic-harness/scripts/dashboard-tick.sh

Environment=VAULT_ROOT=/home/YOUR_USERNAME/dashboard-output
Environment=MISSION_CONTROL_PATH=/home/YOUR_USERNAME/dashboard-output/00-Mission-Control/dashboard.md
Environment=CANVAS_PATH=/home/YOUR_USERNAME/dashboard-output/00-Mission-Control/Mission-Control.canvas
Environment=AGENTS_STATE_JSON=/home/YOUR_USERNAME/.hermes/agents-state.json
Environment=PAPERCLIP_URL=http://localhost:3100
```

## Mac 측 sync

```bash
# 1. sync script
cp scripts/dashboard-sync.sh ~/bin/dashboard-sync.sh
chmod +x ~/bin/dashboard-sync.sh

# 2. launchd plist
cp examples/configs/com.user.dashboard-sync.plist.example \
   ~/Library/LaunchAgents/com.user.dashboard-sync.plist
# 경로 / REMOTE 환경변수 확인

# 3. 로드
launchctl load ~/Library/LaunchAgents/com.user.dashboard-sync.plist
launchctl list | grep dashboard-sync

# 4. 검증
sleep 65
cat ~/.dashboard-sync.log | tail
ls -la ~/Documents/Obsidian\ Vault/00-Mission-Control/
```

launchd plist `StartInterval=60`이라 60초 간격 자동 실행.

## Obsidian 셋업

1. vault `Obsidian Vault` 열기
2. 좌측 file tree: `00-Mission-Control` 폴더 자동 생성됨
3. `Mission-Control.canvas` 더블클릭 → 4-컬럼 칸반:
   - **📋 Pending**: scheduled routine, Board approval 요청 (red)
   - **⚙️ In Progress**: 활성 tmux 세션, 실행 중 routine, agent roster, router 결정
   - **⚠️ Blocked**: idle > 60min 세션, failed routine, 에러 (red)
   - **✅ Done Today**: 오늘 완료된 routine, 오늘 생성된 vault 노트 (드릴다운 가능)

## 폰 Obsidian sync

vault sync 메커니즘 3가지 옵션:

- **Obsidian Sync** (공식) — 유료, 자동
- **iCloud** — vault를 iCloud Drive 안에 두면 자동
- **Syncthing** — 자체 호스팅 무료

어떤 것이든 vault sync만 되면 폰 Obsidian에서 같은 canvas 보임.

## 데이터 소스 — 무엇이 칸반에 떠야 하는가

dashboard가 풍부해지려면 다음 데이터 소스가 있어야:

| 컬럼 | 데이터 | 채워지는 시점 |
|------|--------|-------------|
| Pending | Paperclip routines (scheduled), Board approval requests | Paperclip 운영 시 |
| In Progress | 활성 tmux 세션 (oc-*, cc-*), 실행 중 routines, agents-state.json | 사용자가 폰 명령 → 세션 생성 시 |
| Blocked | 60min+ idle 세션, failed/timeout routines | 자연 발생 |
| Done Today | 오늘 완료된 routines, 오늘 생성된 vault 노트 | 매일 |

**현재 비어있다면**: agent를 한 번도 호출 안 했거나 (=세션 없음) Paperclip 미실행. 폰에서 명령 보내면 즉시 활성 카드 등장.

## 모니터링

```bash
# Linux tick 로그
ssh linux 'tail -f ~/dashboard-output/tick.log'

# Mac sync 로그
tail -f ~/.dashboard-sync.log

# 마지막 tick 시각
ssh linux 'systemctl --user list-timers | grep dashboard-tick'

# 마지막 sync 시각
launchctl print user/$UID/com.user.dashboard-sync | grep -E "last|next"
```

## 트러블슈팅

| 증상 | 점검 |
|------|------|
| Mac vault에 파일 안 옴 | `cat ~/.dashboard-sync.log` 에러 확인. ssh 인증 (Tailscale + key) |
| Canvas가 빈 placeholder만 | tmux 세션 없음 + Paperclip 미실행. 폰에서 명령 보내야 채워짐 |
| Linux tick 안 돔 | `systemctl --user status dashboard-tick.timer` |
| Canvas 카드 위치 매번 바뀜 | deterministic node id 깨짐. canvas-render.sh의 slug() 함수 확인 |
| 너무 느림 (60s) | timer `OnUnitActiveSec`을 30s로 변경. Mac launchd `StartInterval` 동일 |

## 관련 자료

- 패턴 디자인: [`docs/09-agent-instrumentation.md`](09-agent-instrumentation.md)
- 칸반 컬럼 의미 + 색상: [`scripts/canvas-render.sh`](../scripts/canvas-render.sh) 헤더 주석
- Linux systemd unit examples: [`examples/configs/dashboard-tick.*.example`](../examples/configs/)
- Mac launchd plist: [`examples/configs/com.user.dashboard-sync.plist.example`](../examples/configs/)
