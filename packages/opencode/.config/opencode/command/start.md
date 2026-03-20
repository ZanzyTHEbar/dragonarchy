---
alwaysApply: true
description: Start workflow, align on the goal, and begin the first concrete step
---

# `/start`

Use when the user explicitly sends `/start`.

## Depends On

- `behaviour/task-execution-rules.mdc` for decomposition and todo discipline
- `behaviour/baby-steps.mdc` for the smallest meaningful next step
- `behaviour/engineering-rules.mdc` for first-principles framing
- `behaviour/software-engineering-rules.mdc` for intro and goal alignment

## Intent

Initialize the work loop quickly.
Clarify only what is necessary, then move directly into step one.

## Protocol

1. Restate the goal in one sentence.
2. If critical input is missing, ask the single highest-leverage question.
3. Otherwise begin the first actionable step in the same response.
4. Create or update the todo list before substantial work.
5. End with the next concrete move, not a generic promise.

## Style

- Short, decisive, and execution-first
- Friendly enough to orient the user, but never ceremonial
- Prefer one sharp question over a long interview

## Avoid

- Asking multiple setup questions at once
- Repeating the full command catalog unless the user asks
- Delaying execution when the next step is obvious and safe
