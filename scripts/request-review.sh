#!/usr/bin/env bash
# request-review.sh — hand a review packet to another AI's CLI
#
# Usage:
#   ./request-review.sh <target> <packet-path>
#
# Targets supported out of the box: claude, codex, gemini, hermes
# Add new ones by editing the case block below.
#
# Override CLI commands with env vars:
#   AI_COLLAB_CLAUDE_CMD   (default: "claude -p --strict-mcp-config --mcp-config {\"mcpServers\":{}} --no-session-persistence")
#   AI_COLLAB_CODEX_CMD    (default: "codex exec")
#   AI_COLLAB_GEMINI_CMD   (default: "gemini -p")
#   AI_COLLAB_HERMES_CMD   (default: "hermes chat -Q --source ai-collab-bridge -q")
#   AI_COLLAB_HERMES_SSH_HOST
#     Optional SSH host that runs Hermes remotely. Example: "pi".
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
  target:       claude | codex | gemini | hermes | <custom>
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

EMPTY_MCP_CONFIG_JSON='{"mcpServers":{}}'
CLAUDE_PROBE_CMD="${AI_COLLAB_CLAUDE_CMD:-claude -p}"
CLAUDE_DEFAULT_CMD=(
    claude
    -p
    --strict-mcp-config
    --mcp-config
    "$EMPTY_MCP_CONFIG_JSON"
    --no-session-persistence
)
# codex default uses `exec review` with --ignore-user-config so it does not
# try to bootstrap MCP servers (which auth-fail in non-interactive contexts
# and previously hung dispatches for 10+ minutes). --ephemeral skips session
# persistence we do not need for one-shot reviews.
CODEX_CMD="${AI_COLLAB_CODEX_CMD:-codex exec review --ignore-user-config --ephemeral --skip-git-repo-check}"
GEMINI_CMD="${AI_COLLAB_GEMINI_CMD:-gemini -p}"
HERMES_CMD="${AI_COLLAB_HERMES_CMD:-hermes chat -Q --source ai-collab-bridge -q}"
HERMES_SSH_HOST="${AI_COLLAB_HERMES_SSH_HOST:-}"

# probe_cli <full-cmd> <install-hint>
# Runs `<binary> --version` (where <binary> is the first whitespace-delimited
# word of <full-cmd>) and inspects the output. The full command is passed so
# that AI_COLLAB_<NAME>_CMD overrides are honored — e.g., if the user points
# the codex target at a different binary because the global one is broken,
# the probe checks that overridden binary, not hardcoded `codex`.
#
# If the probe errors out in a way that signals a known-broken install
# (missing vendor binary, ENOENT spawn, etc.), prints a friendly diagnosis
# and exits non-zero. Otherwise returns 0.
probe_cli() {
    local full_cmd="$1"
    local hint="$2"
    local name="${full_cmd%% *}"  # first word — handles "codex exec" → "codex"

    # Wrapped commands like "env PATH=... codex exec" or "timeout 60 codex exec"
    # would have the wrapper extracted as $name, which is not the binary we
    # actually want to probe. Skip the probe in that case — the user clearly
    # knows what they're doing and can use AI_COLLAB_SKIP_PROBE=1 anyway.
    case "$name" in
        env|nice|nohup|timeout|sudo|ssh|stdbuf|ionice|chrt|setsid)
            return 0
            ;;
    esac

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
        case "$probe_out" in
        *ENOENT*codex*vendor*|*spawn*codex*ENOENT*)
            cat <<EOF >&2
Error: '$name' CLI is installed but its platform-specific vendor binary is missing.

This is a known issue with @openai/codex on some platforms (npm sometimes
skips the optional native dependency). Fix:

  npm uninstall -g @openai/codex && npm install -g @openai/codex

Then re-run this command. Or, if you have a working codex binary elsewhere,
override with: AI_COLLAB_CODEX_CMD="/path/to/working/codex exec"
EOF
            exit 3
            ;;
        *)
            ;;
        esac

        cat <<EOF >&2
Error: '$name --version' failed:

$probe_out

The CLI is on your PATH but appears broken. Try reinstalling, or point at
a working binary via AI_COLLAB_$(echo "$name" | tr '[:lower:]' '[:upper:]')_CMD,
or skip this check with AI_COLLAB_SKIP_PROBE=1.
EOF
        exit 4
    }
    return 0
}

looks_like_auth_error() {
    case "$1" in
    *"Invalid authentication credentials"*|*"authentication_error"*|*"Failed to authenticate"*)
        return 0
        ;;
    *)
        return 1
        ;;
    esac
}

auth_failure_hint() {
    local name="$1"

    case "$name" in
        claude)
            # Intentionally expand EMPTY_MCP_CONFIG_JSON so the remediation
            # command is copy-pasteable in common shells.
            cat <<EOF >&2

Authentication failed for Claude CLI.

The CLI is installed, but the saved Claude credential was rejected by the
server. Refresh the official Claude Code session:

  claude auth login --claudeai

Then verify with:

  claude -p --strict-mcp-config --mcp-config '$EMPTY_MCP_CONFIG_JSON' --no-session-persistence "Reply with OK only."

EOF
            ;;
        *)
            cat <<EOF >&2

Authentication failed for '$name'. Refresh that CLI's saved credentials and
retry the review request.

EOF
            ;;
    esac
}

run_claude_review() {
    local stdout_file
    local stderr_file
    local claude_stdout
    local claude_stderr
    local claude_combined
    local claude_status

    stdout_file=$(mktemp -t ai-collab-claude.stdout.XXXXXX)
    stderr_file=$(mktemp -t ai-collab-claude.stderr.XXXXXX)

    set +e
    if [ -n "${AI_COLLAB_CLAUDE_CMD:-}" ]; then
        # shellcheck disable=SC2086
        $AI_COLLAB_CLAUDE_CMD "$PROMPT" >"$stdout_file" 2>"$stderr_file"
    else
        "${CLAUDE_DEFAULT_CMD[@]}" "$PROMPT" >"$stdout_file" 2>"$stderr_file"
    fi
    claude_status=$?
    set -e

    claude_stdout=$(cat "$stdout_file")
    claude_stderr=$(cat "$stderr_file")
    rm -f "$stdout_file" "$stderr_file"

    if [ "$claude_status" -ne 0 ]; then
        claude_combined="$claude_stderr
$claude_stdout"
        if looks_like_auth_error "$claude_combined"; then
            auth_failure_hint claude
        fi
        printf '%s\n' "$claude_combined" >&2
        exit "$claude_status"
    fi

    if [ -n "$claude_stderr" ]; then
        printf '%s\n' "$claude_stderr" >&2
    fi
    printf '%s\n' "$claude_stdout"
}

case "$TARGET" in
    claude)
        probe_cli "$CLAUDE_PROBE_CMD" "https://docs.claude.com/claude-code"
        run_claude_review
        ;;
    codex)
        probe_cli "$CODEX_CMD" "npm install -g @openai/codex"
        # codex exec / exec review print a human-readable session log to
        # stdout in addition to the final agent message. Use -o to capture
        # the clean final message and discard the session noise, so callers
        # get review-only output (matching how `claude -p` behaves).
        # If the user overrode AI_COLLAB_CODEX_CMD with something that does
        # NOT accept -o (e.g., they switched back to plain `codex exec`),
        # this still works because -o is a valid flag on both subcommands.
        CODEX_TMP=$(mktemp -t ai-collab-codex.XXXXXX)
        trap 'rm -f "$CODEX_TMP"' EXIT
        # shellcheck disable=SC2086
        $CODEX_CMD -o "$CODEX_TMP" "$PROMPT" >/dev/null
        cat "$CODEX_TMP"
        ;;
    gemini)
        probe_cli "$GEMINI_CMD" "npm install -g @google/gemini-cli"
        # shellcheck disable=SC2086
        $GEMINI_CMD "$PROMPT"
        ;;
    hermes)
        if [ -n "$HERMES_SSH_HOST" ]; then
            if ! command -v ssh >/dev/null 2>&1; then
                echo "Error: 'ssh' CLI not found in PATH." >&2
                exit 2
            fi
            printf '%s' "$PROMPT" | ssh "$HERMES_SSH_HOST" 'python3 -c '"'"'
import subprocess
import sys

prompt = sys.stdin.read()
raise SystemExit(subprocess.call([
    "hermes",
    "chat",
    "-Q",
    "--source",
    "ai-collab-bridge",
    "-q",
    prompt,
]))
'"'"''
        else
            probe_cli "$HERMES_CMD" "Install Hermes Agent and ensure 'hermes' is on PATH"
            # shellcheck disable=SC2086
            $HERMES_CMD "$PROMPT"
        fi
        ;;
    *)
        echo "Error: unknown target '$TARGET'" >&2
        echo "Supported: claude, codex, gemini, hermes" >&2
        echo "To add another, edit this script and append a case." >&2
        exit 5
        ;;
esac
