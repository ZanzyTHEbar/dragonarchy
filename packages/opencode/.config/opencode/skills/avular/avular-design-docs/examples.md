# Design Examples

Use these examples to calibrate how much design is enough.

## Small Change: No Formal Design

Scenario:

- local bug fix in one component
- no interface changes
- verification is obvious

Expected output:

- no formal design doc
- brief implementation note in the PR or issue if needed

## Medium Change: Minimal Design Doc

Scenario:

- one feature across multiple components
- one or two interface changes
- stakeholder review needed before implementation

Expected sections:

- Objective
- Scope
- Context
- Requirements and assumptions
- Proposed design
- Verification strategy
- Open questions

## Large Change: Extended Design Doc

Scenario:

- architecture changes
- multiple systems or repositories involved
- major non-functional trade-offs

Expected additions:

- diagrams
- alternatives considered
- risks and failure handling
- maintainability or performance considerations

## Review Heuristic

If the reviewer's likely first question is "why this design?" then write the design.

If the likely first question is only "did it work?" then a design doc is probably overkill.
