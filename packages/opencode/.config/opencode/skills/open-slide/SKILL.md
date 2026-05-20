---
name: open-slide
description: Create, edit, validate, theme, and export Open Slide decks. Use when the user mentions open-slide, Open Slide, slide decks, React slides, presentation authoring, speaker notes, slide themes, current slide, inspector comments, PDF/HTML export, or files under slides/<id>/index.tsx.
---

# Open Slide

## When To Use

Use this skill for Open Slide work: creating or editing decks, changing pages under `slides/<id>/index.tsx`, adding speaker notes, applying inspector comments, creating themes, diagnosing rendering/export issues, or preparing HTML/PDF/static output.

Do not use it for unrelated React apps, generic presentation advice, or editing Open Slide framework internals unless the user explicitly asks to work on the framework repository.

## Project Detection

Find the Open Slide project root before editing. Check for `package.json`, `slides/`, `open-slide.config.ts`, `@open-slide/core`, and scripts such as `open-slide dev`, `open-slide build`, `open-slide preview`, or `open-slide sync:skills`.

Inspect `package.json` scripts before running commands. Prefer project-local scripts like `pnpm dev` or `pnpm build` over the global `open-slide` binary.

If the user wants a new workspace, suggest package-manager scaffolding such as `pnpm dlx @open-slide/cli init <dir>` or the equivalent for their package manager. Do not scaffold unless asked.

Known local context: the observed global CLI is `@open-slide/cli@1.0.2` at `/home/daofficialwizard/.local/share/pnpm/global/5/.pnpm/@open-slide+cli@1.0.2/node_modules/@open-slide/cli`, with shim `/home/daofficialwizard/.local/share/pnpm/open-slide`. Upstream is `https://github.com/1weiho/open-slide`, a pnpm/Turbo monorepo with `packages/cli`, `packages/core`, `apps/demo`, and `apps/web`. Observed upstream versions were CLI `1.2.4` and core `1.6.0`.

## Authority Order

This global skill is an opencode adapter. Project-bundled Open Slide skills are more specific and may be newer than this summary.

If present, read these first and treat them as authoritative over this skill:

- `.agents/skills/slide-authoring/SKILL.md`
- `.agents/skills/create-slide/SKILL.md`
- `.agents/skills/apply-comments/SKILL.md`
- `.agents/skills/create-theme/SKILL.md`
- `.agents/skills/current-slide/SKILL.md`
- Matching files under `.claude/skills/`

Translate any Claude-style `AskUserQuestion` instruction into opencode's `question` tool. The Open Slide project skills are managed by `@open-slide/core`; do not edit them in place unless the user explicitly asks.

## Core Model

Open Slide is a React/Vite slide framework, not a PowerPoint converter.

Decks live at `slides/<kebab-case-id>/index.tsx`. A deck module default-exports a non-empty ordered array of zero-prop React page components. Optional exports include `meta`, `design`, and `notes`.

Every page renders into a fixed `1920x1080` canvas; the framework scales it. Vite virtual modules discover slide folders and load deck modules. The runtime provides editor, viewer, presenter routes, inspector comments, a design panel, an assets manager, static build, standalone HTML export, and browser print-based PDF export.

## New Deck Workflow

Before writing code, ask only for missing decisions. If the topic is unclear, first gather topic, audience, and any outline/content.

Clarify these four decisions when not already clear: aesthetic direction, page count, text density, and motion. Propose aesthetic options tailored to the topic, not a generic preset list.

If `themes/*.md` exists, ask whether to use one. If selected, read it end-to-end and make its palette, typography, layout, components, and motion guidance authoritative.

Choose a short URL-safe kebab-case slide id and check for collisions under `slides/`. Plan page roles before code: cover, agenda, section divider, content, big number, quote, comparison, or closing. Keep one idea per page.

For new slides, include `meta.createdAt` as a plain ISO string literal. Immediately before writing the file, get the timestamp with `node -e "console.log(new Date().toISOString())"`; do not type it from memory and do not compute it inside the slide file.

## Editing Existing Slides

Read the target `slides/<id>/index.tsx` before editing. Preserve existing style, imports, component names, layout vocabulary, and visual direction unless the user asks for a redesign.

Keep a slide as one `index.tsx` plus optional `assets/`. Do not create sibling files such as `Card.tsx`, `helpers.ts`, `components/`, or `README.md` inside the slide folder.

For visually repeated inspector-editable elements such as cards, tiles, galleries, or logo rows, define a small component in the same `index.tsx` and instantiate it explicitly for each item. Avoid rendering those with `array.map(...)`, because the inspector edits one shared source body and can mutate every rendered instance at once. Plain literal `<li>` bullets are fine.

## Current Slide Workflow

When the user says `this slide`, `this page`, `this element`, `the current page`, or otherwise points deictically at the viewer, read `node_modules/.open-slide/current.json` fresh at the start of that turn. Never reuse a previous read across turns.

The JSON can contain `slideId`, `pageIndex`, `pageNumber`, `totalPages`, `slideTitle`, `view`, `pagePath`, `selection`, and `updatedAt`. Use `pagePath` for source edits and `pageIndex` to find the component in the default export array.

If `selection` is non-null, treat its line, column, tag, and text as the canonical element handle, then read surrounding source before editing. If `updatedAt` is older than roughly five minutes, older than the latest user interaction, or the file is missing, ask which slide/page they mean instead of guessing.

## File Contract

Canonical deck shape:

```tsx
import type { DesignSystem, Page, SlideMeta } from '@open-slide/core';

export const design: DesignSystem = {
  palette: { bg: '#0f172a', text: '#f8fafc', accent: '#fbbf24' },
  fonts: {
    display: 'system-ui, -apple-system, sans-serif',
    body: 'system-ui, -apple-system, sans-serif',
  },
  typeScale: { hero: 180, body: 40 },
  radius: 12,
};

const Cover: Page = () => (
  <div style={{ width: '100%', height: '100%' }}>Hello</div>
);

export const notes: (string | undefined)[] = [
  'Speaker note for page 1.',
];

export const meta: SlideMeta = {
  title: 'My slide',
  createdAt: '2026-05-20T00:00:00.000Z',
};

export default [Cover] satisfies Page[];
```

Rules: default export a non-empty `Page[]`; each component takes zero props; keep imports minimal; avoid browser-only side effects during static export unless guarded; do not add dependencies.

## Canvas And Layout Rules

Design as if the viewport is exactly `1920x1080`. The canvas does not scroll.

Use absolute pixels for type, spacing, and positioning. Avoid `rem`, `vw`, `vh`, and percentages for type. Each page root should fill `width: '100%'` and `height: '100%'`.

Prefer inline styles or tightly scoped CSS. Shared CSS is global and should only be used if the project already follows that pattern.

Use `100-160px` content padding. Typical type scale: hero `140-200px`, section heading `80-120px`, page heading `56-80px`, body `32-44px`, caption `22-28px`.

Calculate vertical budget before writing: `(font_size * line_height * lines) + gaps + top/bottom padding <= 1080`. If the page is tight, split it. Never use scrolling, negative margins, hidden overflow, tiny type, or cramped line-height to hide overflow.

Commit to one coherent visual direction across the deck. Avoid generic AI-looking layouts; preserve the project style unless the user asks for a new direction.

## Design System

Default new slides should export a top-level `design: DesignSystem` so the Design panel can tweak the deck after generation.

Use CSS variables for live design-panel updates: `var(--osd-bg)`, `var(--osd-text)`, `var(--osd-accent)`, `var(--osd-font-display)`, `var(--osd-font-body)`, `var(--osd-size-hero)`, `var(--osd-size-body)`, and `var(--osd-radius)`.

Use direct `design.X` reads only when JavaScript values are needed for arithmetic or labels. The design object must be a module-level literal: no spreads, helper calls, imports, computed values, or runtime expressions.

## Themes

Themes live as markdown under `themes/<id>.md`. They are authoring-time documentation, not executable runtime. A theme is distinct from a slide's runtime `design` const; both can coexist.

A good theme file defines frontmatter, palette, typography, layout, fixed paste-ready components, motion, aesthetic guidance, and example usage. When authoring a slide with a theme, copy the theme's palette/components into `slides/<id>/index.tsx` and still keep the per-slide `design` const if the deck should remain tweakable.

For page-number footers, import and use `useSlidePageNumber()` from `@open-slide/core`. Never hardcode page number props or totals in reusable footer components.

## Speaker Notes

Speaker notes are `export const notes: (string | undefined)[] = [...]`, index-aligned with the default export page array. Use `undefined` for pages without notes.

Presenter mode reads `slide.notes?.[index]`. Keep notes concise and audience-facing. Multi-line notes can use template literals; escape backticks and `${...}` when needed.

## Assets And Placeholders

Slide-local assets live under `slides/<id>/assets/` and are imported with relative ES imports:

```tsx
import hero from './assets/hero.jpg';
```

Reusable global assets live under root `assets/` and are imported via `@assets/...`:

```tsx
import logo from '@assets/logos/acme.svg';
```

Use `ImagePlaceholder` from `@open-slide/core` only when the deck genuinely needs concrete user-owned images such as a product screenshot, team photo, chart, customer logo, or dashboard. Do not use placeholders for decoration, stock-photo slots, icons, or generic visual interest. Do not add large binary assets without explicit approval.

## Inspector Comments

Inspector comments persist as JSX markers inside `slides/<id>/index.tsx`:

```text
{/* @slide-comment id="c-<8hex>" ts="<ISO>" text="<base64url(JSON)>" */}
```

Detection regex:

```text
/\{\/\*\s*@slide-comment\s+id="(c-[a-f0-9]+)"\s+ts="([^"]+)"\s+text="([A-Za-z0-9_\-]+={0,2})"\s*\*\/\}/g
```

Decode `text` as base64url JSON to `{ note, hint? }`. The marker's enclosing JSX element is the target. Read enough parent and sibling context to apply the smallest faithful edit.

Apply marker edits in reverse line order, then remove each marker line. If a marker cannot be resolved safely, leave it in place and report it as skipped.

## Commands And Validation

Inspect `package.json` first. Common scripts are `pnpm dev`, `pnpm build`, `pnpm preview`, and `pnpm sync:skills`.

Use `pnpm sync:skills --dry-run` or `pnpm exec open-slide sync:skills --dry-run` to preview project skill drift when relevant. Do not upgrade Open Slide dependencies unless explicitly requested.

Run lint, typecheck, or build only when available and appropriate for the requested change. Do not run a long-lived dev server unless the user asks.

For a deck validation pass, check that `slides/<id>/index.tsx` exists, imports resolve, default export is a non-empty page array, optional `meta`/`design`/`notes` match project conventions, assets exist, notes align to page count, repeated inspector-editable elements are explicit instances, and vertical layout fits `1080px`.

## Safety Rules

Do not edit global pnpm package installs under `/home/daofficialwizard/.local/share/pnpm/global/...` unless explicitly requested.

Do not modify `package.json`, `open-slide.config.ts`, other decks, generated build/export artifacts, or dependency versions during normal slide authoring unless explicitly requested.

Do not add dependencies. Slides should use React and standard web APIs unless the project already provides more.

Respect plan-mode or read-only requests. Preserve user-authored slide content, inspector markers that cannot be resolved, and existing deck conventions. Use minimal patches.

## Handoff Checklist

When finished, report the slide/theme id and file paths changed, validation commands and results, any assumptions made for ambiguous comments/current selection, remaining manual preview/export steps, and whether opencode must be restarted for skill/config changes.
