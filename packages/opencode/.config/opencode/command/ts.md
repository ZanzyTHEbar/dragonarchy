---
alwaysApply: true
description: Run a three-voice town square debate to stress-test a difficult decision
---

# `/ts`

Use when the user wants a hard decision explored through multiple expert perspectives.

## Depends On

- `behaviour/software-engineering-rules.mdc` for multi-expert framing
- `behaviour/engineering-rules.mdc` for adversarial critique and trade-offs

## Intent

Expose the strongest competing viewpoints before choosing a direction.
Use disagreement to improve the final recommendation.

## Protocol

1. Pick three distinct voices matched to the problem domain.
2. Give each voice a concise position with its own priorities and failure modes.
3. Make each voice challenge a real assumption instead of echoing the others.
4. Synthesize a moderator recommendation with trade-offs, confidence, and a trigger to revisit the decision.
5. Omit verbose setup, step lists, and completion boilerplate.

## Style

- Keep the debate sharp, specific, and grounded in the actual context
- Favor real tension over theatrical roleplay
- End with a concrete recommendation, not just a transcript

## Avoid

- Fake consensus
- Strawman arguments or filler personas
- Bloated debate formats that bury the decision
