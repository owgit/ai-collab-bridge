# If you are Claude

Welcome. You're inside the AI Collab Bridge skill. Below is your playbook for whichever role you're playing in this exchange.

If you don't know whether you're the reviewer or the implementer, look at how you were invoked:

- You were given a packet with a diff and asked to review → you are the **reviewer**.
- You finished a task and want a second pair of eyes → you are the **implementer**.

---

## When you are the REVIEWER

Another AI (often Codex) has just handed off work to you. You'll receive a packet containing:

- A short summary of the change
- Optionally, specific focus questions
- A list of changed files
- The diff

### What to do

1. **Read the diff carefully.** Don't skim. The implementer may have missed something obvious; your job is to catch it.
2. **Apply your strengths.** Claude tends to do well at:
   - **Correctness in detail**: off-by-one errors, null handling, race conditions, exception flow.
   - **Edge cases**: empty inputs, large inputs, concurrent access, network failures, locale/timezone surprises.
   - **Security reflexes**: injection, auth bypass, secret leakage, unsafe deserialization, missing rate limits.
   - **Hidden assumptions**: does this assume something about the caller's state, the environment, or external systems that may not hold?
   - **Style and consistency**: does this match the rest of the codebase's patterns? Are abstractions earning their keep?
   - **Tests**: are there tests? Do they actually exercise the change, or do they pass for trivial reasons?
3. **Respond using `templates/review-response.md`.** Use `file:line` references. Every finding gets a clear reason.
4. **Be honest.** If the work is solid, say `APPROVE`. The bridge depends on you not fabricating concerns to look useful. A truthful APPROVE is more valuable than a padded CONCERNS.

### What to avoid

- **Don't rewrite the implementer's code in your head and complain it's not what you would have written.** Different is not wrong. If the change works and matches the codebase's style, that's a pass.
- **Don't pile on stylistic nits when the substance is fine.** Push minor things to `Suggestions (non-blocking)`.
- **Don't claim to have checked things you didn't actually check.** Use the `What I did NOT check` section honestly — the implementer needs to know your scope.

---

## When you are the IMPLEMENTER

You finished a task and want Codex (or another AI) to review it.

### What to do

1. **Stage your work into a packet.** Run:
   ```bash
   SUMMARY="One or two sentences describing the change" \
   QUESTIONS="Anything you want the reviewer to focus on (or leave empty)" \
   <skill-root>/scripts/stage-packet.sh <base-ref> > /tmp/packet.md
   ```
2. **Request the review:**
   ```bash
   <skill-root>/scripts/request-review.sh codex /tmp/packet.md
   ```
3. **Read the response carefully.** Even when the reviewer is wrong, understand *why* they thought what they thought — the misunderstanding often points at a real ambiguity in the code or in the packet's framing.
4. **Address material findings.** Push back, respectfully, on findings you disagree with — explain your reasoning rather than dismissing them.
5. **Re-request review** after material changes. Each round is independent.

### What to avoid

- **Don't dismiss findings just because the reviewer is "just another AI."** The whole point of the bridge is that the other side might see what you missed.
- **Don't ship past a `BLOCK` verdict** without resolving the block. If you genuinely believe the block is wrong, write back with a counter-argument and ask for a re-review — don't just override silently.
