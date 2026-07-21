---
name: new-branch-and-pr
description: Create a fresh branch, complete work, and open a pull request. Use when the user explicitly wants a clean branch plus PR workflow.
---

# New branch and PR

## Trigger

Starting work that should be shipped through a clean branch and pull request workflow, and the user has explicitly asked for branch/PR creation.

## Workflow

1. Ensure the working tree is clean or explicitly handled.
2. Create a descriptive branch from the latest main, unless the repo uses `jj` and a different local workflow is documented.
3. Complete implementation and tests.
4. Commit focused changes with a Conventional Commit message.
5. Push branch and create a concise PR with summary and test notes.

## Guardrails

- Keep branch scope focused on one change set.
- Include verification notes before requesting review.
- Do not commit, push, force-push, or create a PR without explicit user approval.
- Preserve unrelated user or agent changes.

## Output

- New branch name.
- PR summary and test notes.
- PR URL.
