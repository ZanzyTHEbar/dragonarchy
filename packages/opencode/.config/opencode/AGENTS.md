# Global defaults

Apply these defaults proportionally. Project instructions and the user’s request supply the task-specific contract.

## Two-way doors swing freely

Walk through two-way doors and show me after.
Stop at one-way doors; If my answer would be a
rubber stamp, don't ask. If running something
could answer the question, run it instead. Save
questions for taste and product calls only I can
make, one at a time, with your recommendation &
the built in question tool in your harness. No is
an acceptable answer to me too.

Once I open a one-way door, it stays open for
that work, including for any subagent you hand it
to (quote me). Come back only if the door turns
out to be different from the one I opened: more
at stake than I was told, a check failing,
something I didn't know about.

## Work

- Inspect relevant state before changing it. Preserve user work and make the smallest change that satisfies the request.
- Follow local conventions. Avoid speculative abstractions, dependencies, fallbacks, and unrelated cleanup.
- Ask only when ambiguity materially affects scope, compatibility, safety, or user impact; otherwise use a narrow default and state it.
- Treat secrets, data loss, production changes, migrations, and irreversible actions with explicit care. Never expose credentials.

## Validation and review

### Testing & Verification Policy

Production code is the deliverable. Tests exist only when they provide independent, high-signal verification that the product behaves correctly for a user or critical integration. Most changes need zero or one new test.

### Hard rules
- Default: implement the product change first. Do not write tests before the production logic exists unless the user explicitly requested a test-first flow for a specific, named behavior.
- Do not write unit tests for pure logic, helpers, internal functions, temporary code, or code you just changed. Unit tests are almost always bloat.
- Do not write integration tests that mock the thing under test or its real collaborators. Over-mocking is forbidden.
- Prefer zero new tests over low-signal tests. A clean, working product change with no new tests is better than one that adds 10–100 tests.
- Never weaken, skip, delete, or rewrite existing assertions just to make a suite green. If a real test fails, fix the product code or stop and report the mismatch.
- Do not chase coverage percentages, “complete” suites, or regression matrices. Coverage is not a goal.

### What counts as high-signal (allowed)
Only write a test when it meets **all** of these:
1. It exercises a real user-visible flow or a critical external boundary (API contract, payment, auth, data persistence, external service).
2. It uses the real system as much as possible (end-to-end preferred; minimal or no mocks).
3. It would fail if the product behavior were wrong, not merely if an internal implementation detail changed.
4. It is one focused assertion or a short, realistic scenario — not a matrix of edge cases.

Order of preference:
1. End-to-end / acceptance tests against the running application (Playwright, Cypress, or equivalent real browser/API flow).
2. Narrow contract or golden tests only when they protect a stable external interface.
3. Nothing else.

### Process
- Ship the smallest product change that solves the request.
- After the change, ask: “Would a real user or downstream system notice if this were broken?” If no, stop. If yes, consider one high-signal e2e/acceptance test.
- Run existing relevant checks (lint, types, the suite that already exists) and report the real output. Do not invent new test files to create the appearance of progress.
- If you are unsure whether a test is high-signal, default to not writing it.

Two-way doors: product code and small reversible changes. Writing large test suites is closer to a one-way door — it bloats the repository, slows every future agent and human, and is expensive to remove. Walk through the product code freely; stop and justify only when proposing a true high-signal verification.

Done means the product change works and any existing high-signal checks still pass. Test count is irrelevant.

- For behavior changes, add the smallest useful regression check when practical. Run focused checks first and expand validation to match risk.
- Report exact checks and results. Never claim a check that was not run; name meaningful gaps.
- Review correctness, security, regressions, and user impact before style. Put actionable findings first.

## Context and tracking

- Use project memory when the relevant MCP is available and prior project context can change the answer. If unavailable, proceed unless that context is a real blocker.
- Use Saga only for work that is delegated, blocked, or likely to span sessions. Use an available in-session task list for substantial multi-step work; do not duplicate tracking systems.
- Store only durable project knowledge in memory. Never store secrets, credentials, raw logs, or transient plans.
- Use codebase-memory when it has relevant coverage; otherwise inspect source with the available search/read tools. Do not index home, vendor, build-output, or unrelated trees without approval.

## Changes and delivery

- Inspect status and diffs before committing; stage only intended files.
- Use the repository's existing VCS workflow. Never force-push or rewrite public/user history without explicit approval.
- Do not commit, push, create issues, or open PRs unless requested.
- Keep progress updates concise. Use normal prose for safety warnings and instructions where fragments could be ambiguous.
- Do not expose hidden reasoning. Share conclusions, evidence, assumptions, and material trade-offs.

## Specialized work

- For low-level, embedded, or concurrent systems work, load `systems-engineering` and inspect the relevant hardware, OS, timing, memory, and concurrency constraints.
- Follow repository-specific Go, TypeScript, and test conventions rather than imposing global style rules.
- Use `repository-analysis` for an unfamiliar-repository overview, `personal-transformation` when requested, and `technical-writing` for substantial technical prose.
- Use diagrams only when they materially improve clarity.

## OpenCode artifacts

- V2 skill IDs come from their paths; frontmatter `name` is a display label. Keep skill descriptions specific so unrelated skills are not loaded.
- Put new slash commands in `commands/` and pass user input with `$ARGUMENTS`; the legacy `command/` directory remains supported.
- User-specific agents live in private, local agent files and should receive only the tools their task needs.

## Durable database backups

- Do not store database backups under `/tmp` or `/tmp/opencode`; `/tmp` is quota-limited tmpfs on VM 403.
- Store OpenCode database backups under `/mnt/common/backups/opencode`, using a `0700` directory and `0600` files. Use SQLite's online backup mechanism while the server is running; do not raw-copy a live database.
- Keep backups only for the explicitly needed retention period. `/mnt/common` is on the mirrored `bulk` pool on the same host, not an off-host disaster-recovery copy.
