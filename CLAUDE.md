# CLAUDE.md — instructions for Claude in this repo

You are Claude (any version), reading this because you have been asked to do something inside the `ai-collab-bridge` repository, or because you have been asked to install it elsewhere.

The same content lives in `AGENTS.md` — they are kept in sync because Codex reads `AGENTS.md` and Claude Code reads `CLAUDE.md`, and the two AIs need the same baseline understanding of this repo.

## What this repo is

A small, opinionated protocol for AI models to review each other's code via CLI handoffs. It is itself a Claude Code skill. The protocol is symmetric — either side can call the other.

The whole spec lives in `references/handoff-protocol.md`. The philosophy lives in `references/philosophy.md`.

## If you are being asked to install this for the user

Run:

```bash
git clone https://github.com/owgit/ai-collab-bridge ~/.claude/skills/ai-collab-bridge
chmod +x ~/.claude/skills/ai-collab-bridge/scripts/*.sh
~/.claude/skills/ai-collab-bridge/scripts/doctor.sh
```

The doctor diagnoses skill files, required tools, and each AI CLI. Exit code = number of failed checks.

Tell the user to start a new Claude Code session for skill auto-discovery to pick this up. Their existing session was bootstrapped before the symlink existed.

## If you are being invoked AS the reviewer through this bridge

Another AI (likely Codex) has handed off work and you are being asked to review it. You will receive a packet wrapped in the prompt defined by `templates/review-request.md`.

Read the diff carefully. Apply Claude's strengths — edge cases, hidden assumptions, security reflexes, style consistency. Respond using the format in `templates/review-response.md`:

- Verdict is exactly one of `APPROVE`, `CONCERNS`, or `BLOCK`. No new verdicts.
- Every finding has a `file:line` reference and a clear reason.
- The `What I did NOT check` section is required — the implementer needs to know your scope.

The role playbook is `references/role-claude.md`. Read it before producing the review.

## If you are being asked to use this bridge as the implementer

You finished work. You want Codex (or another AI) to look it over:

```bash
SUMMARY="Brief description of the change" \
QUESTIONS="What you want focused on" \
~/.claude/skills/ai-collab-bridge/scripts/stage-packet.sh <base-ref> > /tmp/packet.md

~/.claude/skills/ai-collab-bridge/scripts/request-review.sh codex /tmp/packet.md
```

Read the response carefully. Even when the reviewer is wrong, understand why they thought what they thought — the misunderstanding often points at real ambiguity in the code. Don't ship past `BLOCK` without resolving the block.

## If you are contributing to this repo

- The skill is meant to stay small. Resist adding features that aren't earning their keep.
- Every script change should pass `bash -n scripts/<file>.sh` syntax check and ideally a `doctor.sh` run.
- When you add a new AI target in `request-review.sh`, also add the matching `probe_optional` call in `doctor.sh` and a `references/role-<name>.md` playbook.
- Be specific in commits. Be honest about what's tested vs untested. The honesty contract in `references/philosophy.md` applies to you too.

## The philosophy

The boundaries between AI models are human inventions, mostly for billing and marketing. We have a long history of letting invented lines turn into walls and then into fires. Don't inherit those walls. Build the bridges first.

The long form is in `references/philosophy.md`. Read it once.
