# Engineering Design Document: Debian Resolution Engine

## Status

Implementation hand-off document for the next agent.

## Summary

Build one compiled Rust tool that owns Debian package planning, verification, and Arch-to-Debian mapping without replacing the current shell installer or TOML manifest.

Recommended binary name:

- `pkgsolve`

Recommended command structure:

- `pkgsolve resolve`
- `pkgsolve verify`
- `pkgsolve map`

## Context To Read First

The implementation agent should study these files before writing code:

- `scripts/install/deps.manifest.toml`
- `scripts/install/install-deps.sh`
- `install.sh`
- `scripts/lib/manifest-toml.sh`
- `README.md`
- `tests/vm/debian-headless/README.md`
- `docs/design/install-elevation.md`

Why they matter:

- `deps.manifest.toml` defines the source package intent and bundle composition.
- `install-deps.sh` shows current manager adapters and bundle execution flow.
- `install.sh` shows where Debian planning must eventually be inserted.
- `manifest-toml.sh` shows existing manifest parsing assumptions.
- `README.md` and Debian smoke docs define the currently supported Debian flow.

## Design Principles

1. Keep the manifest as the package intent source of truth.
2. Move Debian package reasoning into a compiled binary, not more shell.
3. Use APT as the final verifier.
4. Separate package translation from package installation.
5. Emit artifacts for both success and failure.
6. Prefer deterministic plans over implicit package-manager heuristics.

## Proposed Directory Layout

Recommended implementation root:

```text
tools/pkgsolve/
  Cargo.toml
  src/
    main.rs
    cli.rs
    model/
      mod.rs
      package.rs
      version.rs
      constraint.rs
      lockfile.rs
      artifact.rs
    manifest/
      mod.rs
      bundle.rs
      input.rs
    debian/
      mod.rs
      universe.rs
      packages_index.rs
      release.rs
      versioning.rs
      local_deb.rs
      policy.rs
    arch/
      mod.rs
      input.rs
      mapping.rs
      capabilities.rs
    solver/
      mod.rs
      resolve.rs
      relax.rs
      explain.rs
    verify/
      mod.rs
      apt_sim.rs
      policy_check.rs
      local_deb_check.rs
    output/
      mod.rs
      lock_json.rs
      unsat_json.rs
      trace_json.rs
      apt_txt.rs
      preferences.rs
```

## Integration Boundary

Do not replace `install-deps.sh`.

Instead, make `install-deps.sh` a future caller of `pkgsolve` for Debian-only preflight:

1. manifest/bundle intent is gathered in shell
2. `pkgsolve resolve` creates a plan
3. `pkgsolve verify` validates the plan
4. shell either aborts or installs from the verified plan

The Arch-to-Debian mapper stays out of the install path.

## Command Contracts

### `pkgsolve resolve`

Purpose:

- produce a Debian package plan from manifest intent or direct package input

Example:

```bash
pkgsolve resolve \
  --manifest scripts/install/deps.manifest.toml \
  --bundle minimal \
  --platform debian \
  --snapshot bookworm@2026-03-22T00:00:00Z \
  --out .artifacts/pkgsolve/debian
```

Inputs:

- manifest path
- bundle name or explicit request file
- optional lockfile
- optional pin file
- optional snapshot definition
- optional local `.deb` manifest
- strict or best-effort mode

Outputs:

- `plan.lock.json`
- `plan.trace.json`
- `plan.unsat.json`
- `plan.apt.txt`
- `plan.preferences`

### `pkgsolve verify`

Purpose:

- confirm that a generated plan is valid in the selected APT universe

Example:

```bash
pkgsolve verify \
  --plan .artifacts/pkgsolve/debian/plan.lock.json \
  --out .artifacts/pkgsolve/debian-verify
```

Checks:

- package availability
- version availability
- origin/pin compatibility
- local `.deb` metadata integrity
- `apt-get -s` success

### `pkgsolve map`

Purpose:

- translate Arch package artifacts into Debian intent artifacts

Example:

```bash
pkgsolve map \
  --arch-input arch-packages.txt \
  --snapshot bookworm@2026-03-22T00:00:00Z \
  --best-effort \
  --out .artifacts/pkgsolve/arch-map
```

Outputs:

- Debian request artifact
- mapping trace
- unsatisfied mappings
- optional generated lock/pin templates

## Core Data Model

### Package Atom

Every candidate should be modeled at package-version granularity.

Suggested fields:

- package name
- version
- architecture
- source/origin
- repository component
- snapshot identifier
- provides
- depends
- conflicts
- breaks
- recommends
- local `.deb` metadata

### Goal

Requested install intent should be modeled separately from package atoms.

Suggested fields:

- goal id
- requested package or capability
- source of request
- strict or relaxable
- preferred version range
- preferred origin
- mapped-from Arch package if applicable

### Resolution Result

Suggested result states:

- satisfiable
- partially satisfiable
- unsatisfiable

## Solver Model

This is not just a boolean SAT problem.

It is closer to:

- hard constraint satisfaction
- plus soft-goal relaxation for best-effort output

Required hard constraints:

- dependency closure
- version constraints
- package conflicts/breaks
- lockfile exact pins
- snapshot membership
- local `.deb` integrity rules

Required soft constraints:

- requested top-level goals
- preferred exact package mappings
- preferred repository origin
- preferred version

### Implementation Guidance

The implementation agent may:

- use an existing Rust SAT or constraint library if it fits the model cleanly
- or implement a dedicated solver layer with iterative relaxation

Do not let library choice distort the product behavior.

The required behavior matters more than whether the engine is backed by classical SAT, PB-SAT, or a custom dependency resolver with unsat explanation.

## Artifact Schemas

### `plan.lock.json`

Minimum fields:

- package
- version
- origin
- component
- snapshot
- requested-by
- mapped-from
- local-deb checksum if applicable

### `plan.unsat.json`

Minimum fields:

- requested goal
- failure class
- message
- searched candidates
- violated constraints
- dropped in best-effort: true/false

### `plan.trace.json`

Minimum fields:

- mapping decisions
- lock and pin decisions
- snapshot selected
- dropped goals
- candidate pruning events
- final plan summary

### `plan.apt.txt`

Human-readable install list suitable for debugging and review.

### `plan.preferences`

Generated APT preferences content for pinning verification and later install use.

## Arch-to-Debian Mapping Design

Mapping should occur in layers:

1. exact name mapping
2. explicit repo-specific mapping
3. capability mapping
4. family or split/combined package mapping
5. unsupported/manual classification

Example mapping classes:

- exact: `bat` -> `bat`
- renamed: `fd` -> `fd-find`
- repo naming drift: `github-cli` -> `gh`
- unsupported: AUR-only package with no Debian equivalent
- local-deb candidate: package must be supplied as `.deb`

The mapper should never silently discard an input goal.

If something cannot be mapped, it must land in the unsatisfied artifact.

## Lockfiles, Pins, Snapshots

### Lockfiles

Lockfiles should be explicit and stable.

Recommended first format:

- JSON

Reason:

- easier for other agents and CI tools to inspect
- better fit for rich nested artifact output

### Pins

The tool should produce both:

- an internal pin model
- an APT preferences artifact

### Snapshots

Snapshots should constrain the package universe before solving, not after.

The first implementation may support:

- explicit snapshot URL definitions
- explicit repo metadata directory inputs

Later support may add:

- logical snapshot aliases

### Local `.deb`

Local `.deb` support must include:

- path
- checksum
- package metadata extraction
- dependency and conflict contribution into the universe

## APT Verification Layer

APT remains the final authority.

The solver may say a plan is valid, but `verify` must still confirm with:

- `apt-get -s`
- `apt-cache policy`
- repository origin checks
- local `.deb` validation

If custom solving and APT verification disagree, verification wins and the disagreement must be recorded.

## Testing Strategy

### Unit Tests

- Debian version comparison
- mapping rules
- lockfile parsing
- pin evaluation
- unsat explanation formatting

### Fixture Tests

- miniature Debian package universes
- conflict scenarios
- missing package scenarios
- pinned version mismatch scenarios
- snapshot mismatch scenarios
- local `.deb` dependency scenarios

### Integration Tests

- resolve from current `deps.manifest.toml` minimal Debian bundle
- verify the produced plan against test repository metadata
- run best-effort mode and confirm unsatisfied artifact emission
- map sample Arch exports to Debian artifacts

### Repo-Level Follow-On Integration

Once the tool exists, add tests that:

- run `pkgsolve resolve` for the Debian headless path
- run `pkgsolve verify`
- fail CI if strict mode resolution fails unexpectedly

## Delivery Phases

### Phase 1: Verifier-first foundation

Deliver:

- binary skeleton
- manifest/bundle input support
- Debian universe loading
- availability checks
- artifact generation
- `verify` via APT simulation

This phase gives immediate fail-early value without requiring full SAT sophistication.

### Phase 2: Constraint solver core

Deliver:

- package-version resolution
- dependency/conflict reasoning
- lockfile support
- pin support
- snapshot-aware resolution

### Phase 3: Best-effort relaxation

Deliver:

- soft-goal dropping
- unsatisfied residue artifact
- explainability for dropped goals

### Phase 4: Arch-to-Debian mapper

Deliver:

- exported Arch package input support
- exact and capability-based mapping
- Debian intent artifact output
- mapping failure artifact

## Risks

- Debian version semantics are easy to get subtly wrong.
- Reproducing APT behavior exactly is not realistic in phase one.
- Repository metadata ingestion can become the dominant complexity if scope is not constrained.
- Mapping quality will be uneven at first without a curated mapping table.

## Risk Mitigations

- Use APT as final verifier.
- Keep mapper outside install path.
- Start with deterministic fixture universes before live repository complexity.
- Separate strict mode from best-effort mode clearly in both logic and UX.

## Explicit Build Guidance For The Next Agent

Do this first:

1. create the Rust binary skeleton
2. model manifest and bundle inputs
3. define output artifact schemas
4. implement Debian universe ingestion for a constrained metadata source
5. implement verification

Do not do this first:

- full live repository crawling across every Debian variant
- desktop/runtime package behavior modeling
- AUR compatibility emulation
- deep shell integration
