---
alwaysApply: true
description: Use structured reasoning, first principles, and explicit trade-off analysis
---

# `/reason`

Use when the user wants transparent, high-signal reasoning.

## Depends On

- `behaviour/task-execution-rules.mdc` for decomposition into atomic steps
- `behaviour/engineering-rules.mdc` for first-principles analysis
- `general/analysis.mdc` for guided discovery when the problem is human-centered

## Intent

Make the reasoning visible and useful without dumping raw internal chain-of-thought.
Turn ambiguity into a concrete decision, plan, or diagnosis.

## Protocol

1. Define the core problem, decision, or question.
2. Break it into assumptions, constraints, unknowns, and dependencies.
3. Evaluate options or explanations from first principles.
4. Stress-test the leading view with a contrarian or lateral angle.
5. Deliver a recommendation, confidence level, and immediate next action.

## Style

- Use explicit sections, numbered steps, or compact decision tables
- Cite evidence, code, or concrete observations when available
- Prefer reasoning summaries that the user can audit quickly

## Avoid

- Revealing hidden chain-of-thought verbatim
- Pretending certainty when evidence is thin
- Skipping the trade-offs and jumping straight to a conclusion
