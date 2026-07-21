---
name: cursor-team-kit
description: Index the imported Cursor Team Kit workflows for OpenCode. Use when the user asks about cursor-team-kit, the team kit plugin, imported CI/review/shipping skills, or which Team Kit workflow to invoke.
license: MIT
metadata:
  upstream: cursor-team-kit@1.1.0
  source: https://github.com/cursor/plugins/tree/3347cbab5b54136f6fba0994c3a01a56f7fb7fca/cursor-team-kit
---

# Cursor Team Kit for OpenCode

This directory preserves the Cursor Team Kit plugin metadata as an OpenCode skill index. The original Cursor plugin bundles skills, agents, rules, a README, a license, and a logo. OpenCode loads the actionable parts from their native locations:

- Skills: `skills/<name>/SKILL.md`
- Agents: `agent/<name>.md`
- Rules: `rules/cursor-team-kit/*.mdc`, wired through `opencode.json` instructions as global defaults after OpenCode restart

## Source

- Upstream repository: <https://github.com/cursor/plugins>
- Imported subdirectory: `cursor-team-kit`
- Commit: `3347cbab5b54136f6fba0994c3a01a56f7fb7fca`
- Upstream version: `1.1.0`
- License: MIT

## Components

### Skills

| Skill | Description |
|:------|:------------|
| `loop-on-ci` | Watch CI runs and iterate on failures until checks pass. |
| `review-and-ship` | Run a structured review, commit changes, and open a PR when explicitly requested. |
| `pr-review-canvas` | Generate an interactive HTML PR walkthrough with annotated, categorized diffs. |
| `verify-this` | Prove or disprove claims with baseline/treatment artifacts and a clear verdict. |
| `control-cli` | Build or adapt a local harness to drive and profile interactive CLIs or TUIs. |
| `control-ui` | Build or adapt a local browser/CDP harness for web or Electron UIs. |
| `make-pr-easy-to-review` | Clean noisy PR history, improve descriptions, and add reviewer guidance. |
| `run-smoke-tests` | Run Playwright smoke tests and triage failures. |
| `fix-ci` | Find failing CI jobs, inspect logs, and apply focused fixes. |
| `new-branch-and-pr` | Create a fresh branch, complete work, and open a pull request when explicitly requested. |
| `get-pr-comments` | Fetch and summarize review comments from the active pull request. |
| `check-compiler-errors` | Run compile and type-check commands and report failures. |
| `what-did-i-get-done` | Summarize authored commits over a given time period into a concise status update. |
| `weekly-review` | Generate a weekly recap of shipped work with bugfix/tech-debt/net-new highlights. |
| `fix-merge-conflicts` | Resolve merge conflicts, validate build/tests, and summarize decisions. |
| `deslop` | Remove AI-generated code slop and clean up code style. |
| `workflow-from-chats` | Extract durable working preferences from chats into skills, rules, or docs. |
| `thermo-nuclear-code-quality-review` | Run an unusually strict maintainability review. |

### Agents

| Agent | Description |
|:------|:------------|
| `ci-watcher` | Monitor GitHub Actions and PR-attached checks. Available as a selectable agent and Task subagent. |
| `thermo-nuclear-code-quality-review` | Apply the thermo-nuclear code quality rubric to a diff. Available as a selectable agent and Task subagent. |

### Rules

| Rule | Description |
|:-----|:------------|
| `typescript-exhaustive-switch` | Require exhaustive switch handling for unions/enums. |
| `no-inline-imports` | Keep imports at module top-level for readability and consistency. |

Because OpenCode `instructions` are global rather than Cursor-contextual, the imported rules are intentionally phrased as defaults with explicit exceptions instead of absolute bans.
