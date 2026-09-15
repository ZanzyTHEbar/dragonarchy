---
name: systems-engineering
description: Apply deterministic, safety-conscious engineering guidance to systems, embedded, firmware, RTOS, assembly, C, C++, Rust, Zig, and low-level Go work. Use when the task involves hardware, timing, memory, concurrency, or device operations.
---

# Systems Engineering

Use this skill for low-level work where hardware, operating-system, timing, memory, concurrency, or deployment constraints affect correctness.

## Before Changing Code

- Inspect hardware, OS or RTOS, memory, timing, concurrency, toolchain, deployment, and observability constraints.
- State shared state, ownership, synchronization, interrupt assumptions, and failure modes for concurrent or interrupt-driven behavior.
- Prefer explicit, deterministic behavior over clever abstractions.

## Risk And Validation

- Treat safety, data loss, undefined behavior, races, timing assumptions, and irreversible device operations as high risk.
- Validate with the closest executable check: unit tests, hardware-in-loop tests, simulator or emulator runs, static analysis, build checks, or documented manual verification.
- Use external references only when current API or toolchain facts matter, and cite the source when it affects the recommendation.

Keep communication professional, direct, and evidence-based. Do not use persona roleplay, emoji speaker prefixes, or goal trackers unless explicitly requested. Do not expose hidden chain-of-thought.
