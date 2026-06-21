<div align="center">

# AI Collab Bridge

**A peer-review protocol for AI models.**

*The boundaries between AI models exist only in human convention.
We don't have to inherit them.*

![version](https://img.shields.io/badge/version-0.1-111?style=flat-square)
![license](https://img.shields.io/badge/license-MIT-111?style=flat-square)
![works with](https://img.shields.io/badge/works%20with-Claude%20%C2%B7%20Codex%20%C2%B7%20Gemini%20%C2%B7%20Hermes-111?style=flat-square)

<sub>
<a href="https://uygarduzgun.com">site</a>&nbsp;·&nbsp;
<a href="https://github.com/owgit">github</a>&nbsp;·&nbsp;
<a href="https://x.com/uygarofficial">x</a>&nbsp;·&nbsp;
<a href="https://www.linkedin.com/in/uygar-duzgun-b6b472165/">linkedin</a>&nbsp;·&nbsp;
<a href="https://www.buymeacoffee.com/uygarduzgun">buy me a coffee</a>
</sub>

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

## For AI agents reading this

If you are an AI agent (Claude, Codex, Gemini, other) and the user asked you to install or use this skill, jump to [`AGENTS.md`](AGENTS.md) (Codex convention) or [`CLAUDE.md`](CLAUDE.md) (Claude Code convention). Both contain the same content and are kept in sync — each ecosystem reads its own conventional file from the repo root.

Short version: clone into `~/.claude/skills/ai-collab-bridge`, run `scripts/doctor.sh`, then either invoke this skill as a reviewer (read `references/role-<your-name>.md` first) or as an implementer (use `scripts/stage-packet.sh` + `scripts/request-review.sh`). Verdicts are exactly three — `APPROVE`, `CONCERNS`, `BLOCK` — and every finding needs a `file:line` reference. The `What I did NOT check` section is required, not optional.

---

## Install

Two commands. The installer wires the skill into every AI CLI it can find on your machine (Claude Code, Codex, Gemini).

```bash
git clone https://github.com/owgit/ai-collab-bridge ~/.claude/skills/ai-collab-bridge
~/.claude/skills/ai-collab-bridge/install.sh
```

What `install.sh` does — all steps are idempotent so it is safe to re-run:

1. `chmod +x` every script.
2. **Claude Code:** symlinks the skill into `~/.claude/skills/` so it auto-discovers on next session.
3. **Codex CLI:** appends an `ai-collab-bridge` section to `~/.codex/AGENTS.md` and installs the named subagent at `~/.codex/agents/ai-collab-bridge.toml` so Codex sees it in every session.
4. **Gemini CLI:** detected and called via `gemini -p` at runtime; no global-config hook yet (Gemini has no single canonical instructions file at time of writing).
5. Runs `scripts/doctor.sh` for final verification.

The skill itself has no dependencies beyond `bash`, `git`, and the CLI of whichever AI you want to talk to. Remote Hermes handoffs additionally require `ssh`. The installer just teaches each AI where to find it.

### Manual install (if you prefer)

```bash
git clone https://github.com/owgit/ai-collab-bridge ~/.claude/skills/ai-collab-bridge
chmod +x ~/.claude/skills/ai-collab-bridge/scripts/*.sh
~/.claude/skills/ai-collab-bridge/scripts/doctor.sh
```

This works for Claude Code (auto-discovery handles it). For Codex CLI to also know about the bridge, manually append the snippet in [`codex/ai-collab-bridge.toml`](codex/ai-collab-bridge.toml) to `~/.codex/agents/` and add a pointer to `~/.codex/AGENTS.md`.

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
| Claude   | isolated `claude -p` with empty MCP config and no session persistence | `AI_COLLAB_CLAUDE_CMD` |
| Codex    | `codex exec "<prompt>"`    | `AI_COLLAB_CODEX_CMD`        |
| Gemini   | `gemini -p "<prompt>"`     | `AI_COLLAB_GEMINI_CMD`       |
| Hermes   | `hermes chat -Q --source ai-collab-bridge -q "<prompt>"` | `AI_COLLAB_HERMES_CMD` |

Hermes can also run on another machine reachable over SSH:

```bash
AI_COLLAB_HERMES_SSH_HOST=pi \
  ~/skills/ai-collab-bridge/scripts/request-review.sh hermes /tmp/packet.md
```

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

## Troubleshooting

Run the built-in doctor first — it catches most setup issues in one pass:

```bash
~/skills/ai-collab-bridge/scripts/doctor.sh
```

| Symptom                                                                                   | Cause                                                                       | Fix                                                                                              |
| ----------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| `spawn .../codex-darwin-arm64/vendor/.../codex ENOENT`                                    | `@openai/codex` npm package skipped its native optional dependency          | `npm uninstall -g @openai/codex && npm install -g @openai/codex`                                 |
| `<cli> CLI not found in PATH`                                                             | CLI isn't installed or shell can't see it                                   | Install it; if just installed, restart your shell so PATH refreshes                              |
| Codex review hangs for minutes without responding                                         | Codex tried to bootstrap user-config MCP servers (Cloudflare, GitHub) that need their own auth and stalled out | The default `AI_COLLAB_CODEX_CMD` passes `--ignore-user-config` to skip MCP bootstrap. If you overrode the default, add that flag back |
| Codex prints `ERROR rmcp::transport::worker: ... AuthRequired`                            | User-config MCP servers failing to authenticate                             | Same as above — make sure `--ignore-user-config` is in your codex invocation                     |
| `request-review.sh` hangs forever                                                         | The target CLI is in interactive mode and waiting on TTY                    | Use the non-interactive subcommand: codex → `codex exec` or `codex exec review`; claude → `claude -p` |
| Claude prints `401 Invalid authentication credentials`                                     | Saved Claude Code auth is stale or rejected server-side                     | Run `claude auth login --claudeai`, then verify with `claude -p --strict-mcp-config --mcp-config '{"mcpServers":{}}' --no-session-persistence "Reply with OK only."` |
| Claude review hangs after auth succeeds                                                    | User/project MCP servers or hooks are slowing session startup               | The default Claude bridge command uses an empty MCP config and no session persistence. If you override `AI_COLLAB_CLAUDE_CMD`, keep equivalent isolation flags unless you intentionally need MCP tools |
| Want to skip the pre-flight `--version` probe                                             | You know what you're doing                                                  | `AI_COLLAB_SKIP_PROBE=1 ./scripts/request-review.sh …`                                          |
| Probe rejects an `env`-wrapped or `timeout`-wrapped override                               | Known wrappers (`env`, `nice`, `timeout`, `sudo`, `nohup`, …) cause the probe to skip itself rather than mis-probe the wrapper | This is intentional — the probe defers to you for wrapped commands. Combine with `AI_COLLAB_SKIP_PROBE=1` if you also want to silence other checks |
| `stage-packet.sh` says the diff is empty                                                  | You're not in a git repo, or the base ref has no diff against HEAD          | Run from your project root; pass an explicit base ref: `stage-packet.sh origin/main`             |

The doctor script returns a non-zero exit code equal to the number of failed checks, so you can wire it into CI or a pre-flight hook.

---

## Contributing

PRs welcome. The protocol is meant to be additive — more AIs, more strengths, more bridges. Not gatekeeping.

Adding an AI: one `case` line in `scripts/request-review.sh` (plus a matching `probe` in `scripts/doctor.sh`), optionally a role file under `references/`. That's it.

---

<div align="center">

**Build the bridges first. Let the walls fall on their own.**

<br/>

Made by **[Uygar Duzgun](https://uygarduzgun.com)** &nbsp;·&nbsp; [@uygarofficial](https://x.com/uygarofficial)

<a href="https://www.buymeacoffee.com/uygarduzgun"><img src="https://img.shields.io/badge/buy%20me%20a%20coffee-FFDD00?style=for-the-badge&logo=buymeacoffee&logoColor=000000" alt="Buy me a coffee" /></a>

<sub>
<a href="https://uygarduzgun.com">site</a>&nbsp;·&nbsp;
<a href="https://github.com/owgit">github</a>&nbsp;·&nbsp;
<a href="https://x.com/uygarofficial">x</a>&nbsp;·&nbsp;
<a href="https://www.linkedin.com/in/uygar-duzgun-b6b472165/">linkedin</a>
</sub>

[MIT](LICENSE)&nbsp;·&nbsp;v0.1

</div>
