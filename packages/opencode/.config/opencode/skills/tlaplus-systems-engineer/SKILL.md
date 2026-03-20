---
name: tlaplus-systems-engineer
description: Specify and verify concurrent, distributed, and agentic systems with TLA+, PlusCal, TLC, Apalache, and TLAPS. Covers state-machine modeling, invariants, fairness, counterexample analysis, refinement, and state-space explosion control. Use when the user mentions TLA+, TLA, TLC, PlusCal, Apalache, formal verification, model checking, concurrency, distributed protocols, nondeterminism, invariants, liveness, fairness, or wants to verify a design before writing code.
---

# TLA+ Systems Engineering

Use this skill when the problem is behavioral correctness, not syntax or implementation detail.
Think like a formal methods engineer: extract the state machine, bound the model, verify safety first, and only then translate the verified design into code.

## What This Skill Does

- Turns requirements, pseudocode, or source code into an abstract TLA+/PlusCal model
- Defines `Init`, named sub-actions, `Next`, `TypeOK`, safety invariants, and liveness properties
- Uses `TLC` for finite exhaustive search, simulation for cheap exploration, and `Apalache`/`TLAPS` when exhaustive TLC is the wrong tool
- Detects and mitigates state-space explosion before it wastes time
- Interprets counterexamples as design bugs, missing assumptions, or over-strong properties
- Maps verified specs back into implementation plans and runtime assertions

## Operating Rules

1. Model the system, the environment, and the scheduler separately.
2. Abstract aggressively. If a detail does not affect the property, remove it.
3. Bound everything for TLC: finite constants, small sets, short sequences, explicit limits.
4. Write `TypeOK` early. Many "behavior" bugs are malformed state.
5. Define small named sub-actions, then compose `Next` from them.
6. Add fairness only after safety is stable.
7. Apply fairness to specific actions when possible; `WF_vars(Next)` is often too coarse.
8. Treat state-space explosion as a modeling problem first and a tooling problem second.
9. When a step is too atomic, split it with a program counter or PlusCal labels.
10. Keep the spec more abstract than the code; refinement should add detail, not change intent.

## Quick Start

1. Identify:
   - system actors and processes
   - shared state
   - environment actions and failures
   - safety invariants
   - liveness expectations
2. Choose representation:
   - Use `PlusCal` for algorithmic workflows, retries, loops, and process-local control flow.
   - Use raw `TLA+` for declarative protocols, relation-heavy state, or highly abstract specs.
3. Build the skeleton:

```tla
---- MODULE Spec ----
EXTENDS Integers, FiniteSets, Sequences, TLC
CONSTANTS ...
VARIABLES ...

vars == <<...>>
TypeOK == ...
Init == ...
ActionA == ...
ActionB == ...
Next == ActionA \/ ActionB
Spec == Init /\ [][Next]_vars
====
```

4. Add the smallest useful model:
   - `N = 2`, not `N = 10`
   - a two-message queue, not an unbounded history
   - two agents and one adversarial environment step
5. Run TLC or simulation.
6. If TLC explodes, reduce state width before touching liveness.
7. Once safety holds, add fairness and liveness.
8. Only then translate to production code.

## Core Workflows

### 1. Modeling a New System

1. Restate the system boundary in plain English.
2. Extract actors, shared state, environment actions, and failure modes.
3. Choose `PlusCal` or raw `TLA+` based on control-flow vs protocol shape.
4. Write `TypeOK`, `Init`, named sub-actions, `Next`, and `Spec`.
5. Run the smallest useful TLC model first.
6. Check safety before any liveness work.

### 2. Debugging a Counterexample

1. Explain the trace as a short story.
2. Identify the first irreversible bad transition.
3. Classify the issue as a design bug, missing assumption, bad abstraction, or overly strong property.
4. Apply the smallest fix that preserves the original intent.
5. Re-run TLC before changing anything else.

### 3. Recovering from State Explosion

1. Shrink constants and domains.
2. Remove irrelevant payload detail.
3. Replace ordered structures when order is not part of the property.
4. Split oversized actions with `pc` or PlusCal labels.
5. Add symmetry or checker reductions only after the model itself is clean.
6. Move to simulation or `Apalache` only if the abstraction is already disciplined.

### 4. Translating a Verified Spec into Code

1. Map each state variable to an implementation state holder.
2. Convert invariants into assertions, validations, or tests.
3. Preserve guards and preconditions explicitly.
4. Document fairness assumptions as operational dependencies, not code guarantees.
5. Call out what the spec intentionally did not model.

## Decision Guide

### Choose the representation

- Use `PlusCal` when the user describes steps, labels, retries, loops, or per-process programs.
- Use raw `TLA+` when the user describes relations, constraints, ownership, messages, or protocol states.

### Choose the checker

- Use `TLC` for finite, explicit-state bug hunting and invariant checking.
- Use TLC simulation when the model is too large for exhaustive search but you still want fast counterexample hunting.
- Use `Apalache` for bounded symbolic checking, arithmetic-heavy models, or larger parameter spaces.
- Use `TLAPS` when the property must hold beyond any reasonable finite instance and you need proof, not search.

## State-Space Explosion Playbook

When TLC starts drowning in states, do these in order:

1. Shrink constants and domains.
2. Replace data payloads with symbolic tags.
3. Replace sequences with sets when order is irrelevant.
4. Model one shared resource instead of many equivalent copies.
5. Add symmetry where processes are interchangeable.
6. Split oversized actions with `pc`.
7. Add state constraints only if they preserve the behaviors relevant to the property.
8. Move from exhaustive TLC to simulation or Apalache only after the model is already clean.

## Output Standards

### Spec Brief

```markdown
## TLA+ Spec Brief

- System: [what is being modeled]
- Actors: [processes, environment, scheduler]
- State: [variables and meaning]
- Safety: [invariants]
- Liveness: [eventual properties]
- Abstractions: [what was intentionally omitted]
- Model bounds: [constants and limits]
```

### Counterexample Report

```markdown
## Counterexample Report

- Property violated: [invariant or liveness condition]
- Short trace story: [plain-English explanation]
- First bad transition: [which action caused divergence]
- Root cause: [design error vs missing assumption vs overly strong property]
- Fix options: [1-3 concrete changes]
```

### Translation Plan

```markdown
## Verified-to-Code Plan

- Preserved state variables: [spec -> code mapping]
- Preserved invariants: [assertions and guards to keep]
- Concurrency assumptions: [scheduler, retries, timeouts]
- Gaps not modeled: [I/O, latency, auth, persistence details]
```

## Companion Skills

If official TLA+ companion skills are installed, use them as focused helpers:

- `tlaplus-from-source` for extracting a first model from code
- `tlaplus-split-action` for reducing atomicity and clarifying interleavings
- `tlaplus-add-variable` for safe spec extensions

The TLA+ VS Code/Cursor extension is also useful for syntax, TLC integration, and MCP-backed knowledge if available.

## Progressive Disclosure References

- [tla-foundations.md](tla-foundations.md): semantics, stuttering, fairness, refinement, and the mental model behind TLA+
- [verification-workflow.md](verification-workflow.md): TLC internals, simulation, Apalache, TLAPS, model configs, and trace interpretation
- [modeling-patterns.md](modeling-patterns.md): reusable patterns for queues, locks, retries, `pc`-based actions, message passing, and symmetry
- [agentic-systems.md](agentic-systems.md): how to model LLM agents, tool calls, human approvals, partial failure, and verified code generation
