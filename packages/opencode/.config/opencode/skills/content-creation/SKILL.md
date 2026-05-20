---
name: content-creation
description: Plan, write, design, and package content using Open Slide and Penpot MCP. Use when the user asks for content creation, presentations, slide decks, visual storytelling, social assets, landing-page mockups, campaign creative, brand/content systems, Penpot designs, or Open Slide deliverables.
---

# Content Creation

## When To Use

Use this skill when the user wants to create content artifacts, not just edit code. Typical outputs include Open Slide decks, Penpot design files, campaign concepts, visual narratives, social posts, thumbnails, landing-page mockups, product explainers, pitch materials, launch assets, and brand/content systems.

This skill orchestrates two production surfaces:

- Open Slide for presentation decks and executable React slide artifacts.
- Penpot MCP for visual design files, frames, layouts, comments, components, and collaborative review artifacts.

## First Principles

Start with the content job, not the tool. Identify the audience, goal, message, distribution channel, format, deadline, and success criterion before building artifacts.

Prefer concrete artifacts over abstract advice. If the user asks to create, write or design the content in the workspace or in Penpot instead of only describing what to do.

Maintain one clear creative direction. Do not mix unrelated visual languages. Avoid generic AI-looking layouts, vague corporate filler, and interchangeable templates.

## Authority Order

If the work involves an Open Slide deck, load or consult the `open-slide` skill first. In an Open Slide project, project-bundled skills under `.agents/skills/` or `.claude/skills/` are authoritative over this global skill.

If the work involves prose quality, structure, docs, or long-form technical writing, consult the `Technical Writing` skill.

If the work involves an existing brand/design system, read its local files first and preserve its vocabulary, typography, palette, spacing, and component patterns.

## Intake Checklist

Clarify only what is missing. Good defaults are acceptable when the user wants speed.

Required inputs:

- Goal: inform, persuade, teach, sell, onboard, announce, compare, or recap.
- Audience: technical depth, buyer/user persona, familiarity with the topic.
- Format: deck, Penpot mockup, social set, landing page, one-pager, script, article, or mixed package.
- Source material: notes, URLs, docs, screenshots, data, existing deck, brand assets, examples.
- Tone: executive, technical, editorial, playful, premium, founder-led, educational, direct.
- Delivery constraints: dimensions, page count, word count, platform, deadline, export needs.

If the user gives a thin request like `make content about X`, ask one compact question covering audience, output format, and desired style.

## Output Router

Choose the smallest useful artifact set:

- Slide deck: use Open Slide for talks, pitches, product explainers, training, roadmaps, workshops, and narrative documents that benefit from page-by-page pacing.
- Penpot file: use Penpot MCP for visual systems, mockups, social layouts, thumbnails, landing-page compositions, diagrams, design explorations, and reviewable visual artifacts.
- Text-only content: write markdown or repository docs when layout is secondary.
- Mixed package: create a written narrative first, then use Open Slide for presentation flow and Penpot for visual assets or companion mockups.

Do not force Penpot or Open Slide into work that only needs a short text answer.

## Open Slide Workflow

When the chosen output is a deck, follow the `open-slide` skill.

High-level sequence:

1. Detect the Open Slide project root by checking `package.json`, `slides/`, `open-slide.config.ts`, and `@open-slide/core`.
2. Read project-bundled Open Slide skills if present.
3. Clarify topic, audience, aesthetic direction, page count, text density, and motion if missing.
4. Choose a short kebab-case slide id.
5. Plan page roles before code: cover, agenda, section divider, content, comparison, big number, quote, closing.
6. Write `slides/<id>/index.tsx` with a non-empty default export array of zero-prop React page components.
7. Include `meta`, `design`, and `notes` when useful.
8. Validate imports, layout budget, assets, notes alignment, and available scripts.

Use the Open Slide fixed `1920x1080` canvas rules. Keep one idea per page. Split dense content instead of shrinking type or hiding overflow.

## Penpot MCP Workflow

Use Penpot MCP when the requested artifact needs a visual design canvas or collaborative design review.

Discovery flow:

1. Use `penpot_list_teams` to find available teams if the target team is unknown.
2. Use `penpot_list_projects` or `penpot_search_files` to locate the target project/file.
3. Use `penpot_list_pages`, `penpot_get_page_shapes`, or `penpot_query_shapes` to inspect existing structure before modifying.
4. Create snapshots with `penpot_create_file_snapshot` before substantial redesigns to preserve rollback points.

Creation flow:

1. Create a file with `penpot_create_file` when the user needs a new visual artifact.
2. Create pages for variants or deliverables with `penpot_add_page`.
3. Build layout with `penpot_create_frame`, `penpot_create_text`, `penpot_create_rectangle`, and `penpot_create_circle`.
4. Use consistent positions, sizes, names, colors, type styles, and hierarchy.
5. Use alignment/distribution tools for multi-shape layouts.
6. Add comments with `penpot_create_comment_thread` when the design needs review notes or user decisions.
7. Create a share link with `penpot_create_share_link` only when the user wants one.

Update flow:

1. Query existing shapes before bulk updates.
2. Use `penpot_update_shape` for precise edits.
3. Use `penpot_get_shape_properties` when changing an existing shape's visual language.
4. Avoid deleting or replacing user-created design work unless explicitly requested.

## Content Brief Pattern

Before writing or designing, produce a compact internal brief:

- Core promise: the single thing the audience should remember.
- Audience tension: what pain, opportunity, or confusion this resolves.
- Angle: the sharp point of view.
- Proof: data, examples, product details, screenshots, references.
- Structure: opening hook, main beats, close or CTA.
- Visual direction: palette, typography, layout motif, image strategy.

For larger pieces, share this brief with the user before building if major assumptions are unresolved. For small requests, use it internally and proceed.

## Writing Rules

Lead with a clear hook. Remove filler. Prefer concrete nouns, active verbs, and specific claims. Keep each section/page focused on one job.

Match density to medium:

- Slides: short lines, strong hierarchy, one idea per page.
- Social: immediate hook, scannable body, one CTA.
- Landing pages: headline, subhead, proof, objections, CTA.
- Product explainers: problem, mechanism, outcome, proof.
- Technical content: define terms, preserve accuracy, cite constraints.

Never invent facts, metrics, testimonials, customer names, logos, or product capabilities. Use placeholders or ask for source material when proof is missing.

## Visual Direction Rules

Pick one coherent aesthetic and carry it through every artifact. Define palette, typography, spacing, layout grid, image style, and accent motif.

Useful directions include editorial, technical blueprint, premium SaaS, founder memo, brutalist, soft/pastel, data-forward, retro, terminal, cinematic, and magazine-style. Tailor options to the topic instead of offering a fixed preset list.

For Penpot, name shapes and frames semantically. For Open Slide, define shared constants/components inside `slides/<id>/index.tsx` and keep the deck inspectable.

## Mixed Open Slide And Penpot Workflow

Use both tools when the content needs a deck plus designed source assets or reviewable visual explorations.

Recommended sequence:

1. Draft the content narrative and slide/page outline.
2. Use Penpot to create or refine visual assets, layout studies, diagrams, thumbnails, or brand explorations.
3. Use Open Slide to implement the final deck, importing exported assets only when the user has provided or approved them.
4. Keep source-of-truth clear: editable layout stays in Penpot; presentation execution stays in Open Slide.
5. Document remaining export/manual handoff steps.

Do not assume Penpot assets are automatically available in the local filesystem. If a deck needs images from Penpot, ask for an export path or use placeholders until assets are available.

## Review And Iteration

For existing content, review in this order:

1. Message clarity: audience, promise, proof, CTA.
2. Structure: sequence, pacing, repetition, missing context.
3. Visual hierarchy: contrast, scale, alignment, whitespace.
4. Medium fit: deck/page/social/platform constraints.
5. Production risks: missing assets, unverifiable claims, export blockers.

When applying feedback, make the smallest coherent change that satisfies the note. Preserve the existing creative direction unless the feedback asks for a pivot.

## Validation

For Open Slide outputs, use the `open-slide` skill's validation: default export array, imports, assets, notes alignment, `1920x1080` layout budget, and project scripts when appropriate.

For Penpot outputs, verify by querying the file/page after creation or update. Check shape count, key frame names, positions, text content, visual hierarchy, and share/comment status if relevant.

For text outputs, reread for unsupported claims, audience fit, tone consistency, and CTA clarity.

## Safety Rules

Do not mutate Penpot files without first identifying the correct team/project/file/page. For substantial Penpot edits, create a snapshot before changing the design.

Do not delete Penpot shapes, files, pages, comments, teams, members, or webhooks unless explicitly requested.

Do not edit global Open Slide package installs or upgrade Open Slide dependencies unless explicitly requested.

Do not add large binary assets, publish share links, or invite users without approval.

Do not fabricate sources, metrics, legal claims, medical claims, financial claims, customer quotes, or brand approvals.

## Handoff Checklist

End with the artifacts created or changed, where they live, validation performed, assumptions made, and remaining user actions.

For Open Slide, include slide id/path and preview/build notes. For Penpot, include file/page/frame names and share link if one was created. For mixed work, explain which tool owns which part of the source of truth.
