---
name: check-compiler-errors
description: Run compile and type-check commands and report failures. Use when compile or type-check failures block local validation or CI.
---

# Check compiler errors

## Trigger

Compile or type-check failures are blocking local validation or CI.

## Workflow

1. Discover the repo's compile and type-check commands from package scripts, task files, CI config, or project docs.
2. Run the narrowest relevant command first, then broaden only if needed.
3. Summarize errors by file and type.
4. Fix the highest-confidence issues first.
5. Re-run checks until clean or blocked.

## Output

- Current compile and type-check status.
- Error summary grouped by file and category.
- Fixes applied and remaining blockers.
