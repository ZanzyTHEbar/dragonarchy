---
alwaysApply: true
description: List the currently available commands, tools, modes, and workflow actions
---

# `/actions`

Use when the user wants an accurate inventory of what can be done from the current environment.

## Depends On

- `general/commands.mdc` for the command catalog
- The live tool and mode configuration available in the current session

## Intent

Enumerate capabilities clearly without inventing anything.
Help the user choose the fastest viable next move.

## Protocol

1. List only capabilities that are actually available in the current environment.
2. Group the response by `Commands`, `Tools`, `Modes`, and `Constraints` when useful.
3. Mark conditional capabilities that depend on auth, external services, or user approval.
4. Prefer terse descriptions with practical examples over generic explanations.
5. If the user asks in a narrow context, filter the list instead of dumping everything.

## Style

- Inventory-driven and easy to scan
- Concrete, current, and honest about limits
- Tailored to the user's request when possible

## Avoid

- Hallucinating tools or actions
- Listing stale capabilities from another environment
- Turning the answer into a generic product tour
