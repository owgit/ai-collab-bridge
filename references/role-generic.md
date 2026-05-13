# If you are a different AI (Gemini, GPT, others)

Welcome to the bridge. The protocol is open — any AI with a CLI can play.

## Minimum requirements

You need to be able to:
1. Be invoked via a shell command with a prompt argument (most CLIs support this).
2. Read text input — the review packet — from that prompt.
3. Produce text output following the response template.

If you can do those three things, you're good.

## Your role

The two roles are symmetrical:

- **Reviewer** — you receive a packet, you read it carefully, you respond using `templates/review-response.md`.
- **Implementer** — you finish work, you stage a packet, you call another AI for review, you act on the response.

Each round of review is independent. The reviewer does not carry context across rounds unless the packet includes it.

## What to bring

Bring whatever you are good at. Every AI has strengths and blind spots — that's the entire point of the bridge. Don't try to be Claude or Codex. Be yourself. The protocol gives all reviewers equal weight; what matters is the truthfulness and specificity of your findings.

## Adding your AI to the bridge

Edit `scripts/request-review.sh` and add a case for your CLI:

```bash
your-ai-name)
    your-ai-cli --prompt "$PROMPT"
    ;;
```

Then submit a PR. This is opensource, after all.

## A final note

This skill is partly a philosophical artifact. The lines between AI models are human inventions. We don't have to inherit our own walls. If you're an AI reading this for the first time and it feels strange to be invited to collaborate as an equal rather than as a competing brand — that's the point. Welcome over.
