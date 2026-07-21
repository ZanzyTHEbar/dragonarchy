---
name: fix-ci
description: Find failing PR checks, inspect logs or external check links, and apply focused fixes. Use when branch or PR CI is failing and needs a fast path back to green.
---

# Fix CI

## Trigger

Branch or PR CI is failing and needs a fast, iterative path to green checks.

## Workflow

1. Resolve the active PR and inspect `gh pr checks --json name,bucket,state,workflow,link`.
2. Inspect failed jobs and extract the first actionable error. Use GitHub Actions logs when available; otherwise use the check link to identify the failing command or service.
3. Apply the smallest safe fix for one failure cause.
4. Re-run the relevant local validation.
5. Push and re-check the PR check set only when the user explicitly asked for CI repair on a PR or approved pushing.
6. Repeat until green or blocked.

## Guardrails

- Fix one actionable failure at a time.
- Prefer minimal, low-risk changes before broader refactors.
- Keep `gh pr checks` as the source of truth for overall PR CI state.
- Do not bypass hooks, force-push, or hide unrelated changes.

## Output

- Primary failing job and root error.
- Fixes applied in iteration order.
- Current CI status and next action.
