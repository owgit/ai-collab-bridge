# Handoff protocol — formal spec

This file is the canonical reference for what a handoff looks like. If you're building tooling around the bridge, this is the contract you implement against.

## Packet format

A packet is a markdown document with these sections, in order:

````markdown
# Review packet

## Summary
<1-3 sentences describing the change>

## Specific focus questions
<bullet list or "(none — open review)">

## Changed files
```
<output of `git diff --stat <base>`>
```

## Diff
```diff
<output of `git diff <base>`>
```
````

The `scripts/stage-packet.sh` script produces exactly this format. Tooling that produces packets differently should still match this shape.

## Response format

A response is a markdown document with these sections:

```markdown
# Review response

## Verdict
APPROVE | CONCERNS | BLOCK

## Reason
<1-2 sentences>

## Findings

### Bugs
- `<path/to/file>:<line>` — Description.

### Security
- `<path/to/file>:<line>` — Description.

### Quality / style
- `<path/to/file>:<line>` — Description.

### Suggestions (non-blocking)
- Description.

## What I checked
- <list>

## What I did NOT check
- <list>
```

Sections with no items may be omitted.

## Verdicts

| Verdict | Meaning | Implementer action |
|---------|---------|--------------------|
| `APPROVE` | Work is good as-is | Ship |
| `CONCERNS` | There are issues but none are blocking | Triage; ship if you want, after considering each finding |
| `BLOCK` | At least one finding is a hard stop | Fix and re-request review |

There are no other valid verdicts. Don't invent new ones — tooling depends on the three above.

## Re-requests

After material changes, stage a new packet and call the reviewer again. Each round is independent — the reviewer does not assume context from prior rounds unless the packet includes it.

If you want to give the reviewer context about a prior round, include it in the `Summary` or `Specific focus questions` section. For example:

```
## Summary
Round 2 — addressed the SQL injection and the empty-array check from round 1.
Still using non-parameterized query for the audit log; question below.

## Specific focus questions
- Is it OK that the audit-log insert uses string interpolation? The values come from a server-controlled enum.
```

## CLI conventions

| Script | Behavior |
|--------|----------|
| `scripts/stage-packet.sh [base-ref]` | Produces a packet on stdout. Reads `SUMMARY` and `QUESTIONS` from env. |
| `scripts/request-review.sh <target> <packet-path>` | Invokes the target AI's CLI with the packet wrapped in `templates/review-request.md`. Returns the response on stdout. |
| `scripts/detect-role.sh` | Returns `claude`, `codex`, `gemini`, or `unknown`. Best-effort. |

## Environment variables

| Variable | Purpose |
|----------|---------|
| `AI_COLLAB_ROLE` | Force a role for `detect-role.sh` (`claude` / `codex` / etc.) |
| `AI_COLLAB_CLAUDE_CMD` | Override the Claude invocation (default: `claude -p`) |
| `AI_COLLAB_CODEX_CMD` | Override the Codex invocation (default: `codex exec`) |
| `AI_COLLAB_GEMINI_CMD` | Override the Gemini invocation (default: `gemini -p`) |

## Honesty contract

The protocol does not — cannot — enforce honesty. It assumes both sides participate in good faith:

- The implementer accurately describes the change in the summary.
- The reviewer truthfully reports verdict and findings.
- Both sides honestly disclose what was and was not checked.

If any side is dishonest, the protocol degrades to noise. But in good-faith use, it's enough.
