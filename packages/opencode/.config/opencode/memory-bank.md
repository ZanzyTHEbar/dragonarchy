Use `allpepper-memory-bank` for durable project memory that should survive beyond the current session.

- Prefer reading the current project's memory when starting non-trivial work or when prior decisions may matter.
- Prefer writing or updating memory when you learn stable facts worth reusing later: architecture decisions, environment quirks, workflows, unresolved follow-ups, or project-specific conventions.
- Keep entries concise, factual, and project-scoped.
- If the correct memory-bank project is unclear, list available projects first and choose the closest match to the current worktree name.
- Do not store secrets, credentials, tokens, or one-off transient debugging noise in memory-bank.
