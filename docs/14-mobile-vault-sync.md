# 폰 Obsidian Vault Sync

> Mac vault `~/Documents/Obsidian Vault/` 를 폰 Obsidian에서 보려면 sync 메커니즘이 필요. 4가지 옵션 비교 + 셋업 가이드.

## 옵션 비교

| 옵션 | 비용 | 셋업 난이도 | 안정성 | 폰 latency | 추천 |
|------|------|------------|--------|-----------|------|
| **Obsidian Sync (공식)** | $8/월 | 5분 | ✅ 최고 | 2-5초 | 빠른 셋업 원하면 |
| **iCloud Drive** | 5GB 무료 (50GB $1) | 10분 | ✅ 좋음 | 30초-2분 | Apple 생태계 사용자 (Recommended) |
| **Syncthing (자체 호스팅)** | 무료 | 30분 | 좋음 | 5-15초 | 외부 서비스 거부, 풀 컨트롤 |
| **Git** | 무료 | 15분 | ✅ 좋음 | 수동 (pull) | review-friendly. Mission Control처럼 자동 갱신엔 부적합 |

## 권장: iCloud Drive (대부분 사용자에게)

### 셋업

1. **Mac 시스템 설정**:
   - Apple 메뉴 → System Settings → Apple ID → iCloud → "iCloud Drive" ON
   - "Desktop & Documents Folders" 선택 (선택 — 사용자 결정)

2. **vault를 iCloud로 이동**:

   ```bash
   # 기존 위치: ~/Documents/Obsidian Vault/
   # 새 위치: ~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Vault/
   #   (Obsidian iOS 앱이 자동 인식)
   
   # 또는 단순히 Obsidian app에서:
   # Settings → File and links → "Make Obsidian Sync default" (이건 공식 sync)
   # iCloud는 Obsidian app 외부에서 처리 — vault 폴더를 iCloud Drive 안으로 이동
   ```

3. **Obsidian Mac에서 vault 재오픈** (새 경로로)

4. **dashboard-sync.sh의 target 경로 갱신** (vault 이동했으면):

   ```bash
   # ~/bin/dashboard-sync.sh
   MAC_VAULT_TARGET="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Vault/00-Mission-Control"
   ```

5. **폰 App Store**에서 "Obsidian" 설치 → 열면 iCloud vault 자동 인식

### 트레이드-오프

- iCloud 무료 5GB 한도. 보통 텍스트 vault는 100MB 이하라 충분
- 50GB는 월 $1
- macOS↔iOS 자동 sync. 매우 안정적
- 단점: 외부 (Apple) 의존

## 옵션: Obsidian Sync (가장 빠른 셋업)

1. <https://obsidian.md/sync> → 가입 + $8/월 결제
2. Obsidian Mac → Settings → Sync → 새 remote vault 생성 + 연결
3. 폰 Obsidian 다운로드 → 같은 계정 로그인 → vault 자동 sync

### 트레이드-오프

- 5초 안에 sync (가장 빠름)
- end-to-end encrypted
- 단점: 월 비용 + 외부 서비스 의존 추가

## 옵션: Syncthing (자체 호스팅)

```bash
# Mac
brew install syncthing
syncthing --no-browser   # daemon 시작

# 폰: App Store에서 "Möbius Sync" (iOS, $5) 또는 "Syncthing-fork" (Android)
# 양쪽에서 vault 폴더를 같은 device-id로 공유 설정
```

### 트레이드-오프

- 무료, 자체 호스팅
- LAN/Tailscale 둘 다 동작
- 단점: 셋업 복잡, iOS는 유료 앱 필요

## 권장 결정 트리

```
Q1. 외부 서비스 OK?
  → YES → Q2
  → NO  → Syncthing

Q2. 월 $8 OK + 가장 빠른 셋업 원함?
  → YES → Obsidian Sync
  → NO  → Q3

Q3. Apple 생태계 (iPhone + Mac)?
  → YES → iCloud Drive (Recommended)
  → NO  → Syncthing (Android 사용자)
```

대부분 사용자: **iCloud Drive**. Apple 생태계 + 무료 5GB로 텍스트 vault 충분.

## 셋업 후 확인

폰 Obsidian 열어서:

1. 좌측 file tree에서 `00-Mission-Control` 폴더 보이는지
2. `Mission-Control.canvas` 열기 (Obsidian Mobile iOS/Android 둘 다 canvas 지원)
3. 4-컬럼 칸반 view → 카드 drilldown

end-to-end latency:

- Linux 생성 (60s) + Mac sync (60s) + iCloud upload (10s) + 폰 download (10s)
- 최대 ~3분, 평균 ~90초

## Mission Control 폴더만 sync (옵션, 효율적)

vault 전체 sync는 부담스러우면 Mission Control 폴더만:

### iCloud + symlink

```bash
# Vault는 로컬에 그대로 (~/Documents/Obsidian Vault/)
# Mission Control만 iCloud에 두고 vault에 symlink
mkdir -p ~/Library/Mobile\ Documents/iCloud\~md\~obsidian/Documents/Mission-Control-Sync
ln -s ~/Library/Mobile\ Documents/iCloud\~md\~obsidian/Documents/Mission-Control-Sync \
      ~/Documents/Obsidian\ Vault/00-Mission-Control-iCloud
```

폰에서 별도 vault로 "Mission-Control-Sync" 열기.

### 또는 dashboard-sync.sh의 target만 iCloud로

```bash
MAC_VAULT_TARGET="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/Mission-Control"
```

→ Mac vault는 그대로, 폰만 Mission Control 받음.

## 다음 결정

iCloud / Obsidian Sync / Syncthing 중 본인 환경에 맞는 옵션을 골라 해당 섹션대로 셋업하면 된다. 결정이 어려우면 위의 "권장 결정 트리" 참고 — 대부분의 Apple 생태계 사용자는 iCloud Drive로 충분.
