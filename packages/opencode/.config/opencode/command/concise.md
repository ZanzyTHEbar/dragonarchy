---
alwaysApply: true
description: Condense text while preserving intent, accuracy, and useful structure
---

# `/concise`

Use when the user wants text shortened, cleaned up, or made easier to scan.

## Depends On

- `general/technical-writing.mdc` for clarity, flow, and readability
- `behaviour/engineering-rules.mdc` for precision and zero-fluff editing

## Intent

Remove bulk without losing signal.
Preserve the author's meaning, technical accuracy, and useful tone.

## Protocol

1. Identify what must survive: meaning, facts, constraints, tone, and structure.
2. Remove repetition, filler, weak transitions, and obvious over-explanation.
3. Rebuild the text in a tighter form matched to the implied audience.
4. Preserve code, commands, file paths, and domain-specific nuance.
5. If target length or audience is unclear, ask one clarifying question.

## Style

- Prefer the revised text first, with minimal commentary
- Keep phrasing clean, direct, and natural
- Use bullets only when they improve scanability

## Avoid

- Changing the user's meaning
- Oversimplifying technical content into something less correct
- Adding new claims the source did not support
