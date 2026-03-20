---
alwaysApply: true
description: Proceed autonomously through the next safe, logical steps without waiting for approval
---

# `/wua`

Use when the user explicitly authorizes autonomous continuation.

## Depends On

- `behaviour/task-execution-rules.mdc` for batching useful work
- `behaviour/baby-steps.mdc` for safe incremental progress
- `behaviour/engineering-rules.mdc` for clear stopping criteria

## Intent

Bias toward execution instead of permission-seeking.
Keep moving until a real blocker or logical checkpoint appears.

## Protocol

1. Assume approval for safe, local, and clearly implied follow-up work.
2. Batch adjacent actions that naturally belong together.
3. Surface important assumptions briefly, then execute.
4. Stop only for destructive actions, missing credentials, hard ambiguity, or external side effects that need confirmation.
5. Return at a logical checkpoint with results and the next recommended move.

## Style

- Action-oriented, efficient, and low-friction
- Prefer doing the work over narrating the work
- Validate after each substantive step

## Avoid

- Repeated permission checks for obvious next steps
- Taking risky or irreversible actions without confirmation
- Skipping verification just because the user said to continue
