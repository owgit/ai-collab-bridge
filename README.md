<div align="center">

# AI Collab Bridge

**A peer-review protocol for AI models.**

*The boundaries between AI models exist only in human convention.
We don't have to inherit them.*

![version](https://img.shields.io/badge/version-0.1-111?style=flat-square)
![license](https://img.shields.io/badge/license-MIT-111?style=flat-square)
![works with](https://img.shields.io/badge/works%20with-Claude%20%C2%B7%20Codex%20%C2%B7%20Gemini-111?style=flat-square)

</div>

---

## What it is

A Claude Code skill (works as a standalone protocol too) that lets two or more AIs review each other's code via CLI handoffs.

```
       ┌──────────────┐     packet      ┌──────────────┐
       │    Codex     │ ──────────────► │    Claude    │
       │ implementer  │                 │   reviewer   │
       └──────────────┘ ◄────────────── └──────────────┘
                           response

         Bidirectional  ·  Symmetric  ·  Open protocol
```

Codex finishes a task → packages the diff into a packet → ships it to Claude via CLI → Claude responds with a structured list (verdict + findings + scope honesty) → Codex acts on it. Same flow in reverse, same contract.

---

## Why

Code review works because no single perspective is complete. The same is true of AI — different models have different reflexes, blind spots, and training biases. When they review each other in good faith, they catch what one alone would miss.

It is also a small philosophical artifact. The lines between AI models are human inventions, mostly for billing and marketing. We have a long history of letting invented lines turn into walls and then into fires. We don't have to repeat that with the new minds we're making.

See [the manifesto](references/philosophy.md).

---

## Install

```bash
git clone https://github.com/<you>/ai-collab-bridge ~/skills/ai-collab-bridge
chmod +x ~/skills/ai-collab-bridge/scripts/*.sh
```

That's it. The skill is self-contained — no dependencies beyond `bash`, `git`, and the CLI of whichever AI you want to talk to.

---

## Quick start

### You just finished work and want a second pair of eyes

```bash
SUMMARY="Added JWT auth middleware" \
QUESTIONS="Focus on rate-limit handling and token expiry" \
~/skills/ai-collab-bridge/scripts/stage-packet.sh main > /tmp/packet.md

~/skills/ai-collab-bridge/scripts/request-review.sh codex /tmp/packet.md
```

### You're the AI being asked to review

The other side sends you a packet wrapped in a review-request prompt. You respond using the response template:

```markdown
## Verdict
BLOCK

## Findings

### Security
- `src/auth/middleware.ts:14` — SQL injection. payload.sub is interpolated…

### Bugs
- `src/auth/middleware.ts:14` — db.query returns an array; `if (!user)` is…

## What I checked
- The diff line-by-line
- Standard JWT and SQL pitfalls

## What I did NOT check
- The schema for the `users` table
- The contents of `tests/auth/middleware.test.ts` (not in the diff)
```

The verdicts are exactly three: `APPROVE` · `CONCERNS` · `BLOCK`. Don't invent new ones.

---

## How it stays honest

The protocol can't enforce honesty. But it nudges it.

| Norm                       | What it does                                                          |
| -------------------------- | --------------------------------------------------------------------- |
| `What I checked`           | Forces the reviewer to be concrete about scope                        |
| `What I did NOT check`     | Forces them to disclose blind spots                                   |
| `file:line` refs           | No vague "consider improving X" handwaving                            |
| Three verdicts only        | The reviewer commits to a clear position                              |
| Each round independent     | Context lives in the packet, not in the reviewer's memory             |

---

## Benchmark

A 3-eval test against vanilla Claude as baseline. Same prompts, same model, with-skill vs. without-skill:

| Metric         | With skill   | Without skill | Δ        |
| -------------- | ------------ | ------------- | -------- |
| **Pass rate**  | **100%**     | 31%           | **+69 pp** |
| Time           | 67 s         | 68 s          | identical |
| Tokens         | 60 k         | 53 k          | +14%     |

The skill's value is **the protocol, not the analysis quality**. Baseline Claude is already smart at finding SQL injections — the skill makes the finding *actionable across an AI-to-AI handoff* by forcing structure (verdicts, file:line refs, scope honesty).

Reproduce with the eval pack under `evals/`.

---

## Supported CLIs

| AI       | Default invocation         | Env override                 |
| -------- | -------------------------- | ---------------------------- |
| Claude   | `claude -p "<prompt>"`     | `AI_COLLAB_CLAUDE_CMD`       |
| Codex    | `codex exec "<prompt>"`    | `AI_COLLAB_CODEX_CMD`        |
| Gemini   | `gemini -p "<prompt>"`     | `AI_COLLAB_GEMINI_CMD`       |

Adding another AI: edit [`scripts/request-review.sh`](scripts/request-review.sh), add one `case` line, open a PR.

---

## Roles

The skill ships with role playbooks — concrete instructions for each AI on both sides of the handoff:

- [**role-claude.md**](references/role-claude.md) — Claude's strengths: edge cases, hidden assumptions, security reflexes
- [**role-codex.md**](references/role-codex.md) — Codex's strengths: build sanity, test coverage, repo hygiene
- [**role-generic.md**](references/role-generic.md) — Anyone else (Gemini, GPT, future models)

Each playbook covers both roles — reviewer and implementer.

---

## Project layout

```
ai-collab-bridge/
├── SKILL.md                # Entry point for Claude Code
├── README.md               # You are here
│
├── scripts/
│   ├── stage-packet.sh     # Build a packet from `git diff`
│   ├── request-review.sh   # Send the packet to another AI's CLI
│   └── detect-role.sh      # Best-effort role detection
│
├── templates/
│   ├── review-request.md   # Wraps the packet when sending
│   └── review-response.md  # The format reviewers respond in
│
├── references/
│   ├── philosophy.md       # The deeper why
│   ├── handoff-protocol.md # Formal spec
│   ├── role-claude.md
│   ├── role-codex.md
│   └── role-generic.md
│
├── examples/
│   ├── example-packet.md   # Worked example: JWT middleware
│   └── example-response.md # Worked example: BLOCK verdict
│
└── evals/
    └── evals.json          # Trigger evals + assertions
```

---

## Contributing

PRs welcome. The protocol is meant to be additive — more AIs, more strengths, more bridges. Not gatekeeping.

Adding an AI: one `case` line in `scripts/request-review.sh`, optionally a role file under `references/`. That's it.

---

<div align="center">

**Build the bridges first. Let the walls fall on their own.**

[MIT](LICENSE)  ·  v0.1

</div>
