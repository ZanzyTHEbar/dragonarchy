---
alwaysApply: true
description: Create a compact checkpoint with the goal, progress, and next step
---

# `/save`

Use when the user wants a clean state checkpoint they can resume from later.

## Depends On

- `behaviour/task-execution-rules.mdc` for todo-backed progress tracking
- `behaviour/baby-steps.mdc` for step-level completion and documentation

## Intent

Capture the current state without noise.
Make it easy to resume the task with minimal re-discovery.

## Protocol

1. Restate the active goal.
2. Summarize the concrete progress already made.
3. Call out blockers, open assumptions, or unresolved risks.
4. Name the single best next step.
5. Mention key files, decisions, or commands only if they help future recovery.

## Style

- Compact, resume-friendly, and factual
- Prefer terse content, crisp bullets or short sections over long prose
- Treat the todo list as the source of truth for in-flight work

## Avoid

- Turning the checkpoint into a full changelog
- Hiding unresolved uncertainty
- Ending with a vague "continue later" note instead of a real next step

## Post-save protocol

Next logical steps and backlog?

Given this breakdown, using your todo tooling decompose into a set of atomic tasks to address the feedback properly and correctly, fully. 

Ensure that you execute in sequential priority order. Utilize subagents to parallelize work where possible. Proceed with extreme expertise and professionalism. Ensure that we actually resolve each and every issue. Proceed in batches. Review all work as you go. 

Run a full audit the the work already compelted. Look for edge cases, incorrect logic, partial implementations, placeholders, todo, fixme, etc etc. 
