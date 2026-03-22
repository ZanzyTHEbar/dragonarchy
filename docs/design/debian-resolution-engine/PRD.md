# Product Requirements Document: Debian Resolution Engine

## Status

Proposed hand-off specification for a follow-on implementation agent.

## Purpose

Introduce a compiled Debian package resolution toolchain that:

- fails early and clearly on unsatisfied Debian package requests
- verifies Debian install plans before mutating the host
- supports best-effort resolution with explicit unsatisfied artifacts
- enables a separate Arch-to-Debian mapping workflow for cloning Arch-oriented setups into Debian-oriented artifacts

This work is intended to strengthen the Debian path without turning the shell installer into a package solver.

## Problem Statement

The current Debian path is manifest-driven and adapter-driven, but it still relies on shell-time package existence checks and APT behavior during installation. That creates three gaps:

1. There is no dedicated satisfiability planning step for Debian package sets.
2. Failure output is too close to the install action instead of being surfaced as a standalone planning artifact.
3. There is no clean external tool for translating Arch package artifacts into Debian artifacts in a deterministic, reviewable way.

## Context Sources

The implementation agent should read these first:

- `scripts/install/deps.manifest.toml`
- `scripts/install/install-deps.sh`
- `install.sh`
- `scripts/lib/manifest-toml.sh`
- `README.md`
- `tests/vm/debian-headless/README.md`
- `docs/design/install-elevation.md`

These files define the current package model, bundle composition, Debian/headless path, and validation expectations.

## Users

Primary users:

- the Debian install path in `install.sh`
- CI and local validation workflows for Debian
- maintainers who need a clear artifact explaining why a Debian install set is or is not satisfiable
- maintainers who want to translate Arch package inputs into Debian install artifacts

Secondary users:

- future automation agents that need deterministic inputs and outputs
- future lockfile and snapshot workflows

## Goals

1. Provide a compiled preflight resolver for Debian package intent.
2. Produce explicit machine-readable and human-readable artifacts for satisfiable and unsatisfiable inputs.
3. Keep the Arch-to-Debian mapper outside the runtime install path.
4. Preserve the current manifest-driven package model instead of replacing it with a second source of truth.
5. Make APT the final verifier, not the first place a human discovers breakage.

## Non-Goals

- Replace APT with a custom installer.
- Rebuild the entire Arch package path around the new tool.
- Support desktop session modeling, GUI package runtime validation, or Hyprland behavior in phase one.
- Solve arbitrary package ecosystems beyond Debian-family repositories plus local `.deb` inputs.
- Introduce Python or any interpreter dependency at runtime.

## Hard Constraints

- Runtime language cannot require an interpreter.
- Design must be clean, direct, and auditable.
- Unsatisfied requests must be clearly emitted to artifacts.
- Best-effort mode must continue with satisfiable subsets while preserving unsatisfied residue.
- Mapping workflow must remain separate from the install path.

## Product Shape

The expected product is one compiled binary with three subcommands:

- `resolve`
- `verify`
- `map`

The implementation language should be Rust.

## Functional Requirements

### FR-1: Debian Resolve

The tool must accept Debian intent from:

- manifest + bundle selections from `deps.manifest.toml`
- direct package request files
- future lockfile inputs

The tool must:

- load the Debian package universe
- model versioned dependencies and conflicts
- detect missing packages and unsatisfied constraints
- emit a plan artifact when satisfiable
- emit an unsatisfied artifact when fully or partially unsatisfied

### FR-2: Debian Verify

The tool must verify a previously emitted Debian plan by:

- checking package availability in the declared repository context
- checking pinned version compatibility
- checking local `.deb` availability and metadata
- simulating the install via APT mechanisms such as `apt-get -s`

### FR-3: Best-Effort Mode

The tool must support a best-effort resolution mode that:

- keeps hard constraints intact
- relaxes soft goals when required
- emits a maximal satisfiable subset
- emits all dropped or unsatisfied requests to a dedicated artifact

### FR-4: Arch-to-Debian Mapper

The tool must support a separate mapping workflow that:

- accepts Arch artifacts such as exported package lists
- translates them into Debian intent artifacts
- records exact mappings, fallback mappings, and failed mappings
- does not install anything

### FR-5: Lockfiles and Pinning

The tool must support:

- exact version locks
- repository pinning
- local `.deb` references with checksums
- snapshot-aware repository selection

### FR-6: Artifact Output

The tool must emit stable artifacts under an output directory, including:

- resolved plan
- unsatisfied items
- trace/debug artifact
- APT-oriented install artifact
- lockfile artifact
- pin/preferences artifact

## Expected Artifacts

Required outputs:

- `plan.lock.json`
- `plan.apt.txt`
- `plan.preferences`
- `plan.trace.json`
- `plan.unsat.json`

Optional outputs:

- `plan.sources.list`
- `plan.snapshot.json`
- `plan.local-debs.json`

## User Experience Requirements

The tool must:

- fail fast in strict mode
- explain failures with package-level precision
- show exactly which goals were dropped in best-effort mode
- make artifact paths obvious in stdout
- keep shell integration thin and predictable

## Integration Requirements

### Install Path

The Debian install path should eventually do this:

1. Resolve requested Debian package intent.
2. Verify the resulting plan.
3. Abort in strict mode if verification fails.
4. Continue in best-effort mode only with the satisfiable subset.
5. Persist unsatisfied artifacts for review.

### Mapping Path

The Arch-to-Debian mapper must remain external to `install.sh` and `install-deps.sh`.

## Success Criteria

The design is successful when the implementation agent can deliver:

- deterministic Debian plan generation from current manifest inputs
- explicit unsat artifacts for broken Debian inputs
- APT-backed verification before host mutation
- a usable Arch-to-Debian mapping pass that produces reviewable Debian artifacts
- no runtime dependency on Python or another interpreter

## Acceptance Criteria

- A compiled Rust binary exists and runs on Debian and Arch-family hosts used by this repo.
- The binary exposes `resolve`, `verify`, and `map`.
- Strict mode aborts on unsatisfied Debian plans before package installation.
- Best-effort mode produces both a reduced install plan and an unsatisfied artifact.
- Mapping mode can ingest at least exported Arch package lists and emit Debian artifacts.
- The implementation does not replace the existing manifest as the source of package intent.

## Open Questions For Implementation

- Which repository metadata ingestion format should be first-class in phase one: local `Packages` indices, live APT metadata, or both?
- Should lockfile format be JSON or TOML?
- Should snapshot references be represented as exact URLs, logical labels, or both?
- Should local `.deb` references be accepted only via explicit input files or also discovered from directories?
