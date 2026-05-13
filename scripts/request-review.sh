#!/usr/bin/env bash
# request-review.sh — hand a review packet to another AI's CLI
#
# Usage:
#   ./request-review.sh <target> <packet-path>
#
# Targets supported out of the box: claude, codex, gemini
# Add new ones by editing the case block below.
#
# Override CLI commands with env vars:
#   AI_COLLAB_CLAUDE_CMD   (default: "claude -p")
#   AI_COLLAB_CODEX_CMD    (default: "codex exec")
#   AI_COLLAB_GEMINI_CMD   (default: "gemini -p")
#
# Pre-flight: this script runs <cli> --version before dispatch and surfaces
# helpful errors for known broken-install patterns (e.g. @openai/codex's
# missing vendor binary on ARM macOS). Skip with AI_COLLAB_SKIP_PROBE=1.

set -euo pipefail

TARGET="${1:-}"
PACKET="${2:-}"

if [ -z "$TARGET" ] || [ -z "$PACKET" ]; then
    cat <<EOF >&2
Usage: $0 <target> <packet-path>
  target:       claude | codex | gemini | <custom>
  packet-path:  path to a markdown packet (see stage-packet.sh)
EOF
    exit 1
fi

if [ ! -f "$PACKET" ]; then
    echo "Error: packet not found at $PACKET" >&2
    exit 1
fi

SKILL_DIR=$(cd "$(dirname "$0")/.." && pwd)
TEMPLATE="$SKILL_DIR/templates/review-request.md"

if [ ! -f "$TEMPLATE" ]; then
    echo "Error: request template missing at $TEMPLATE" >&2
    exit 1
fi

PROMPT="$(cat "$TEMPLATE")

---

$(cat "$PACKET")"

CLAUDE_CMD="${AI_COLLAB_CLAUDE_CMD:-claude -p}"
CODEX_CMD="${AI_COLLAB_CODEX_CMD:-codex exec}"
GEMINI_CMD="${AI_COLLAB_GEMINI_CMD:-gemini -p}"

# probe_cli <name> <install-hint>
# Runs `<name> --version` and inspects the output. If it errors out in a way
# that signals a known-broken install (missing vendor binary, ENOENT spawn,
# etc.), prints a friendly diagnosis and exits non-zero. Otherwise returns 0.
probe_cli() {
    local name="$1"
    local hint="$2"

    if ! command -v "$name" >/dev/null 2>&1; then
        cat <<EOF >&2
Error: '$name' CLI not found in PATH.

Install: $hint
EOF
        exit 2
    fi

    if [ "${AI_COLLAB_SKIP_PROBE:-}" = "1" ]; then
        return 0
    fi

    # Capture both stdout and stderr; some CLIs print version to stderr.
    local probe_out
    probe_out=$("$name" --version 2>&1) || {
        # Detect the @openai/codex vendor-binary ENOENT pattern explicitly —
        # it's confusing because `which codex` succeeds but invoking it fails.
        if echo "$probe_out" | grep -qE "ENOENT.*codex.*vendor|spawn.*codex.*ENOENT"; then
            cat <<EOF >&2
Error: '$name' CLI is installed but its platform-specific vendor binary is missing.

This is a known issue with @openai/codex on some platforms (npm sometimes
skips the optional native dependency). Fix:

  npm uninstall -g @openai/codex && npm install -g @openai/codex

Then re-run this command.
EOF
            exit 3
        fi

        cat <<EOF >&2
Error: '$name --version' failed:

$probe_out

The CLI is on your PATH but appears broken. Try reinstalling, or override
the invocation via AI_COLLAB_$(echo "$name" | tr '[:lower:]' '[:upper:]')_CMD.
EOF
        exit 4
    }
    return 0
}

case "$TARGET" in
    claude)
        probe_cli claude "https://docs.claude.com/claude-code"
        # shellcheck disable=SC2086
        $CLAUDE_CMD "$PROMPT"
        ;;
    codex)
        probe_cli codex "npm install -g @openai/codex"
        # shellcheck disable=SC2086
        $CODEX_CMD "$PROMPT"
        ;;
    gemini)
        probe_cli gemini "npm install -g @google/gemini-cli"
        # shellcheck disable=SC2086
        $GEMINI_CMD "$PROMPT"
        ;;
    *)
        echo "Error: unknown target '$TARGET'" >&2
        echo "Supported: claude, codex, gemini" >&2
        echo "To add another, edit this script and append a case." >&2
        exit 5
        ;;
esac
