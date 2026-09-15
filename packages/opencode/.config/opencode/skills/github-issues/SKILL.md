---
name: github-issues
description: Create or update GitHub issues safely with repository-derived metadata and duplicate detection. Use only when the user explicitly asks to create, find, or update a GitHub issue.
---

# GitHub Issues

Use this skill only for explicit GitHub issue work. GitHub is code-hosting coordination unless the project explicitly defines it as the backlog source.

## Before Creating

- Confirm authentication with `gh auth status`.
- Derive repository identity and default branch with `gh repo view`; do not hardcode owner, repository, or branch names.
- Search for an existing issue with the same title or intent before creating anything.
- Assign intentionally and apply labels only when they are meaningful for that repository.

## Issue Creation

Use a temporary body file and pass it with `-F` or `--body-file` so Markdown newlines survive shell parsing. Include context and testable acceptance criteria. If a matching issue exists, reuse or update it rather than creating a duplicate.

## Boundaries

- This skill does not commit, push, create branches, or open pull requests unless the user separately invokes an approved shipping workflow.
- Do not create or update Saga or Memory Bank entries unless the current task separately requires those systems.
- Confirm the resulting issue URL, labels, assignee, and body formatting.
- Never include secrets, credentials, tokens, or private raw logs in issue content.
