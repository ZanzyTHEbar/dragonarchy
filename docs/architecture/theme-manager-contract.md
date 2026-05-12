# Theme Manager Integration Contract

## Purpose

The theme manager is a legacy subsystem under `scripts/theme-manager/` that generates runtime color themes for multiple UI targets. It contains 68 scripts that produce derived configuration files from a static palette.

This document defines the explicit ownership boundary between the theme-manager subsystem and the new Ansible + chezmoi control plane. Without this contract, the same paths could be modified by both the theme manager at runtime and chezmoi during apply, leading to non-deterministic user state and silent overwrites.

The contract establishes:

- which paths the theme manager may write to
- which paths are owned by chezmoi and must be treated as read-only
- how the theme manager gates its behavior against the active control-plane mode

## Ownership matrix

| Concern | Legacy Path | Canonical Owner | Notes |
|---------|-------------|-----------------|-------|
| Theme palettes | `packages/themes/` | chezmoi (when manifest created) | Static palette definitions |
| GTK3/4 CSS | `scripts/theme-manager/generate-gtk-themes` → `~/.config/gtk-3.0/gtk.css` | **Runtime** (theme-manager) | Generated from palette |
| Kitty colors | `scripts/theme-manager/generate-kitty-themes` → `~/.config/kitty/colors.conf` | **Runtime** (theme-manager) | Generated from palette |
| SwayNC CSS | `scripts/theme-manager/generate-swaync-themes` → `~/.config/swaync/style.css` | **Runtime** (theme-manager) | Already excluded from chezmoi |
| Clipse theme | `scripts/theme-manager/generate-clipse-themes` → `~/.config/clipse/theme.toml` | **Runtime** (theme-manager) | Already excluded from chezmoi |
| Walker CSS | `scripts/theme-manager/generate-walker-themes` → `~/.config/walker/themes/current/style.css` | **Runtime** (theme-manager) | Excluded from chezmoi manifests |
| btop theme | `scripts/theme-manager/theme-set` → `~/.config/btop/themes/current.theme` | **Runtime** (theme-manager) | Excluded from chezmoi manifests |
| wlogout CSS | `scripts/theme-manager/wlogout-setup` → `~/.config/wlogout/wlogout.css` | **Runtime** (theme-manager) | Excluded from chezmoi manifests |
| Plymouth theme | `scripts/theme-manager/refresh-plymouth` → `/usr/share/plymouth/themes/` | **Runtime** (theme-manager) | System-level runtime |
| SDDM theme | `scripts/theme-manager/refresh-sddm` → `/usr/share/sddm/themes/` | **Runtime** (theme-manager) | System-level runtime |
| Wallpaper | `scripts/theme-manager/theme-bg-*` → `~/.config/hypr/config/wallpaper.conf` | **Runtime** (theme-manager) | User-selected |
| Hyprland colors | `scripts/theme-manager/theme-set` → `~/.config/hypr/colors-theme.conf` | **Runtime** (theme-manager) | Excluded from chezmoi manifests |
| Keyboard local | `scripts/install/setup/keyboard.sh` → `~/.config/hypr/config/keyboard.local.conf` | **Runtime** (theme-manager or user) | Excluded from chezmoi manifests |
| GTK settings | `scripts/theme-manager/generate-gtk-themes` → `~/.config/gtk-3.0/settings.ini` | **Runtime** (theme-manager) | Generated from palette |
| GTK4 settings | `scripts/theme-manager/generate-gtk-themes` → `~/.config/gtk-4.0/settings.ini` | **Runtime** (theme-manager) | Generated from palette |

## Runtime-owned path contract

1. Theme-manager may write to any path marked **Runtime** in the ownership matrix.
2. Theme-manager **MUST NOT** write to chezmoi-owned paths.
3. Theme-manager scripts **MUST** source `scripts/lib/control-plane-mode.sh` before writing to any path that might overlap with chezmoi-owned trees.
4. Runtime-owned paths **MUST** be explicitly excluded from chezmoi manifests and apply operations.
5. When a theme is applied, the theme-manager must regenerate all runtime targets atomically to avoid a partial-theme state.

## Integration with control-plane gating

Theme-manager scripts should source `scripts/lib/control-plane-mode.sh` and respect `DOTFILES_USER_OWNER=chezmoi`.

When chezmoi owns user state, the theme-manager must still fulfill its runtime contract:

- continue generating runtime files (its canonical responsibility)
- not attempt to modify static chezmoi-owned files directly
- use the chezmoi-generated source tree as a **read-only reference** for palette data

The theme-manager does not need to check the control-plane mode for system-level paths (Plymouth, SDDM) because those are outside chezmoi's scope entirely.

## Runtime exclusions

The following paths are owned by the theme manager at runtime and must remain excluded from chezmoi manifests:

- `~/.config/btop/themes/current.theme`
- `~/.config/walker/themes/current/style.css`
- `~/.config/kitty/colors.conf`
- `~/.config/gtk-3.0/gtk.css`
- `~/.config/gtk-3.0/settings.ini`
- `~/.config/gtk-4.0/gtk.css`
- `~/.config/gtk-4.0/settings.ini`
- `~/.config/hypr/config/keyboard.local.conf`
- `~/.config/hypr/colors-theme.conf`
- `~/.config/swaync/style.css`
- `~/.config/clipse/theme.toml`
- `~/.config/wlogout/wlogout.css`

## Future work

In a later phase, theme generation could be moved into chezmoi templates or Ansible handlers. That would collapse the runtime layer into the control plane itself and remove the need for a separate runtime contract.

The theme-manager remains the canonical owner of runtime theme state until a future design document overrides this contract.
