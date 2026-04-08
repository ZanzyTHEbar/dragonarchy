---
name: avular-doc-routing
description: Route engineering artifacts to the correct Avular system of record. Use when deciding whether information belongs in the repository, Jira or Confluence, PLM, or SharePoint, and when linking related documentation across systems.
---

# Avular Document Routing

Use this skill when the main question is where an engineering artifact belongs.

## Workflow

1. Determine whether the artifact is a formal deliverable, a process artifact, shared knowledge, or a limited-scope working file.
2. Route the artifact to the system of record using the routing matrix.
3. If the artifact lives outside the repo, add a stable link from the engineering context that depends on it.
4. Avoid duplicate source-of-truth copies.

## Guardrails

- Formal deliverables need controlled storage.
- Process artifacts belong with the process tools.
- Shared knowledge should be discoverable by the intended audience.
- Do not store the same artifact as an editable source in multiple systems.

## Output

- The correct system of record
- Why that location fits
- Any required cross-links

## Additional Resource

- Routing matrix: [routing-matrix.md](./routing-matrix.md)
