---
name: daydream
description: Mine Obsidian vault for non-obvious cross-note connections (default mode network style). 50 random note pairs → Sonnet synthesis → Haiku critic. Triggers on "daydream", "연결", "cross-link", "비명백" keywords.
---

# Vault Daydream Skill

Source: [glebis/claude-skills/daydream](https://github.com/glebis/claude-skills/tree/main/daydream)

Multi-agent system that mines the Obsidian vault for non-obvious connections between notes, mimicking the brain's default mode network.

## Usage

`/daydream` (Hermes will invoke this skill if vault is accessible)

## What it does

1. Auto-detects vault root from `OBSIDIAN_VAULT_PATH` or `~/vault-mirror/`
2. Scans vault for notes modified in last 120 days
3. Generates 50 recency-weighted random pairs
4. Synthesizes connections (Sonnet, parallel batches of 5)
5. Critiques and scores insights (Haiku, parallel batches)
6. Filters for quality (average score >= 7.0)
7. Outputs top connections to console or saves to vault

## Setup on server

```bash
git clone https://github.com/glebis/claude-skills /tmp/claude-skills
mkdir -p ~/.hermes/skills/daydream
cp -r /tmp/claude-skills/daydream/* ~/.hermes/skills/daydream/
mv ~/.hermes/skills/daydream/skill.md ~/.hermes/skills/daydream/SKILL.md
# 첫 줄에 frontmatter 추가 후
systemctl --user restart hermes-gateway
```

## Trigger from Telegram

- "오늘 vault에서 의외의 연결 찾아줘"
- "daydream"
- "비명백한 패턴 발견해줘"

Hermes router의 Rule 4 (Domain Skill Keywords)에서 자동 매칭.

## Related files in daydream/

- `instructions.md` — full instructions
- `synthesizer-prompt.md` — Sonnet prompt template
- `critic-prompt.md` — Haiku prompt template
