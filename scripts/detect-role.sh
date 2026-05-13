#!/usr/bin/env bash
# detect-role.sh — best-effort detection of the current AI's role
#
# Prints one of: claude, codex, gemini, unknown
# Override with: AI_COLLAB_ROLE=<role>

set -euo pipefail

if [ -n "${AI_COLLAB_ROLE:-}" ]; then
    echo "$AI_COLLAB_ROLE"
    exit 0
fi

# Claude Code sets CLAUDECODE=1 in its shell environment
if [ "${CLAUDECODE:-}" = "1" ]; then
    echo "claude"
    exit 0
fi

# Codex CLI env hints (these vary by version — add more as you encounter them)
if [ -n "${CODEX_SESSION:-}" ] || [ -n "${CODEX_HOME:-}" ]; then
    echo "codex"
    exit 0
fi

# Gemini hint (loose — only matches if Anthropic env is absent)
if [ -n "${GEMINI_API_KEY:-}" ] && [ -z "${ANTHROPIC_API_KEY:-}" ]; then
    echo "gemini"
    exit 0
fi

echo "unknown"
