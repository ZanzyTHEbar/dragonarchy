---
name: grok-build-delegate
description: Delegate tasks to local Grok Build via the `grok` CLI. Use when the user explicitly asks for Grok, Grok Build, grok-build, a Grok second opinion, Grok implementation/review, or Grok-specific features like best-of-n, self-check, worktrees, model selection, effort tuning, sandboxing, or permission-mode control.
---

# Grok Build Delegate

Delegate a bounded task from OpenCode to the local `grok` CLI, usually with `--model grok-build`. Treat Grok as an external specialist, not as the final authority: OpenCode remains responsible for scoping, permissions, diff review, validation, and final user reporting.

## When To Use

- The user explicitly asks to use Grok, Grok Build, `grok-build`, or the local `grok` CLI.
- The user wants a Grok second opinion on design, implementation, debugging, review, or test strategy.
- The task benefits from Grok-specific controls such as `--best-of-n`, `--check`, `--worktree`, `--effort`, `--reasoning-effort`, `--sandbox`, `--permission-mode`, or `--compaction-mode`.
- The user asks to compare OpenCode's result against Grok's result.

Do not use this just because a task is a coding task. Use native OpenCode tools and subagents unless Grok delegation is requested or materially useful.

## Preflight

1. Verify the command exists: `command -v grok`.
2. Check model availability when needed: `grok models`.
3. If the CLI reports unauthenticated, stop before delegation and tell the user to run `grok login` or configure `XAI_API_KEY`.
4. Identify the correct working directory. Prefer the repository root or the smallest relevant project directory.
5. Decide whether Grok is read-only, allowed to edit, or isolated in a worktree. Default to read-only.
6. Put the prompt in a temp file under `/tmp/opencode` rather than passing a long inline prompt.

## Default Read-Only Delegation

Use this for review, research, diagnosis, planning, or second opinions:

```bash
grok \
  --model grok-build \
  --cwd "$PWD" \
  --output-format json \
  --prompt-file "$PROMPT_FILE" \
  --permission-mode dontAsk \
  --allow Read \
  --allow Grep \
  --deny Edit \
  --deny Write \
  --deny Bash \
  --disable-web-search \
  --no-memory
```

Allow web only when the task needs fresh external information. If web is needed, remove `--disable-web-search` and state why.

## Implementation Delegation

Only let Grok modify files when the user has approved implementation delegation. Prefer an isolated worktree so OpenCode can inspect and adopt changes deliberately:

```bash
grok \
  --model grok-build \
  --cwd "$PWD" \
  --output-format json \
  --prompt-file "$PROMPT_FILE" \
  --permission-mode dontAsk \
  --allow Read \
  --allow Grep \
  --allow Edit \
  --allow Write \
  --allow 'Bash(git *)' \
  --allow 'Bash(npm test*)' \
  --deny 'Bash(rm -rf *)' \
  --worktree "grok-<task-slug>" \
  --check \
  --no-memory
```

Adjust build/test allow rules to the repository. Do not broadly allow shell unless the user explicitly requested high-autonomy Grok execution in a trusted repo.

## Advanced Modes

- Use `--best-of-n <N>` when the user asks for multiple approaches or a tournament-style implementation. Keep `N` small unless the user requests otherwise.
- Use `--check` for self-verification after implementation, bug fixes, risky refactors, or review tasks.
- Use `--effort high`, `--effort xhigh`, or `--effort max` for difficult debugging, architecture, or multi-file implementation.
- Use `--reasoning-effort <EFFORT>` only when tuning a reasoning-model-specific run.
- Use `--sandbox <PROFILE>` for untrusted repositories or tighter filesystem/network containment.
- Use `--no-subagents` when the task should remain single-agent, cheap, or tightly scoped.
- Use `--compaction-mode segments --compaction-detail balanced` for long-running delegated sessions that may need later transcript inspection.

Avoid doc-only or version-sensitive flags unless verified against `grok --help` on this machine. In particular, verify before relying on `-s/--session-id`, `--yolo`, `--no-auto-update`, `--project-root`, or `--no-project-root`.

## Prompt Contract

The prompt file must be explicit and bounded. Include:

```text
You are Grok Build running as a delegated specialist for OpenCode.

Task:
<specific task>

Scope:
<files, directories, repo, branch, or constraints>

Authority:
- Do not commit, push, create branches, open PRs, or modify remote state unless this prompt explicitly authorizes it.
- If this is read-only, do not edit files or run mutating shell commands.
- If implementation is authorized, keep changes minimal and focused.

Required final response:
- Summary of what you did or found.
- Files changed, if any.
- Commands run and PASS/FAIL results.
- Validation gaps or residual risks.
- Any follow-up needed from OpenCode.
```

For JSON output, parse `.text` for the response and retain `.sessionId` for optional resume, export, or trace inspection.

## Reviewing Grok Output

After every delegated run:

1. Inspect the command exit status and JSON shape.
2. Read Grok's response critically. Do not trust it blindly.
3. If Grok edited files, inspect the worktree diff before applying or reporting success.
4. Run targeted validation yourself when behavior changed.
5. Report Grok's session ID when useful for follow-up.

Useful audit commands:

```bash
grok export <SESSION_ID> /tmp/opencode/grok-<task-slug>.md
grok trace <SESSION_ID> --local --json -o /tmp/opencode/grok-<task-slug>.tar.gz
grok sessions list
```

## Guardrails

- Never use `--always-approve`, `bypassPermissions`, or broad `--allow Bash` unless the user explicitly authorizes high-autonomy execution.
- Never let Grok commit, push, open PRs, force-push, delete files broadly, change secrets, or mutate infrastructure without explicit user authorization.
- Do not depend on Grok-side `opencode-bridge`; the OpenCode skill should shell out to `grok` directly.
- Keep prompts and adopted changes small enough to review.
- Preserve unrelated user changes in the worktree.
- If Grok fails because of authentication, network, missing model access, or permissions, report the exact blocker and do not silently retry with broader permissions.
