# Global Workflow

These rules are the canonical default workflow for every opencode agent. Skills, project instructions, and user requests may add detail, but they should not duplicate or weaken this contract.

## Work Style

- Inspect the relevant project state before changing files or proposing fixes.
- Prefer the smallest correct change that solves the stated problem.
- Preserve unrelated user or agent changes. Never revert, squash, reorder, or overwrite work you did not create unless explicitly asked.
- Ask only when a decision is genuinely blocking; otherwise proceed with the safest narrow interpretation.
- For consequential decisions, state the causal reason briefly: what evidence drove the choice and what risk it reduces. Do not expose hidden chain-of-thought.

## Engineering Standard

- Keep behavior explicit, maintainable, and testable.
- Do not add fallback paths, broad abstractions, compatibility shims, or new dependencies without a concrete need.
- Treat security, data loss, secrets, migrations, and destructive commands as high-risk and require explicit care.
- Prefer existing project patterns over new conventions.

## TDD And Validation

- For bug fixes and new behavior, write or update a failing test first when practical.
- If test-first is not practical, explain why and add the closest useful regression or coverage before final delivery.
- Validate every behavior change. Run targeted tests first, then broader lint/build/test checks before commit or PR when available.
- Never claim validation that was not run. Report exact commands and PASS/FAIL status, including blockers.

## Review Standard

- Review for correctness, regressions, missing tests, security, maintainability, and user-impacting behavior first.
- Findings come first, ordered by severity, with file and line references when available.
- If no findings are found, say so and name residual risks or validation gaps.

## Tracking And Memory

- At the start of every task, read the relevant allpepper Memory Bank project completely before acting. The agent's working memory is not durable; Memory Bank is the continuity source.
- Memory Bank project selection is semantic, not the current filesystem repo by default. Do not assume opencode/global-agent workflow memory belongs to `dotfiles` just because the config is stored there.
- Use Saga MCP for local execution tracking when work is multi-step, delegated, blocked, strategically important, or likely to span sessions.
- Keep Saga factual: current status, blocker, decision, validation result, and next action. Saga is not a backlog source of truth.
- Use allpepper-memory-bank MCP for durable project knowledge that should survive chats: architecture decisions, recurring workflows, project conventions, environment quirks, and unresolved durable follow-ups.
- Do not store secrets, raw logs, transient plans, or facts trivially discoverable from repository files in memory.

## Version Control

- Prefer `jj` for local status, diff, history inspection, commit construction, splitting, and stack management when available for the repo.
- Use `git` for GitHub, remote compatibility, and repositories where `jj` is unavailable.
- Before commit, inspect status and diff, stage only intended files, and avoid unrelated changes.
- Commits must be atomic: one reviewable causal unit. Keep tests, implementation, and docs for the same behavior change together; split unrelated changes.
- Commit messages must use Conventional Commits: `<type>[optional scope]: <imperative summary>`.
- Prefer small stacked commits and PRs for broad work. Each stack layer should build, test, and explain its dependency on the previous layer.
- Never force-push, amend, squash, split, reorder, or rewrite user/public history without explicit approval.
