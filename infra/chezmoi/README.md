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
- sync tooling (`bin/chezmoi-sync`)
- architecture documentation

This directory does not own:

- `/etc`
- system packages
- system services
- hardware state
- canonical shared package contents
- canonical host dotfile contents
- chezmoi source state (lives in `~/.local/share/chezmoi/`)

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

## Sync mechanism

`bin/chezmoi-sync` reads all manifests and syncs the declared source paths into `~/.local/share/chezmoi/` (chezmoi's source directory). It is idempotent and lightweight.

The `install` script at the repo root calls `chezmoi-sync` as part of user-state application.

## Runtime-owned exclusions

These paths are owned by the theme manager / runtime and are excluded from chezmoi manifests:

- `swaync/style.css`
- `clipse/theme.toml`
- `clipse/clipboard_history.json`

See `docs/architecture/theme-manager-contract.md` for the full ownership matrix.
