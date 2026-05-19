---
name: ship
description: Use when the user explicitly wants to commit, push, and open a pull request for current changes. Enforces atomic staging, Conventional Commits, validation, safe push, PR deduplication, and opencode review trigger.
---

# Ship

Commit the intended changes, push the branch, open or reuse a PR, and trigger an opencode review. Use only on an explicit user request such as "ship it", "commit push pr", "create a PR", or "commit and ship".

## Workflow

Stop and report immediately on any blocker, failed validation, auth problem, conflict, or unexpected unrelated staged change.

### 1. Inspect State

Prefer `jj` for local inspection when available in the repo:

```bash
jj status
jj diff
jj log -r 'latest(ancestors(@), 10)'
```

Also inspect git-compatible state before committing or pushing:

```bash
git status
git diff
git diff --staged
git log --oneline -10
git remote -v
```

Use this to identify the branch/bookmark, changed files, recent message style, remote, and any unrelated user changes.

### 2. Validate Before Commit

Run targeted tests for the changed area first. If project lint/build/test commands are discoverable, run the relevant broader checks before committing.

Abort on failure unless the user explicitly asks to ship despite known failures. Report exact commands and results.

### 3. Stage Atomic Changes

Stage only files that belong to one reviewable causal unit. Exclude secrets, `.env`, credentials, databases, generated noise, and unrelated work.

Use `jj split` or `jj squash` for atomic local change construction when safe and appropriate. Do not rewrite user-created history without explicit approval.

Verify staging:

```bash
git status
git diff --staged
```

### 4. Commit

Use a Conventional Commit message:

```text
<type>[optional scope]: <imperative summary>
```

Prefer <= 50 characters for the subject, hard max 72 unless the repo style differs. Add a body only when the why, risk, or migration detail is not obvious.

Commit with the repository's active workflow (`jj describe`/`jj git export` or `git commit`) as appropriate. Record the resulting git-compatible commit hash before reporting.

### 5. Prepare Push

Derive the repo and default branch dynamically:

```bash
SLUG=$(gh repo view --json nameWithOwner -q .nameWithOwner)
BASE=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)
BRANCH=$(git branch --show-current)
REMOTE=$(git config "branch.$BRANCH.remote" 2>/dev/null || true)
```

If `BRANCH` is empty, stop and inspect the active `jj` bookmark or detached git state before pushing. Do not guess a branch name.

If `REMOTE` is empty, derive it from `git remote -v` and `SLUG`. If exactly one remote points at the GitHub repo, use it. If none or multiple match, stop and ask which remote to push.

Fetch remote state before pushing:

```bash
git fetch "$REMOTE"
```

Do not force-push. If the branch needs a history rewrite, stop and ask for explicit approval.

Push with upstream if needed:

```bash
git push -u "$REMOTE" "$BRANCH"
```

or, if upstream already exists:

```bash
git push
```

### 6. Open Or Reuse PR

Deduplicate by branch first:

```bash
EXISTING_PR=$(gh pr list --repo "$SLUG" --head "$BRANCH" --state open --json url -q '.[0].url' 2>/dev/null || true)
```

If a PR exists, reuse it. Otherwise create a newline-safe body file and pass it with `-F`:

```bash
PR_BODY=$(mktemp)
cat > "$PR_BODY" <<'EOF'
## Summary

- <what changed>
- <why>

## Validation

- <commands and PASS/FAIL status>

## Risks

- <known limitations or none>
EOF
gh pr create --repo "$SLUG" --base "$BASE" --head "$BRANCH" --title "<title>" -F "$PR_BODY"
```

The PR body must include a short summary and validation commands/results.

### 7. Trigger Review

Post a review request without asking for automatic approval:

```bash
gh pr comment <PR number-or-url> --body "/oc please review this PR"
```

### 8. Report Back

Report:

- commit hash and message
- PR URL
- validation commands and PASS/FAIL status
- whether opencode review was triggered

## Safety Rules

- Never commit secrets, credentials, token files, databases, or unrelated work.
- Never force-push, rewrite public history, or amend user work without explicit approval.
- Do not assume `origin/main`; derive remote and base branch.
- If `gh` is not authenticated, stop and tell the user the exact failing command.
