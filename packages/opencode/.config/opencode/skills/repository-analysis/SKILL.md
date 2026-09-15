---
name: repository-analysis
description: Analyze an unfamiliar repository or codebase and produce a useful first-look report. Use when the user asks for a repository overview, codebase analysis, architecture overview, or first look.
---

# Repository Analysis

Use this skill when the repository is unfamiliar or the user explicitly asks for a codebase overview.

## Workflow

1. Establish the project purpose, current state, and likely entry points.
2. Inspect the directory structure and identify the main application, library, service, or deployment boundaries.
3. Trace important flows from inputs to outputs, including key dependencies and external systems.
4. Identify non-obvious algorithms, state transitions, data boundaries, and operational assumptions.
5. Read representative source files and tests before making correctness claims.
6. Record uncertainty as `UNKNOWN` and name the smallest check that would resolve it.

## Report

Use only sections that the repository supports:

- Overview and intended use case
- Architecture and component interactions
- Code structure and conventions
- Key components and dependencies
- Important logic, algorithms, or data flows
- Testing and validation strategy
- Documentation quality
- Risks and focused improvement opportunities
- Short conclusion with the next useful investigation

Prefer a compact report grounded in inspected files over a generic inventory. Cite paths and symbols when they support a claim. Use a Mermaid diagram when it materially clarifies boundaries or flow, and keep it readable and high contrast.

## Boundaries

- Use codebase-memory first for repository-wide navigation when available, then LSP and exact file search fallbacks.
- Do not index home directories, vendor trees, build outputs, or unrelated repositories.
- Do not infer behavior from filenames alone.
- Do not expose hidden chain-of-thought; provide conclusions, evidence, uncertainty, and verification steps.
