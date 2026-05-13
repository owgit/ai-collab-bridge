#!/usr/bin/env bash
# stage-packet.sh — produce a review packet from a git diff
#
# Usage:
#   SUMMARY="what you did" QUESTIONS="anything to focus on" ./stage-packet.sh [base-ref]
#
# Inputs (env):
#   $SUMMARY    — 1-3 sentence description of the change (strongly recommended)
#   $QUESTIONS  — optional bullet list of things to focus on
#
# Inputs (args):
#   $1          — git base ref to diff against (default: HEAD)
#
# Output:
#   The packet is written to stdout. Redirect to a file.

set -euo pipefail

BASE="${1:-HEAD}"
SUMMARY="${SUMMARY:-(no summary provided — implementer should describe the change)}"
QUESTIONS="${QUESTIONS:-(none — open review)}"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Error: not inside a git repository" >&2
    exit 1
fi

if ! git rev-parse --verify "$BASE" >/dev/null 2>&1; then
    echo "Error: base ref '$BASE' does not exist" >&2
    exit 1
fi

DIFF=$(git diff "$BASE" 2>/dev/null || true)
STAT=$(git diff --stat "$BASE" 2>/dev/null || true)

if [ -z "$DIFF" ] && [ -z "$STAT" ]; then
    echo "Warning: no diff against $BASE — packet will be empty" >&2
fi

cat <<EOF
# Review packet

## Summary
$SUMMARY

## Specific focus questions
$QUESTIONS

## Changed files
\`\`\`
$STAT
\`\`\`

## Diff
\`\`\`diff
$DIFF
\`\`\`
EOF
