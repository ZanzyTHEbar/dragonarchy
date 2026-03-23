# chezmoi Control Plane

This directory is the orchestration layer for future chezmoi-managed user state.

It is not the canonical home-directory content tree.

## Canonical ownership

Canonical shared user-state source remains in:

- `packages/`

Canonical host-specific user-state source remains in:

- `hosts/<host>/dotfiles/`

This directory owns:

- build manifests
- build scripts
- generated-source conventions
- cutover documentation

This directory does not own:

- `/etc`
- system packages
- system services
- hardware state
- canonical shared package contents
- canonical host dotfile contents

## Active migration rule

The chezmoi migration must preserve canonical source contents.

Rules:

- keep `packages/` untouched
- keep `hosts/<host>/dotfiles/` untouched
- prefer `cp -a` and overlay semantics over content rewrites
- treat generated chezmoi source as rebuildable output, not canonical content

## Generated source model

The build step materializes a host-specific chezmoi source tree under:

- `infra/chezmoi/generated/<host>/`

That generated tree is the path passed to chezmoi.

Expected invocation model:

```bash
./infra/chezmoi/scripts/build-source.sh --host goldendragon
chezmoi --source ~/dotfiles/infra/chezmoi/generated/goldendragon diff
chezmoi --source ~/dotfiles/infra/chezmoi/generated/goldendragon apply
```

The generated tree may use chezmoi naming such as `dot_config/`, but only inside `generated/<host>/`.

Tracked files under `infra/chezmoi/` should remain orchestration files, not mirrored home-directory content.

## First build slice

The first manifest targets:

- Hyprland shared config
- Waybar shared config
- Walker shared config
- Elephant shared config
- host-specific Waybar session markers when present

Generated or script-owned files still need explicit handling before final cutover.
