# Obsidian Local REST API — agent vault write 활성화

> 이 가이드는 **agent가 vault에 직접 write 가능하게** 만드는 셋업 (옵션). [`docs/15-obsidian-vault-integration.md`](15-obsidian-vault-integration.md) 의 vault-mirror 단방향 read 패턴을 보완.

## 왜 필요한가

`docs/15` 의 vault-mirror 패턴은 read-only. agent가 vault를 검색/읽기는 가능하지만 새 노트를 vault에 직접 만들 수 없음. write 시나리오:

- agent가 daily report를 vault `03-Daily-Reports/`에 자동 저장
- 사용자 명령 ("이 결과 vault에 저장해줘") 시 agent가 새 노트 작성
- daydream skill이 발견한 connections를 vault에 노트로 commit

## 아키텍처

```
Linux agent (Hermes / opencode)
   │
   │  HTTP POST /vault/<path>
   │  (Tailscale 위 SSH 또는 직접 Mac IP)
   ▼
Mac Obsidian
   ├─ Local REST API plugin (port 27124, HTTPS + token)
   └─ vault `~/Documents/Obsidian Vault/`
        │
        ▼ vault-mirror-sync.sh (5분)
Linux ~/vault-mirror/   ← read는 여전히 mirror에서
```

write는 Mac REST API로, read는 Linux mirror로 — 분리.

## 셋업

### Step 1: Mac Obsidian에 Local REST API plugin 설치

1. Mac Obsidian 앱 → Settings → Community plugins
2. "Browse" → 검색 "Local REST API"
3. **"Local REST API" by Adam Coddington** 설치 + Enable
4. Plugin Settings:
   - **API Key**: 자동 생성됨 (필요시 regenerate)
   - **Encrypted (HTTPS)** port: 27124 (기본)
   - **Insecure (HTTP)** port: 27123 — Tailscale 안에서만 사용할 거면 OK
   - **Subject Alternative Names**: `127.0.0.1, localhost, <Mac Tailscale IP>` 추가
   - API key 복사해서 어디 보관 (다음 단계에서 사용)

### Step 2: Tailscale 경로 확인

```bash
# Mac에서
tailscale status
# → Mac의 Tailscale IP 확인 (예: 100.x.y.z)

# Linux에서
ssh linux 'tailscale ip -4 <your-mac-hostname>'  # Tailscale에 등록된 Mac 호스트명
```

또는 단순히 macOS의 LAN IP를 Linux에서 reach 가능하면 됨.

### Step 3: API key를 server secret-tool에

attribute는 canonical 형식 (`service hermes account <secret-name>`)으로 통일 — store/lookup 순서가 다르면 lookup이 조용히 실패한다:

```bash
# Mac에서 API key를 안전하게 서버로
read -rsp "Obsidian REST API key: " KEY; echo
ssh linux "printf '%s' '${KEY}' | secret-tool store --label='Obsidian Local REST API' service hermes account obsidian-rest-api-key"
unset KEY

# 검증
ssh linux 'secret-tool lookup service hermes account obsidian-rest-api-key >/dev/null && echo "✓ stored"'
```

### Step 4: server에서 API 검증

```bash
ssh linux '
MAC_IP="<Mac Tailscale IP 또는 LAN IP>"
KEY=$(secret-tool lookup service hermes account obsidian-rest-api-key)

# vault 목록 (HTTPS, self-signed cert이므로 -k)
curl -sk -H "Authorization: Bearer $KEY" \
  https://${MAC_IP}:27124/vault/ | jq ".files | length" 2>/dev/null
# → 노트 개수 출력되면 OK

# 새 노트 작성 테스트 (test-from-server.md)
curl -sk -X PUT \
  -H "Authorization: Bearer $KEY" \
  -H "Content-Type: text/markdown" \
  --data "# Test from server\n\n작성 시각: $(date)" \
  https://${MAC_IP}:27124/vault/test-from-server.md

# 확인
curl -sk -H "Authorization: Bearer $KEY" \
  https://${MAC_IP}:27124/vault/test-from-server.md
'
```

Mac Obsidian에서 `test-from-server.md` 즉시 보이면 성공.

### Step 5: MCP server 추가 (Hermes 통합)

Hermes의 obsidian skill은 filesystem-first 패턴이라 REST API 안 씀. write를 위해선 별도 MCP server 또는 wrapper script 필요.

**옵션 A: obsidian MCP server (외부 제공)**

```bash
ssh linux 'npm i -g @smithery/obsidian-mcp 2>&1 | tail -3'
# 또는 다른 obsidian MCP — 시점에 따라 활성 maintainer 확인 필요
# - https://smithery.ai/server/@MarkusPfundstein/mcp-obsidian
# - https://github.com/MarkusPfundstein/mcp-obsidian

# Claude Code MCP 등록 (있으면)
claude mcp add obsidian-rest -- npx -y @smithery/obsidian-mcp \
  --url https://${MAC_IP}:27124 \
  --api-key "$(secret-tool lookup service hermes account obsidian-rest-api-key)"
```

**옵션 B: 직접 wrapper script + Hermes skill**

헬퍼 스크립트는 **이 레포의 [`scripts/obsidian-write.sh`](../scripts/obsidian-write.sh)에 포함됨** — 새로 작성할 필요 없이 서버로 복사만 하면 된다:

```bash
# 레포 클론 위치(Mac)에서 서버로 설치
ssh linux 'mkdir -p ~/agentic-harness/scripts'
scp scripts/obsidian-write.sh linux:~/agentic-harness/scripts/
ssh linux 'chmod +x ~/agentic-harness/scripts/obsidian-write.sh'
# (레포를 다른 이름으로 clone했다면 경로를 그에 맞게 조정)

# 동작 확인
ssh linux 'OBSIDIAN_HOST=<Mac Tailscale IP> ~/agentic-harness/scripts/obsidian-write.sh "inbox/test-from-server.md" "# Test from helper"'
```

동작 요약 (`scripts/obsidian-write.sh`):

- 인자: `<vault-relative-path> [content]` — content 생략 시 stdin에서 읽음
- API key 조회 (canonical): macOS Keychain (`security find-generic-password -a hermes -s obsidian-rest-api-key -w`) → 없으면 Linux `secret-tool lookup service hermes account obsidian-rest-api-key`
- 환경변수: `OBSIDIAN_HOST` / `OBSIDIAN_PORT` (기본 27124) / `OBSIDIAN_METHOD` (`PUT` 덮어쓰기 기본, `POST` append)

Hermes skill 등록:

```bash
ssh linux 'mkdir -p ~/.hermes/skills/obsidian-write && cat > ~/.hermes/skills/obsidian-write/SKILL.md <<EOF
---
name: obsidian-write
description: Write new notes or append to existing notes in Obsidian vault via Local REST API. Use when user says "vault에 저장해줘", "노트 만들어줘" or agent autonomously creates daily reports.
---
# Obsidian Vault Write (via Local REST API)

Wrapper for ~/agentic-harness/scripts/obsidian-write.sh.
Reads API key from secret-tool (service hermes account obsidian-rest-api-key).

Usage examples:
  bash ~/agentic-harness/scripts/obsidian-write.sh "03-Daily-Reports/2026-05-28.md" "내용..."
  echo "..." | bash ~/agentic-harness/scripts/obsidian-write.sh "inbox/quick-note.md"
  OBSIDIAN_METHOD=POST bash ~/agentic-harness/scripts/obsidian-write.sh "inbox/log.md" "- append 한 줄"
EOF'
```

## 보안

- Local REST API는 token 기반 인증 (API key)
- Tailscale 위에서만 노출 (Mac에 외부 IP 노출 X)
- HTTPS (self-signed cert) — `-k` flag 필요. 또는 Tailscale cert 자동 발급
- API key는 secret-tool에 저장, 환경변수 노출 X
- Mac이 sleep / Obsidian이 quit이면 REST API 죽음 → agent write 실패 → 처음부터 graceful fallback (vault staging area에 write + 사용자가 나중에 vault에 머지)

## 한계

- **Mac 동작 의존**: Mac이 켜져있고 Obsidian이 실행 중이어야 write 가능
- **single point**: Mac 죽으면 write 막힘. graceful fallback 필요
- **token rotation**: API key 회전 시 secret-tool 갱신 필요
- **단순 write만**: 복잡한 metadata / wiki link 처리는 manually

## 우선순위

이 셋업이 필요한지부터 결정:

- ✅ **필요**: agent가 자율적으로 vault에 새 노트 생성 (daily reports, daydream output)
- ⚠️ **선택**: 사용자가 "vault에 저장" 명시 시만 — manually pipe + ssh도 충분
- ❌ **불필요**: read-only 패턴 (현재 vault-mirror) 이 충분하면 skip

## 관련 자료

- vault read 패턴 (현재 운영): [`docs/15-obsidian-vault-integration.md`](15-obsidian-vault-integration.md)
- 폰 vault sync: [`docs/14-mobile-vault-sync.md`](14-mobile-vault-sync.md)
- Obsidian Local REST API plugin: <https://github.com/coddingtonbear/obsidian-local-rest-api>
- (참고) MCP servers for Obsidian:
  - <https://github.com/MarkusPfundstein/mcp-obsidian>
  - <https://github.com/StevenStavrakis/obsidian-mcp>

## 셋업 결정

셋업 순서 요약:

1. Mac Obsidian에서 Local REST API plugin 설치 + API key 발급 (Step 1)
2. API key를 서버로 전달 (Step 3)
3. Step 4 (검증) + Step 5 (MCP 또는 wrapper script) 진행

지금 안 해도 운영엔 지장 없음 — vault read는 이미 mirror로 동작.
