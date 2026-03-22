# `pkgsolve`

`pkgsolve` is the Debian resolution engine for this repo.

It is a compiled Rust tool with three commands:

- `pkgsolve resolve`
- `pkgsolve verify`
- `pkgsolve map`

It keeps `scripts/install/deps.manifest.toml` as the package-intent source of truth, emits stable artifacts, and uses APT as the final verifier.

## Build

```bash
./scripts/tools/build-pkgsolve.sh
```

The resulting binary will be at:

```bash
tools/pkgsolve/target/release/pkgsolve
```

## Local Development

Format:

```bash
./scripts/tools/fmt-pkgsolve.sh
```

Format check:

```bash
./scripts/tools/fmt-pkgsolve.sh --check
```

The formatter helper avoids the broken local `cargo-fmt`/`rustfmt` proxy path by using the toolchain binary directly and falling back to Docker when needed.

Lint:

```bash
cargo clippy --manifest-path tools/pkgsolve/Cargo.toml --all-targets --all-features -- -D warnings
```

Test:

```bash
cargo test --manifest-path tools/pkgsolve/Cargo.toml
```

## Resolve Example

```bash
tools/pkgsolve/target/release/pkgsolve resolve \
  --manifest scripts/install/deps.manifest.toml \
  --bundle minimal \
  --platform debian \
  --manager apt \
  --out .artifacts/pkgsolve/resolve
```

## Verify Example

```bash
tools/pkgsolve/target/release/pkgsolve verify \
  --plan .artifacts/pkgsolve/resolve/plan.lock.json \
  --out .artifacts/pkgsolve/verify
```

## Map Example

```bash
tools/pkgsolve/target/release/pkgsolve map \
  --arch-input tools/pkgsolve/tests/fixtures/arch/packages.txt \
  --best-effort \
  --out .artifacts/pkgsolve/map
```

## Artifacts

`resolve` and `verify` emit:

- `plan.lock.json`
- `plan.unsat.json`
- `plan.trace.json`
- `plan.apt.txt`
- `plan.preferences`

`map` emits:

- `plan.requests.json`
- `plan.unsat.json`
- `plan.trace.json`

## Current Scope

The implementation is verifier-first:

- native manifest and bundle ingestion
- Debian metadata loading from local `Packages` indexes
- system APT candidate lookup
- strict and best-effort planning via APT simulation
- lockfile and pin ingestion
- local `.deb` metadata and checksum checks
- Arch-to-Debian request mapping

The shell installer remains the orchestration layer.
