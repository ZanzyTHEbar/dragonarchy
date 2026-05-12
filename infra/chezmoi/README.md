# chezmoi Control Plane

This directory is the orchestration layer for chezmoi-managed user state.

It is not the canonical home-directory content tree.

## Canonical ownership

Canonical shared user-state source remains in:

- `packages/`

Canonical host-specific user-state source remains in:

- `hosts/<host>/dotfiles/`

This directory owns:

- build manifests (canonical specification)
- permanent sync tooling (`bin/chezmoi-sync` — TODO)
- architecture documentation

This directory does not own:

- `/etc`
- system packages
- system services
- hardware state
- canonical shared package contents
- canonical host dotfile contents
- chezmoi source state (lives in `~/.local/share/chezmoi/`)

## Migration status

The Stow-to-chezmoi migration is in progress. Temporary migration scripts have been moved to `migration-scripts/` and are **not part of permanent architecture**.

See `migration-scripts/README.md` for details.

## Manifest model

Manifests are the **canonical specification** of what chezmoi manages. They declare the mapping from repo source trees to chezmoi destination paths.

Manifests live in `manifests/` and are permanent. The current set:

| Manifest | Contents |
|----------|----------|
| `session-core.manifest` | Hyprland, Waybar, Walker, Elephant |
| `session-shell.manifest` | Autostart, Clipse, SwayNC, SwayOSD |
| `session-zsh.manifest` | Zsh config, host-specific overlays |
| `devtools-core.manifest` | nvim, kitty, tmux, zed, lazygit, yazi, alacritty, fastfetch, fcitx5 |
| `git-ssh.manifest` | git, gpg, ssh (public keys only) |

## Generated source

The `generated/<host>/` directory was a **temporary build artifact** used during migration. It has been removed from git tracking and should not be committed.

## Runtime-owned exclusions

These paths are owned by the theme manager / runtime and are excluded from chezmoi manifests:

- `swaync/style.css`
- `clipse/theme.toml`

See `docs/architecture/theme-manager-contract.md` for the full ownership matrix.
