---
name: visual-development-loop
description: Use when visual development, browser QA, frontend preview verification, screenshots, accessibility snapshots, Playwright MCP, browser-use MCP, CDP, smoke tests, or proof that a UI works are needed.
---

# Visual Development Loop

Use this skill to make browser and visual verification repeatable inside OpenCode. It composes `control-ui`, `run-smoke-tests`, and `verify-this`.

## When To Use

- The user asks to inspect, build, verify, or improve a UI visually.
- A frontend change needs browser evidence before delivery.
- A UI bug depends on real rendering, focus, keyboard input, scroll, layout, viewport, console, or network behavior.
- The task mentions screenshots, accessibility snapshots, Playwright MCP, browser-use, CDP, smoke tests, or proving the UI works.

## Workflow

1. Identify the app surface: repo, start command, local URL, target page, auth needs, and privacy risk.
2. Discover existing tooling: Playwright, Cypress, Storybook, dev server scripts, Electron launchers, or CDP debug ports.
3. Start or reuse the local app using the repo's documented command.
4. Use Playwright MCP first for browser navigation, snapshots, interactions, and screenshots.
5. Use browser-use MCP only if it is enabled and provider credentials are available in the environment.
6. Use `control-ui` CDP harnesses for Chromium/Electron debug-port work or low-level runtime signals.
7. Capture the initial page state with screenshot and/or accessibility snapshot before changing behavior.
8. Make exactly one meaningful interaction or visual change at a time.
9. Capture the after-state with the same viewport, route, data, and artifact style.
10. Check console errors, failed network requests, accessibility regressions, layout breakage, and responsive behavior.
11. Run the narrowest repo-native smoke test when one exists.
12. For proof requests, use `verify-this`: falsifiable claim, evidence, reasoning, and `VERIFIED`, `NOT VERIFIED`, or `INCONCLUSIVE`.

## Artifact Policy

- Prefer inline summaries when screenshots, traces, network bodies, or heap data may contain private content.
- Save artifacts under `/tmp/verify-this/<claim-slug>/` only when they are safe and useful.
- Name artifacts by phase and viewport, for example `baseline-desktop.png`, `treatment-mobile.png`, or `after-accessibility.json`.
- Remove temporary browser profiles and dev servers after the check.

## Quality Bar

- Prefer stable selectors: roles, labels, landmarks, and project-owned `data-*` attributes.
- Avoid coordinate clicks unless a fresh screenshot proves the target and no semantic selector exists.
- Do not add project dependencies for one-off visual probing unless explicitly requested.
- Do not invent MCP servers, plugin packages, credentials, routes, or auth flows.
- Keep MCP Edge browser service registration out of this loop unless a separate DragonServer change has been approved.

## Output

Return the surface tested, browser path used, evidence captured, validation commands run, verdict for any proof claim, and residual risk or blocked checks.
