---
name: review-and-ship
description: Review the current branch for bugs, intent fit, and test coverage, then commit and open or update a PR when explicitly requested. Use for review-and-ship workflows.
---

# Review and ship

## Trigger

Reviewing changes before shipping. Close key issues, verify behavior, and open or update a PR when the user has explicitly requested shipping.

## Workflow

1. Gather context: diff against base branch, uncommitted changes, recent commits, changed files, and user intent from recent relevant chats if useful and available.
2. Run targeted tests for changed behavior. If no focused tests exist, decide whether to add them or document the gap.
3. Review for correctness, regressions, security, and intent fit. Use parallel subagents for larger diffs.
4. Fix critical issues before finalizing and re-run affected tests.
5. Commit selective files with a concise Conventional Commit message only when the user requested commit/shipping.
6. Push branch and open or update a PR only when the user requested it or approved it.

## Suggested Checks

```bash
git fetch origin main
git diff origin/main...HEAD
git status
gh pr checks --json name,bucket,state,workflow,link
```

## Guardrails

- Prioritize correctness, security, and regressions over style-only comments.
- Keep commits focused and avoid unrelated file changes.
- If pre-commit checks fail, fix the issues rather than bypassing hooks.
- Use `gh pr checks` instead of GitHub Actions-only commands when judging PR readiness.
- Respect the global OpenCode workflow, including `jj` preference where available and no commit/push/PR without explicit approval.

## Output

- Findings summary: critical, warning, note.
- Tests run and outcomes.
- PR URL when one was created or updated.
