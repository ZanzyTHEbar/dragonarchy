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
./infra/chezmoi/scripts/verify-generated-source.sh --host goldendragon
./infra/chezmoi/scripts/plan-stow-cutover.sh --host goldendragon
./infra/chezmoi/scripts/cutover-host.sh --host goldendragon
```

To execute the full cutover on the target host after dry-run review:

```bash
./infra/chezmoi/scripts/cutover-host.sh --host goldendragon --execute
```

The generated tree may use chezmoi naming such as `dot_config/`, but only inside `generated/<host>/`.

Tracked files under `infra/chezmoi/` should remain orchestration files, not mirrored home-directory content.

For the operator-facing first-host execution order, see:

- `docs/runbooks/first-host-chezmoi-cutover.md`

## First build slice

The first manifest targets:

- Hyprland shared config
- Waybar shared config
- Walker shared config
- Elephant shared config
- host-specific Waybar session markers when present

The next manifest slice expands the session shell with:

- autostart
- clipse
- swaync
- swayosd

The current zsh slice expands user-shell ownership with:

- `.zshrc`
- `.zshenv`
- `.config/zsh/**`
- host-specific zsh overlays under `.config/zsh/hosts/<host>.zsh`
- host-specific zsh functions under `.config/zsh/functions/<host>.zsh`

Generated or script-owned files still need explicit handling before final cutover.

Notable current exceptions:

- `swaync/style.css` is merged runtime output
- `clipse/theme.toml` is theme-generated runtime state

These runtime-owned paths are excluded from generated source with manifest `exclude` entries.
