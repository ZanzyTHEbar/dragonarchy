---
name: avular-design-docs
description: Create and review Avular software design documentation for medium and large changes. Use when planning a design, writing a design document, preparing a technical review, mapping requirements to design decisions, or deciding whether a change needs formal design documentation.
---

# Avular Design Docs

Use this skill for engineering work that benefits from design before implementation.

## When Design Is Required

Write a design when one or more of these are true:

- the change affects multiple components or interfaces
- the solution has meaningful architecture or trade-off decisions
- the work needs stakeholder review before coding
- verification strategy is non-trivial
- the impact on other components is not obvious

Skip formal design documentation for small, local, low-risk changes.

## Workflow

1. Define the objective and scope of the change.
2. Identify impacted components, interfaces, assumptions, and open questions.
3. Record the proposed design and the key decisions behind it.
4. Capture risks, error handling, and the verification strategy.
5. Include only the diagrams and sections needed for the review.

## Guardrails

- Keep the document decision-oriented, not narrative.
- Do not dump the full checklist into every design.
- If feedback is expected, resolve it in the design before coding when possible.
- Focus on why this solution is chosen and what it changes.

## Output

- A concise design document or review summary
- Explicit open questions
- A verification strategy matched to the design

## Additional Resources

- Minimal design template: [template.md](./template.md)
- Section selection checklist: [checklist.md](./checklist.md)
- Sizing examples: [examples.md](./examples.md)
