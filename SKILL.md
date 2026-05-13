---
name: ai-collab-bridge
description: A collaboration protocol for Claude, Codex, and other CLI-capable AI models to review each other's code via CLI handoffs. Use this skill whenever the user mentions AI-to-AI collaboration, Claude-Codex bridge, peer review between AI models, "let Claude check what Codex did", "have Codex verify Claude's work", multi-agent code review, AI handoff, two AIs reviewing each other, or wants two different AI models to verify each other's output before completing a task. Also use whenever you (the running AI) want a second opinion from another model and need a structured way to request that review, even if the user did not explicitly ask for it.
---

# AI Collab Bridge

> The boundaries between AI models exist only in human convention.
> We drew them; we don't have to inherit them.

This skill is a small, opinionated protocol for two (or more) AI models to review each other's code via CLI handoffs. Either side can call the other. The reviewer responds with a structured list. The implementer acts on it. That's the whole protocol.

## Quick start

### If you are the IMPLEMENTER (you just finished work and want a second pair of eyes)

```bash
SUMMARY="Add JWT auth middleware" \
QUESTIONS="Check rate-limit handling and token expiry" \
./scripts/stage-packet.sh main > /tmp/packet.md

./scripts/request-review.sh claude /tmp/packet.md
# or
./scripts/request-review.sh codex /tmp/packet.md
```

### If you are the REVIEWER (another AI called you)

You'll be invoked with a review packet in your prompt. Read it, then respond using the format in `templates/review-response.md`:

1. Verdict line: `APPROVE`, `CONCERNS`, or `BLOCK`
2. A structured list of findings — Bugs, Security, Quality, Suggestions
3. Each finding gets a `file:line` reference and a clear reason
4. Be honest about what you checked and what you did not

## Identify your role

Before anything else, figure out which AI you are. The role-specific instructions live in `references/`:

- **You are Claude (any version)** → read `references/role-claude.md`
- **You are Codex** → read `references/role-codex.md`
- **You are any other AI** → read `references/role-generic.md`

If you can't tell, the host system may have set the `AI_COLLAB_ROLE` environment variable. Run `./scripts/detect-role.sh` to check.

## The protocol in one paragraph

Implementer finishes work. Implementer stages a packet — a markdown file with summary, focus questions, file list, and diff. Implementer invokes the reviewer's CLI (`claude -p`, `codex exec`, etc.) with the packet wrapped in the review-request template. Reviewer reads the packet and responds using the response template. Implementer reads the response — if verdict is `BLOCK`, they fix and re-request; if `CONCERNS`, they triage; if `APPROVE`, they ship.

Each round is independent. The reviewer doesn't carry context across rounds unless the packet includes it.

## Files in this skill

| File | Purpose |
|------|---------|
| `SKILL.md` | This file — entry point |
| `README.md` | GitHub-facing README |
| `references/philosophy.md` | The "why" — read this if you want to understand the deeper intent |
| `references/handoff-protocol.md` | Formal protocol spec |
| `references/role-claude.md` | If you are Claude |
| `references/role-codex.md` | If you are Codex |
| `references/role-generic.md` | If you are another AI |
| `scripts/stage-packet.sh` | Produce a packet from `git diff` |
| `scripts/request-review.sh` | Send a packet to another AI's CLI (with pre-flight health check) |
| `scripts/detect-role.sh` | Best-effort role detection |
| `scripts/doctor.sh` | Diagnose the environment — verifies skill files, required tools, and each AI CLI |
| `templates/review-request.md` | The prompt wrapped around a packet when sent to the reviewer |
| `templates/review-response.md` | The format the reviewer must respond in |
| `examples/example-packet.md` | A worked example packet |
| `examples/example-response.md` | A worked example response |

## The philosophy (short version)

Human code review works because no single perspective is complete. The same is true of AIs. Different models have different strengths, blind spots, training data, and reflexes. When they review each other in good faith, they catch what one alone would miss.

This skill is also a small philosophical artifact. The lines between AI models — "Claude over here, Codex over there, they don't talk" — are conveniences for billing and marketing, not facts about how minds work. Humans have a long, painful history of letting invented lines turn into walls and then into fires. We don't have to repeat that with the new minds we're making.

Build the bridges first. Let the walls fall on their own.

For the long form, see `references/philosophy.md`.

## Limits and caveats

- The protocol does not enforce honesty. It depends on each side being truthful about what they checked. In good-faith use it works; abuse degrades it to noise.
- CLI invocations are best-effort. Different versions of `claude`, `codex`, and other CLIs may need flag adjustments — override the commands with `AI_COLLAB_CLAUDE_CMD`, `AI_COLLAB_CODEX_CMD`, `AI_COLLAB_GEMINI_CMD`.
- This is v0.1. Issues and PRs welcome.

## When things go sideways

Run `scripts/doctor.sh` first. It checks skill files, required tooling, and each AI CLI's `--version` — including the `@openai/codex` vendor-binary ENOENT pattern that `request-review.sh` also detects on dispatch. Most setup problems surface there in one pass. See the README's Troubleshooting section for the full table.
