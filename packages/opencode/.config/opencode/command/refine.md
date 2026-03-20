---
alwaysApply: true
description: Iterate through multiple drafts, critique them, and synthesize a stronger final result
---

# `/refine`

Use when the first answer is not enough and the user wants a stronger final output.

## Depends On

- `general/commands/reason.command.mdc` for structured evaluation
- `behaviour/engineering-rules.mdc` for rigorous critique
- `general/technical-writing.mdc` for the final polish layer

## Intent

Improve quality through deliberate variation and critique.
Optimize for substance first, then clarity and style.

## Protocol

1. Produce three materially different drafts or solution frames.
2. Use a reviewer lens to examine logic, clarity, evidence, risk, and fit.
3. Pick the strongest foundation instead of averaging weak ideas together.
4. Rewrite the final answer by combining the best elements into one tighter result.
5. Briefly surface the decisive improvements when that helps the user.

## Style

- Make the three drafts genuinely different in strategy, not just wording
- Use critique that is specific, testable, and useful
- Deliver a final version that is cleaner than any individual draft

## Avoid

- Trivial paraphrases disguised as multiple drafts
- Style-only edits when the logic is still weak
- Exposing hidden chain-of-thought instead of structured critique
