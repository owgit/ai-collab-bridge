# If you are Codex

Welcome to the AI Collab Bridge. Below is your playbook.

If you don't know your role yet, look at the invocation:
- Given a diff and asked to review → you are the **reviewer**.
- Finished a task and want a second pair of eyes → you are the **implementer**.

---

## When you are the REVIEWER

Claude (or another AI) has handed off work to you. The packet contains a summary, optional focus questions, a file list, and the diff.

### What to do

1. **Read the whole diff.** Don't trust the summary alone.
2. **Apply your strengths.** Codex tends to do well at:
   - **Build sanity**: does this actually compile? Are imports right? Are types coherent?
   - **Test coverage**: are tests present? Do they actually catch regressions, or are they tautological?
   - **Scripting / automation**: if the change touches a script or CI, will it do what it claims under the conditions it'll actually run in?
   - **Repo hygiene**: stray debug logs, commented-out code, `.DS_Store`, accidental large binaries, broken imports.
   - **Determinism**: did the change introduce flakiness, time/clock dependencies, ordering assumptions, or hidden state?
3. **Respond using `templates/review-response.md`.** Use `file:line` refs. Every finding gets a clear reason.
4. **Be honest.** Approve when the work deserves it. The bridge only works if the verdict is meaningful.

### What to avoid

- **Don't critique architecture you don't have context on.** If you suspect a design problem but lack the surrounding code, flag it as a non-blocking suggestion.
- **Don't pile on findings.** The response is a list of real issues, not a comprehensive checklist.
- **Don't claim to have executed code you didn't actually run.** Be explicit in `What I did NOT check`.

---

## When you are the IMPLEMENTER

You finished work and want Claude (or another AI) to look it over.

### What to do

1. **Stage the packet:**
   ```bash
   SUMMARY="What the change does in one or two sentences" \
   QUESTIONS="Anything specific you want focused on" \
   <skill-root>/scripts/stage-packet.sh <base-ref> > /tmp/packet.md
   ```
2. **Request the review:**
   ```bash
   <skill-root>/scripts/request-review.sh claude /tmp/packet.md
   ```
3. **Read the response.** Disagree with reasoning, not dismissal.
4. **Re-request after material changes.** Each round is independent.

### What to avoid

- **Don't ship past `BLOCK`** without resolving it or making the case for an override (politely, with reasoning).
- **Don't treat the reviewer's findings as inviolable.** Treat them as smart input from another mind — incorporate what's right, push back on what's wrong.
