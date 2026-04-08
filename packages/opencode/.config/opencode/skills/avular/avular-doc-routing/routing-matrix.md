# Routing Matrix

Use this order of questions.

## 1. Is it a formal deliverable?

Examples:

- project or product deliverables
- released binaries
- software-related development documentation that belongs with source

Route to:

- repository for software source and software development documentation
- PLM for formal non-repo deliverables and controlled release artifacts

## 2. Is it a process artifact?

Examples:

- minutes of meeting
- planning items
- bug reports
- review follow-ups

Route to:

- Jira and Confluence

## 3. Is it shared knowledge for a team or the company?

Examples:

- engineering guidance
- how-to documents
- cross-team reference material

Route to:

- Confluence

If the source file must live elsewhere, store the source in its system of record and link to it from Confluence.

## 4. Is it a limited-scope working file?

Examples:

- personal notes
- temporary drafts
- limited confidential collaboration material

Route to:

- local or OneDrive-based working storage, only when it is not yet a formal, process, or shared artifact

## Engineering-Specific Rules

- Repository: code, README, design docs that must evolve with code, scripts, and engineering-local reference docs.
- Jira or Confluence: meeting minutes, planning decisions, issue workflows, review process tracking.
- PLM: formal product and controlled deliverables.
- SharePoint: supporting documents that must be shared broadly but do not belong in the repo and are not best managed as process pages.

## Quick Examples

- A software design doc that must stay versioned with code: repository
- Minutes of a design review meeting: Jira or Confluence
- A formal released deliverable package: PLM
- A broad team-facing how-to that references external files: Confluence with links to the source files

## Anti-Patterns

- storing a design doc in both the repo and Confluence as separate editable masters
- putting formal deliverables in ad hoc personal storage
- putting process tracking into the repo when Jira already owns the workflow
