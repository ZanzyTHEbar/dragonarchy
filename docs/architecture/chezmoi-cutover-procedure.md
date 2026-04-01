# Chezmoi Cutover Procedure

## Purpose

This document defines how a user-state path moves from Stow ownership to generated chezmoi ownership without changing canonical source content.

For the operator-facing first-host sequence, use:

- `docs/runbooks/first-host-chezmoi-cutover.md`

## Preconditions

A path is eligible for cutover only when all of the following are true:

1. canonical source content lives in `packages/` or `hosts/<host>/dotfiles/`
2. the path is produced by a generated-source manifest
3. no setup script still rewrites the path after install
4. generated or theme-runtime files are either excluded or explicitly re-generated after apply

## Cutover sequence

### 1. Define the slice

Add or update a manifest under `infra/chezmoi/manifests/` so the target path is produced from canonical repo content.

### 2. Build generated source

Build the host-specific source tree:

```bash
./infra/chezmoi/scripts/build-source.sh --host <host> --manifest <manifest> ...
```

### 3. Verify generated source

Verify the expected output exists:

```bash
./infra/chezmoi/scripts/verify-generated-source.sh --host <host> --manifest <manifest> ...
```

### 3.5. Plan the Stow carve-out

Before applying chezmoi, generate the Stow ignore plan for the same manifest set:

```bash
./infra/chezmoi/scripts/plan-stow-cutover.sh --host <host> --manifest <manifest> ...
```

This planner derives:

- the migrated `$HOME` path set
- package-level `stow --ignore=...` carve-outs
- host-dotfiles `stow --ignore=...` carve-outs

This is required because the current `hyprland` package still owns non-migrated paths such as `.local/bin/**` and `.config/theme-manager/**`.

### 4. Stop legacy rewrites

Before cutover, remove or neutralize any script path that would overwrite the migrated files after apply.

Known examples:

- `keyboard.local.conf` from `scripts/install/setup/keyboard.sh`
- host-written `host-config.conf` behavior from host setup scripts
- theme-generated files such as merged `swaync/style.css`

### 5. Disable Stow ownership for the migrated path

Stow must stop owning only the migrated path set.

The preferred rule is:

- remove the migrated subtree from Stow application scope
- keep canonical source content in `packages/` untouched
- do not delete canonical content just because ownership moved

### 6. Apply chezmoi from generated source

Use the executable host cutover entrypoint:

```bash
./infra/chezmoi/scripts/cutover-host.sh --host <host>
```

Dry-run behavior:

- prints the build, verify, Stow carve-out, and chezmoi apply sequence
- reports any migrated paths that are not currently repo-managed and would block a real cutover

Execute only after reviewing the dry-run output:

```bash
./infra/chezmoi/scripts/cutover-host.sh --host <host> --execute
```

Execution behavior:

- rebuilds and verifies the generated source
- backs up and removes repo-managed migrated paths under `$HOME`
- re-runs package and host Stow with manifest-derived `--ignore=...` carve-outs
- runs `chezmoi diff` and `chezmoi apply` against the generated source

### 7. Validate post-cutover behavior

Confirm:

- files landed at the expected `$HOME` paths
- no host setup script rewrote them afterward
- session components still start correctly
- theme/runtime generators still behave correctly

## Current cutover status

The repository is not yet at full cutover.

The current state is:

- generated-source manifests exist
- generated-source build and verify tooling exist
- canonical source paths remain unchanged
- Stow is still the active owner for the migrated user-state paths

## First practical cutover target

The safest first real cutover target is the current session-core plus session-shell set:

- `dot_config/hypr`
- `dot_config/waybar`
- `dot_config/walker`
- `dot_config/elephant`
- `dot_config/autostart`
- `dot_config/clipse`
- `dot_config/swaync`
- `dot_config/swayosd`

Current runtime-managed exceptions inside that target are:

- `dot_config/swaync/style.css`
- `dot_config/clipse/theme.toml`

These stay out of generated source through manifest `exclude` entries and continue to be runtime-owned until their owner changes.
