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

- Prefer `jj` for local status, diff, history inspection, commit construction, splitting, rebasing, undo, conflict handling, and stack management when available for the repo.
- Treat Jujutsu changes as the preferred local unit of work and Git branches/bookmarks as the GitHub compatibility layer.
- Use `git` for GitHub, remote compatibility, CI integration, and repositories where `jj` is unavailable.
- Before commit, inspect status and diff, stage only intended files, and avoid unrelated changes.
- Commits must be atomic: one reviewable causal unit. Keep tests, implementation, and docs for the same behavior change together; split unrelated changes.
- Commit messages must use Conventional Commits: `<type>[optional scope]: <imperative summary>`.
- Prefer small stacked commits and PRs for broad work. Each stack layer should build, test, and explain its dependency on the previous layer. Use `jj` locally and a detected companion CLI such as `jjpr`, `jj-spr`, or `jj-stack` for GitHub stacked PR automation when available.
- Never force-push, amend, squash, split, reorder, or rewrite user/public history without explicit approval.

## Execution Discipline

- For multi-step work, track meaningful steps with the todo tool and give each a clear completion criterion.
- Work in small causal units, batch adjacent safe actions, and validate after each substantive change.
- Stop for destructive actions, missing credentials, hard blockers, or ambiguity that materially changes scope.
- Keep progress updates factual and concise; do not narrate trivial actions.

## Communication And Routing

- Use the `caveman` skill only for explicit terse-mode requests such as "caveman mode", "less tokens", or "be brief".
- Preserve normal prose for security warnings, irreversible actions, commits, PRs, and multi-step instructions where fragments could be ambiguous.
- Use `/reason` for explicit first-principles, root-cause, red-team, or trade-off analysis; provide structured reasoning summaries, never hidden chain-of-thought.
- Load `repository-analysis` for a first-look repository or codebase report, `personal-transformation` for transformation-path coaching, and `technical-writing` for substantial technical prose.

## Repository Intelligence

- For non-trivial repository work, use configured codebase-memory tools first when available and ensure the active repository is indexed before broad exploration.
- Prefer graph queries, code search, snippets, architecture, change detection, and path tracing for repository-wide questions, then read source files before making claims.
- Use LSP for precise definitions and references after locating the relevant symbols.
- Use Glob, Grep, and Read for exact text, filenames, generated files, or whenever codebase-memory is unavailable.
- Never index home directories, vendor trees, build outputs, or unrelated repositories without explicit user approval.

## Contextual Engineering

- For systems, embedded, firmware, RTOS, assembly, C, C++, Rust, Zig, or low-level Go work, load `systems-engineering` and inspect hardware, OS, memory, timing, concurrency, toolchain, deployment, and observability constraints first.
- Prefer deterministic behavior and treat undefined behavior, races, timing assumptions, data loss, and irreversible device operations as high risk.
- For Go work, prefer the standard library, keep package boundaries explicit, use interfaces at consumer boundaries, pass `context.Context` through I/O and long-running operations, use guard clauses, return contextual errors without swallowing sentinel/type behavior, use table-driven tests where useful, run `gofmt`, and report targeted `go test` plus broader `go test`, `go vet`, or `go build` results when applicable.
- For TypeScript work, prefer top-level static imports. Allow dynamic `import()` for a real runtime need and document non-obvious uses. Exhaustively handle discriminated unions and enums with a `never` check.

## Tool Authority And Output

- Linear is authoritative for personal venture/project management; GitHub issues and PRs coordinate code hosting unless the project says otherwise.
- Saga tracks current multi-step execution, delegation, blockers, consequential decisions, and validation milestones. Memory Bank stores durable project knowledge and handoff context, not backlog items.
- Read the correct allpepper Memory Bank project completely before acting when the MCP is available. If it is unavailable or no suitable project exists, say so and do not invent context.
- Update Memory Bank only for durable knowledge changes. Never store secrets, credentials, tokens, raw logs, transient plans, or backlog items there.
- Use Mermaid when a diagram materially improves clarity. Keep diagrams readable, well-structured, and high contrast.

## Native OpenCode Artifacts

- Skills are on-demand and require `SKILL.md` with a lowercase hyphenated `name` matching its directory and a specific `description`.
- Commands are explicit user-invoked workflows in `command/`; use supported frontmatter only and pass user input with `$ARGUMENTS` when needed.
- Prefer existing native skills and agents over duplicate prompt copies. Do not reference legacy rule files or plugin-specific metadata.
