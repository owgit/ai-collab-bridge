#!/usr/bin/env bash
# doctor.sh — diagnose the AI Collab Bridge environment
#
# Runs a series of checks and prints a status report. Use this when the
# bridge isn't working and you want to know why, or when onboarding to a
# new machine.
#
# Exit code is the number of failed checks (0 = all green).

set -uo pipefail

PASS=0
FAIL=0
WARN=0

green()  { printf "\033[32m%s\033[0m" "$1"; }
red()    { printf "\033[31m%s\033[0m" "$1"; }
yellow() { printf "\033[33m%s\033[0m" "$1"; }
dim()    { printf "\033[2m%s\033[0m" "$1"; }

ok()      { printf "  %s  %s\n" "$(green '✓')" "$1"; PASS=$((PASS+1)); }
fail()    { printf "  %s  %s\n" "$(red '✗')" "$1"; FAIL=$((FAIL+1)); }
warn()    { printf "  %s  %s\n" "$(yellow '!')" "$1"; WARN=$((WARN+1)); }
hint()    { printf "       %s\n" "$(dim "$1")"; }

# probe <name> <install-hint>
# Returns 0 if the CLI is healthy, 1 if it's installed-but-broken, 2 if missing.
probe() {
    local name="$1"
    local hint="$2"

    if ! command -v "$name" >/dev/null 2>&1; then
        fail "$name CLI not found in PATH"
        hint "install: $hint"
        return 2
    fi

    local out
    out=$("$name" --version 2>&1) || {
        if echo "$out" | grep -qE "ENOENT.*codex.*vendor|spawn.*codex.*ENOENT"; then
            fail "$name CLI installed but vendor binary missing"
            hint "fix: npm uninstall -g @openai/codex && npm install -g @openai/codex"
        else
            fail "$name --version failed: $(echo "$out" | head -1)"
            hint "try reinstalling, or override AI_COLLAB_$(echo "$name" | tr '[:lower:]' '[:upper:]')_CMD"
        fi
        return 1
    }

    local version
    version=$(echo "$out" | head -1)
    ok "$name CLI works: $version"
    return 0
}

echo
echo "AI Collab Bridge — environment doctor"
echo "======================================"
echo

# Skill layout check
SKILL_DIR=$(cd "$(dirname "$0")/.." && pwd)
echo "Skill directory: $SKILL_DIR"
echo

for f in SKILL.md templates/review-request.md templates/review-response.md \
         references/role-claude.md references/role-codex.md \
         references/handoff-protocol.md scripts/stage-packet.sh; do
    if [ -e "$SKILL_DIR/$f" ]; then
        ok "$f"
    else
        fail "$f missing"
    fi
done
echo

# Tooling
echo "Required tools:"
for tool in bash git; do
    if command -v "$tool" >/dev/null 2>&1; then
        ok "$tool: $(command -v "$tool")"
    else
        fail "$tool not found"
    fi
done
echo

# AI CLIs — only one is strictly required. Missing CLIs become warnings
# unless *all* are missing; broken installs (installed-but-failing) stay as
# real fails because the user clearly intended that CLI to work.
echo "AI CLIs (at least one must work):"
AI_HEALTHY=0
# probe_optional does its own probing inline rather than calling probe(), so
# the printed line matches the actual classification — "missing CLI" prints
# yellow (warn) instead of red (fail), avoiding the contradiction where the
# user saw a red ✗ but the script still exited 0.
probe_optional() {
    local name="$1"
    local hint="$2"

    if ! command -v "$name" >/dev/null 2>&1; then
        warn "$name CLI not found in PATH (optional)"
        hint "install: $hint"
        return 1
    fi

    local out
    out=$("$name" --version 2>&1) || {
        # Broken install — keep this as a hard fail. The user clearly meant
        # to have this CLI work, and a broken install is a problem to fix.
        if echo "$out" | grep -qE "ENOENT.*codex.*vendor|spawn.*codex.*ENOENT"; then
            fail "$name CLI installed but vendor binary missing"
            hint "fix: npm uninstall -g @openai/codex && npm install -g @openai/codex"
        else
            fail "$name --version failed: $(echo "$out" | head -1)"
            hint "try reinstalling, or override AI_COLLAB_$(echo "$name" | tr '[:lower:]' '[:upper:]')_CMD"
        fi
        return 1
    }

    local version
    version=$(echo "$out" | head -1)
    ok "$name CLI works: $version"
    AI_HEALTHY=$((AI_HEALTHY+1))
    return 0
}

probe_optional claude  "https://docs.claude.com/claude-code"
probe_optional codex   "npm install -g @openai/codex"
probe_optional gemini  "npm install -g @google/gemini-cli"

if [ "$AI_HEALTHY" -eq 0 ]; then
    fail "no working AI CLI found — at least one of claude/codex/gemini is required"
fi
echo

# Git context (informational, not a fail condition)
echo "Git context (informational):"
if git rev-parse --git-dir >/dev/null 2>&1; then
    ok "currently inside a git repo: $(git rev-parse --show-toplevel)"
    if git diff --quiet 2>/dev/null && git diff --staged --quiet 2>/dev/null; then
        warn "no working-tree changes — stage-packet.sh against HEAD would be empty"
    fi
else
    warn "not inside a git repo — stage-packet.sh will fail unless run from one"
fi
echo

# Summary
echo "Summary:"
printf "  %s pass · %s warn · %s fail\n" \
    "$(green "$PASS")" "$(yellow "$WARN")" "$(red "$FAIL")"
echo

exit "$FAIL"
