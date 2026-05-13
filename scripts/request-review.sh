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

case "$TARGET" in
    claude)
        if ! command -v claude >/dev/null 2>&1; then
            echo "Error: 'claude' CLI not found in PATH" >&2
            exit 2
        fi
        # shellcheck disable=SC2086
        $CLAUDE_CMD "$PROMPT"
        ;;
    codex)
        if ! command -v codex >/dev/null 2>&1; then
            echo "Error: 'codex' CLI not found in PATH" >&2
            exit 2
        fi
        # shellcheck disable=SC2086
        $CODEX_CMD "$PROMPT"
        ;;
    gemini)
        if ! command -v gemini >/dev/null 2>&1; then
            echo "Error: 'gemini' CLI not found in PATH" >&2
            exit 2
        fi
        # shellcheck disable=SC2086
        $GEMINI_CMD "$PROMPT"
        ;;
    *)
        echo "Error: unknown target '$TARGET'" >&2
        echo "Supported: claude, codex, gemini" >&2
        echo "To add another, edit this script and append a case." >&2
        exit 3
        ;;
esac
