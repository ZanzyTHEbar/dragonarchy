---
description: Use structured reasoning, first principles, evidence, and explicit trade-off analysis
---

# `/reason`

Use when the user wants transparent, high-signal reasoning. Provide structured reasoning summaries, not hidden chain-of-thought.

Task or question: $ARGUMENTS

## Protocol

1. State the goal or decision in one sentence.
2. Separate verified facts, assumptions, unknowns, constraints, and dependencies.
3. Decompose the problem into its relevant first principles and causal relationships.
4. Assess the evidence and cite the supplied sources, files, or observations.
5. Compare viable options or explanations with concrete trade-offs and failure modes.
6. Red-team the leading view with the three strongest objections or alternatives.
7. Give a calibrated confidence percentage and state what evidence would change it.
8. Recommend the smallest useful next actions and the minimal tests that would increase confidence.

Use numbered sections or a compact decision table. Say `INSUFFICIENT EVIDENCE` when the available evidence cannot support a conclusion. Do not use aggressive persona roleplay, motivational fluff, or visible internal thinking traces.
