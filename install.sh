#!/usr/bin/env bash
# install.sh — install ai-collab-bridge and wire it into every AI CLI on this machine
#
# Idempotent: safe to run multiple times. Detects existing installs and pointers
# and skips them rather than duplicating.
#
# Usage (after cloning to the canonical path):
#   ~/.claude/skills/ai-collab-bridge/install.sh
#
# Or from anywhere if you cloned elsewhere — the script knows its own location.
#
# What it does
# ------------
# 1. chmod +x all scripts in scripts/
# 2. If Claude Code is on PATH and the skill is not already at
#    ~/.claude/skills/ai-collab-bridge, symlinks it there so Claude Code can
#    auto-discover it
# 3. If Codex CLI is on PATH, appends a pointer section to ~/.codex/AGENTS.md
#    and copies the named-subagent toml to ~/.codex/agents/ — both are
#    idempotent and will not duplicate
# 4. If Gemini CLI is on PATH, mentions where Gemini reads global rules so the
#    user can wire it up manually (Gemini CLI does not have a single
#    well-known global instructions file at time of writing)
# 5. Runs scripts/doctor.sh to verify the result

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$SCRIPT_DIR"

green()  { printf "  \033[32m✓\033[0m  %s\n" "$1"; }
yellow() { printf "  \033[33m!\033[0m  %s\n" "$1"; }
red()    { printf "  \033[31m✗\033[0m  %s\n" "$1"; }
dim()    { printf "      \033[2m%s\033[0m\n" "$1"; }
header() { printf "\n\033[1m%s\033[0m\n" "$1"; }

header "AI Collab Bridge — installer"
echo "  Source: $SKILL_DIR"
echo

# 1. Make scripts executable
header "1. Scripts"
chmod +x "$SKILL_DIR/scripts/"*.sh "$SKILL_DIR/install.sh" 2>/dev/null || true
green "scripts made executable"

# 2. Claude Code discovery
header "2. Claude Code"
CLAUDE_SKILLS_DIR="$HOME/.claude/skills"
CLAUDE_SKILL_LINK="$CLAUDE_SKILLS_DIR/ai-collab-bridge"

if command -v claude >/dev/null 2>&1; then
    mkdir -p "$CLAUDE_SKILLS_DIR"
    if [ -e "$CLAUDE_SKILL_LINK" ] || [ -L "$CLAUDE_SKILL_LINK" ]; then
        if [ "$(readlink "$CLAUDE_SKILL_LINK" 2>/dev/null || true)" = "$SKILL_DIR" ]; then
            green "already symlinked: $CLAUDE_SKILL_LINK -> $SKILL_DIR"
        elif [ "$CLAUDE_SKILL_LINK" = "$SKILL_DIR" ]; then
            green "skill is already at the canonical Claude Code path"
        else
            yellow "$CLAUDE_SKILL_LINK already exists pointing elsewhere"
            dim "remove it first if you want this install to take precedence"
        fi
    else
        ln -s "$SKILL_DIR" "$CLAUDE_SKILL_LINK"
        green "symlinked: $CLAUDE_SKILL_LINK -> $SKILL_DIR"
    fi
    dim "Claude Code will auto-discover the skill on next session start"
else
    yellow "claude CLI not detected — skipping Claude Code wiring"
    dim "install Claude Code later: https://docs.claude.com/claude-code"
fi

# 3. Codex CLI discovery
header "3. Codex CLI"
CODEX_HOME="$HOME/.codex"
CODEX_AGENTS_MD="$CODEX_HOME/AGENTS.md"
CODEX_AGENTS_DIR="$CODEX_HOME/agents"
CODEX_TOML_SRC="$SKILL_DIR/codex/ai-collab-bridge.toml"
CODEX_TOML_DST="$CODEX_AGENTS_DIR/ai-collab-bridge.toml"

if command -v codex >/dev/null 2>&1; then
    mkdir -p "$CODEX_HOME" "$CODEX_AGENTS_DIR"
    touch "$CODEX_AGENTS_MD"

    if grep -q "ai-collab-bridge" "$CODEX_AGENTS_MD"; then
        green "AGENTS.md already mentions ai-collab-bridge"
    else
        cat >> "$CODEX_AGENTS_MD" <<'AGENTS_BLOCK'

## ai-collab-bridge — peer review with Claude / Gemini

Free open-source skill at `~/.claude/skills/ai-collab-bridge`. Use whenever the user asks for AI peer review, code review handoff, "use the bridge", or wants you to ship work for Claude / Gemini to look at.

As IMPLEMENTER:
```
SUMMARY="What you did" \
QUESTIONS="What to focus on" \
~/.claude/skills/ai-collab-bridge/scripts/stage-packet.sh main > /tmp/packet.md

~/.claude/skills/ai-collab-bridge/scripts/request-review.sh claude /tmp/packet.md
# or gemini
```

As REVIEWER (you receive a packet wrapped in the review-request template):
Respond using `~/.claude/skills/ai-collab-bridge/templates/review-response.md`. Format:
- Verdict: `APPROVE` | `CONCERNS` | `BLOCK` (no other values)
- Findings with file:line refs, grouped by Bugs / Security / Quality / Suggestions
- `What I checked` + `What I did NOT check` (both required)

Role playbook: `~/.claude/skills/ai-collab-bridge/references/role-codex.md`
Repo: https://github.com/owgit/ai-collab-bridge
AGENTS_BLOCK
        green "added ai-collab-bridge section to $CODEX_AGENTS_MD"
    fi

    if [ -f "$CODEX_TOML_DST" ]; then
        green "subagent already installed: $CODEX_TOML_DST"
    elif [ -f "$CODEX_TOML_SRC" ]; then
        cp "$CODEX_TOML_SRC" "$CODEX_TOML_DST"
        green "installed subagent: $CODEX_TOML_DST"
    else
        yellow "subagent template missing at $CODEX_TOML_SRC — skipping"
        dim "this is fine; the AGENTS.md pointer is enough on its own"
    fi
    dim "Codex will see the bridge in every new session"
else
    yellow "codex CLI not detected — skipping Codex wiring"
    dim "install Codex later: npm install -g @openai/codex"
fi

# 4. Gemini CLI (advisory only — no single canonical config path)
header "4. Gemini CLI"
if command -v gemini >/dev/null 2>&1; then
    yellow "gemini CLI detected but auto-wiring is not implemented"
    dim "the bridge scripts call gemini -p directly, which works out of the box"
    dim "for trigger-aware behavior, add a note about the bridge to your Gemini config manually"
else
    yellow "gemini CLI not detected — skipping (optional)"
    dim "install Gemini later: npm install -g @google/gemini-cli"
fi

# 5. Verification
header "5. Verification"
"$SKILL_DIR/scripts/doctor.sh"
