# Tier And Version Reference

## Tier-0: Commercial Products

Meaning:

- market-facing product names

Versioning:

- no external semantic versioning
- internally, refer to the underlying Tier-1 platform version when needed

## Tier-1: Products

Format:

- `Generation.Major/Minor`

Use when:

- describing the main product generation and product-level change scope

Examples:

- `Origin 1.0/4`
- `Vertex 2.0/0`

## Tier-2: Sub-Products

### Robotic Platforms

Format:

- `Generation.Major.Minor.Patch`

Use when:

- the tier is the robotic platform itself

Interpretation:

- generation and major reflect large platform changes
- minor reflects backward-compatible functional additions
- patch reflects small fixes or invisible fit, form, function changes

### Other Tier-2 Products

Format:

- `Major.Minor.Patch`

Use when:

- the tier is a non-platform Tier-2 sub-product such as software or a major additional component

Interpretation:

- major: incompatible interface change
- minor: backward-compatible functional addition
- patch: small fix

## Tier-3: Modules

Format:

- `Major.Minor.Patch`

Interpretation:

- major: incompatible interface change
- minor: backward-compatible functional addition
- patch: small fix

## Writing Guidance

- Always state the tier if the audience could confuse product, sub-product, and module language.
- When describing impact, tie the wording to compatibility, not only size.
- When in doubt, show one concrete naming example in the document.
