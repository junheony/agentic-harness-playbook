# Obsidian Vault Integration

> Mac vault (사용자 source) → Linux mirror (agent read) + Hermes의 내장 obsidian skill로 LLM이 vault 노트 검색/읽기 가능.

## 왜 (deprecated) `iansinnott/obsidian-claude-code`가 아닌가

이 repo의 옛 버전 (PLAYBOOK v2)은 `iansinnott/obsidian-claude-code` 플러그인을 가정했는데, 2026-05 시점에 해당 GitHub 레포가 404 — 우리가 이 점을 발견하고 TBD로 표시했음.

대안 셋업이 더 깔끔하다는 것도 발견:

## 채택한 아키텍처: Hermes built-in obsidian skill + vault mirror

```
Mac (source of truth)
  ~/Documents/Obsidian Vault/         ← 사용자가 Obsidian 앱에서 편집
       │
       │  Mac launchd (5분 간격)
       │  vault-mirror-sync.sh (rsync, read-only mirror)
       ▼
Linux
  ~/vault-mirror/                     ← Hermes / opencode 가 검색 / 읽기
       │
       │  OBSIDIAN_VAULT_PATH 환경변수
       ▼
Hermes obsidian skill (~/.hermes/hermes-agent/skills/note-taking/obsidian/)
  - read_file       : 노트 절대 경로로 읽기
  - search_files    : pattern (filename 또는 content) 검색
  - write_file      : staging area에 쓰기 (vault에 직접 X)
```

**왜 단방향 (Mac → Linux read-only)인가**:

- Mac이 source of truth (사용자가 적극적으로 편집)
- agent는 검색/읽기만 — vault 직접 write X (충돌 회피)
- agent가 새 노트를 만들고 싶다면 `~/dev/<project>/notes/`에 staging → 사용자가 review 후 vault에 수동 머지

write가 정말로 필요하다면 [Obsidian Local REST API plugin](https://github.com/coddingtonbear/obsidian-local-rest-api) + MCP 서버 추가 (별도 셋업).

## 셋업

### Mac 측: launchd 5분 sync

```bash
# 1. sync script
cp scripts/vault-mirror-sync.sh ~/bin/vault-mirror-sync.sh
chmod +x ~/bin/vault-mirror-sync.sh

# 2. launchd plist
cp examples/configs/com.user.vault-mirror-sync.plist.example \
   ~/Library/LaunchAgents/com.user.vault-mirror-sync.plist
# YOUR_USERNAME 경로 치환

# 3. 로드
launchctl load ~/Library/LaunchAgents/com.user.vault-mirror-sync.plist
launchctl list | grep vault-mirror

# 4. 검증
sleep 5
cat ~/.vault-mirror-sync.log | tail
ssh linux 'du -sh ~/vault-mirror/'
```

`StartInterval=300` (5분) — vault는 자주 안 바뀌니까 dashboard-sync (60s)보다 긴 간격.

### Linux 측: OBSIDIAN_VAULT_PATH 등록

```bash
ssh linux 'echo "OBSIDIAN_VAULT_PATH=/home/<user>/vault-mirror" >> ~/.hermes/.env && chmod 600 ~/.hermes/.env'
# Hermes-gateway 재시작 (EnvironmentFile=~/.hermes/.env 가 새 변수 로드)
ssh linux 'systemctl --user restart hermes-gateway.service'
```

### 검증

폰 Telegram 봇한테:

```
vault에서 "스탠포드" 검색해줘
```

또는

```
내가 작성한 "AI 강의" 노트 요약해줘
```

Hermes의 obsidian skill이 자동 발동 → `search_files` 또는 `read_file` 호출 → 결과 응답.

## rsync 한계 (한국어 + 이모지 긴 파일명)

ext4의 파일명 한도는 255 바이트. 한국어 UTF-8은 한 글자 3바이트라 약 85자 한도. 거기에 이모지까지 들어가면 더 짧음.

vault에 매우 긴 파일명 (예: "20 개발/... AI 패키스트 70).md" 같은 75자+ 한국어) 이 있으면 rsync가 `File name too long` 오류 + 그 파일만 skip.

해결 옵션:

1. **Mac 측 vault에서 파일명 단축** (가장 깨끗) — 사용자 작업
2. **Linux fs를 더 큰 한도 (Btrfs/XFS, 1024바이트) 로 변경** — 운영 부담
3. **현재 패턴 (skip + log)** — 핵심 노트는 다 sync되니까 실용적

현재는 **3** — rsync에 `--ignore-errors` flag로 long-filename fail 다른 파일 sync 안 막음. log에 어떤 파일이 fail인지 기록됨 (~/.vault-mirror-sync.log).

## router 키워드 (이미 등록됨)

`skills/router/SKILL.md` Rule 4 (domain skill keywords):

```
| `vault`, `노트`, `obsidian`, `내가 쓴`, `예전에 정리` | Claude Code 또는 Hermes (vault skill) |
| `daydream`, `연결`, `cross-topic`, `비명백`         | Claude Code + daydream |
```

폰 명령에 위 키워드 들어가면 자동으로 obsidian skill 발동.

## Hermes obsidian skill 주요 능력

`~/.hermes/hermes-agent/skills/note-taking/obsidian/SKILL.md` 본문 참고. 요약:

| 기능 | 사용 명령 |
|------|----------|
| 노트 읽기 | `read_file` with absolute path |
| 노트 목록 | `search_files` `target: "files"` `pattern: "*.md"` |
| 파일명 검색 | `search_files` `target: "files"` `pattern: "<name>"` |
| 내용 검색 (regex) | `search_files` `target: "content"` `pattern: "<regex>"` `file_glob: "*.md"` |
| 새 노트 작성 | `write_file` (단, vault read-only mirror이므로 staging area에) |
| 노트에 append | `patch` 또는 별도 staging |
| Wikilink 추가 | 본문 안에서 markdown 직접 (`[[note name]]`) |

## 더 복잡한 시나리오: Daydream (cross-note connection mining)

원본 PLAYBOOK 가정: `glebis/claude-skills`의 daydream skill — 노트 cross-link 발굴.

현재 Linux Hermes에 daydream skill 미설치. 필요하면:

```bash
# (TBD) glebis/claude-skills clone + daydream만 추출
git clone https://github.com/glebis/claude-skills /tmp/claude-skills
cp -r /tmp/claude-skills/daydream/ ~/.hermes/skills/
```

Hermes가 skills 디렉토리에서 자동 발견. router에 "daydream" 키워드 이미 등록.

## 폰 Obsidian (별도)

이 가이드는 **Linux ↔ Mac vault sync**. 폰 Obsidian은 별도 sync 메커니즘 (iCloud / Obsidian Sync / Syncthing) — [`docs/14-mobile-vault-sync.md`](14-mobile-vault-sync.md) 참고.

3-way 전체:

```
Mac vault (편집)  ←→  iCloud  ←→  폰 Obsidian (모바일 편집)
       │
       ▼ vault-mirror-sync.sh (5분, read-only)
Linux ~/vault-mirror/  ← agent (Hermes / opencode)가 검색/읽기
```

## 관련 자료

- 헬퍼 스크립트: [`scripts/vault-mirror-sync.sh`](../scripts/vault-mirror-sync.sh)
- launchd plist: [`examples/configs/com.user.vault-mirror-sync.plist.example`](../examples/configs/com.user.vault-mirror-sync.plist.example)
- Hermes obsidian skill (built-in): `~/.hermes/hermes-agent/skills/note-taking/obsidian/SKILL.md`
- 폰 vault sync: [`docs/14-mobile-vault-sync.md`](14-mobile-vault-sync.md)
