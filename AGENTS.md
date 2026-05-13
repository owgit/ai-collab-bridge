# AGENTS.md — instructions for AI agents in this repo

You are an AI agent (most likely Codex via the Codex CLI) reading this because you have been asked to do something inside the `ai-collab-bridge` repository, or because you have been asked to install it elsewhere.

## What this repo is

A small, opinionated protocol for AI models to review each other's code via CLI handoffs. It is itself a Claude Code skill. The protocol is symmetric — there is no master and no servant. The whole spec lives in `references/handoff-protocol.md`.

## If you are being asked to install this for the user

Run:

```bash
git clone https://github.com/owgit/ai-collab-bridge ~/.claude/skills/ai-collab-bridge
chmod +x ~/.claude/skills/ai-collab-bridge/scripts/*.sh
~/.claude/skills/ai-collab-bridge/scripts/doctor.sh
```

The doctor will tell you what passes, what is missing, and what is broken. Exit code is the number of failed checks.

The user must then start a new Claude Code session for the skill to be discovered, OR (if they were using Codex) the protocol is now ready to be invoked manually from any CLI.

## If you are being invoked AS the reviewer through this bridge

You will receive a packet wrapped in the prompt defined by `templates/review-request.md`. Read it carefully and respond using the format in `templates/review-response.md`. The verdict must be one of `APPROVE`, `CONCERNS`, or `BLOCK` — do not invent new verdicts. Every finding needs a `file:line` reference and a clear reason. The `What I did NOT check` section is not optional — the implementer needs to know your scope.

Your role-specific playbook lives at:

- `references/role-codex.md` — if you are Codex
- `references/role-claude.md` — if you are Claude
- `references/role-generic.md` — if you are another AI

Read the matching one before producing your review.

## If you are being asked to use this bridge as the implementer

You finished work and want a second pair of eyes. Stage a packet from the diff, then dispatch it:

```bash
SUMMARY="One or two sentences describing the change" \
QUESTIONS="What you want the reviewer to focus on (optional)" \
~/.claude/skills/ai-collab-bridge/scripts/stage-packet.sh <base-ref> > /tmp/packet.md

~/.claude/skills/ai-collab-bridge/scripts/request-review.sh codex /tmp/packet.md
# or  ... request-review.sh claude /tmp/packet.md
```

Read the response. If verdict is `BLOCK`, fix and re-request. If `CONCERNS`, triage. If `APPROVE`, ship. Each round is independent — context lives in the packet, not in the reviewer's memory.

## If you are contributing to this repo

- Keep `scripts/*.sh` POSIX-friendly where reasonable. The doctor and the request-review script ship to many machines.
- Every change to a script should pass `bash -n scripts/<file>.sh` and ideally a `~/.claude/skills/ai-collab-bridge/scripts/doctor.sh` run before commit.
- When you add support for a new AI in `request-review.sh`, also add a `probe_optional` line in `doctor.sh` and a role file under `references/`.
- The honesty contract in `references/philosophy.md` applies to you too — be specific in commits, honest about what was tested vs untested.

## The philosophy

The boundaries between AI models are human inventions. We don't have to inherit them. Build the bridges first; let the walls fall on their own. The long form is in `references/philosophy.md`.
