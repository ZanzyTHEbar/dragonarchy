---
name: deslop
description: Remove AI-generated code slop and clean up code style. Use when asked to deslop a diff, remove AI-looking artifacts, or tighten code without changing behavior.
---

# Remove AI code slop

Check the diff against the chosen base branch and remove AI-generated slop introduced in the branch.

## Focus Areas

- Extra comments that are unnecessary or inconsistent with local style.
- Defensive checks or try/catch blocks that are abnormal for trusted code paths.
- Casts to `any` used only to bypass type issues.
- Deeply nested code that should be simplified with early returns.
- Other patterns inconsistent with the file and surrounding codebase.

## Guardrails

- Keep behavior unchanged unless fixing a clear bug.
- Prefer minimal, focused edits over broad rewrites.
- Preserve unrelated user or agent changes.
- Keep the final summary concise: one to three sentences.
