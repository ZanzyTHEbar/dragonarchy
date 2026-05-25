# Cursor Team Kit plugin

OpenCode-normalized import of Cursor Team Kit. Internal-style workflows for CI, code review, shipping, and test reliability. The kit is designed to work without requiring third-party service integrations beyond local tools such as `git`, `gh`, test runners, and browser/terminal harnesses.

## OpenCode layout

- Skills live under `skills/<name>/SKILL.md`.
- Agents live under `agent/<name>.md`; imported Team Kit agents use `mode: all` so they are selectable and available as Task subagents.
- Rules live under `rules/cursor-team-kit/*.mdc` and are referenced by `opencode.json` instructions as global defaults after OpenCode restart.
- PR Review Canvas static resources live next to `skills/pr-review-canvas/SKILL.md`.

## Upstream

- Repository: <https://github.com/cursor/plugins>
- Directory: `cursor-team-kit`
- Commit: `3347cbab5b54136f6fba0994c3a01a56f7fb7fca`
- Version: `1.1.0`
- License: MIT
