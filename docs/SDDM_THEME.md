# SDDM Theme Management

## Overview

SDDM themes are managed through a set of scripts that handle installation, selection, and integration with the main theme-switching workflow.

## Available Themes

Located in `packages/sddm/usr/share/sddm/themes/`:

- **catppuccin-mocha-sky-sddm** (default)
- **chili**
- **darkevil**
- **flateos**
- **sugar-dark**
- **sugar-light**

## Installation

### During Setup (`./install.sh`)

SDDM themes are automatically set up during installation when:
- SDDM is detected on the system
- The `--no-theme` flag is **not** used

Three modes of theme selection:

1. **CLI argument**: Specify a theme directly
   ```bash
   ./install.sh --sddm-theme sugar-dark
   ```

2. **Interactive selection**: When running interactively with `gum` installed, you'll be prompted to choose a theme
   ```bash
   ./install.sh  # Presents a gum chooser menu
   ```

3. **Automatic default**: If no theme is specified and no theme is already configured, falls back to `catppuccin-mocha-sky-sddm`

Theme validation occurs before applying — if the specified theme doesn't exist, the installer logs available themes and falls back to the default.

### Manual Theme Management

```bash
# Refresh/update themes from dotfiles to system directory
./scripts/theme-manager/refresh-sddm

# Change theme interactively (gum chooser)
./scripts/theme-manager/sddm-menu

# Set a specific theme
./scripts/theme-manager/sddm-set <theme-name>

# Set theme and restart SDDM immediately
./scripts/theme-manager/sddm-set <theme-name> --restart
```

## Theme-Set Integration

When you switch your desktop theme using `theme-set`, SDDM is automatically updated:

1. **Exact match**: If an SDDM theme matches the desktop theme name exactly, it's applied
2. **Fuzzy match**: If the SDDM theme name contains the desktop theme slug (or vice versa), it's applied as a best-effort match
3. **No match**: SDDM theme remains unchanged

This means running `theme-set catppuccin-mocha-sky` will automatically apply `catppuccin-mocha-sky-sddm` if it exists.

## How It Works

1. **`refresh-sddm`**: Copies theme files from `packages/sddm/usr/share/sddm/themes/` to `/usr/share/sddm/themes/` using rsync
2. **`sddm-set`**: Validates the theme exists (checks for `Main.qml`), then writes the theme selection to `/etc/sddm.conf.d/10-theme.conf`
3. **`sddm-menu`**: Lists available themes via `gum choose` and delegates to `sddm-set`
4. **`theme-set`**: After switching desktop theme, attempts to match and apply a corresponding SDDM theme

## Testing

```bash
# 1. Verify themes are copied to system
ls -la /usr/share/sddm/themes/

# 2. Verify theme configuration
cat /etc/sddm.conf.d/10-theme.conf
# Should show:
# [Theme]
# Current=<your-theme-name>

# 3. Preview SDDM (without ending session)
sddm-greeter --test-mode

# 4. Restart SDDM to apply (WARNING: ends current session)
sudo systemctl restart sddm
```

## Files

| File | Purpose |
|------|---------|
| `scripts/theme-manager/refresh-sddm` | Copy themes to `/usr/share/sddm/themes/` |
| `scripts/theme-manager/sddm-set` | Set theme + validate + write config |
| `scripts/theme-manager/sddm-menu` | Interactive theme chooser |
| `scripts/theme-manager/theme-set` | Main theme switcher (includes SDDM integration) |
| `scripts/install/stow-system.sh` | Stows SDDM system files |
| `install.sh` | Main installer (SDDM setup with `--sddm-theme` option) |
| `packages/sddm/` | SDDM theme source files |

## Notes

- The SDDM setup respects the `--no-theme` flag — if used, SDDM setup is skipped
- SDDM setup only runs if SDDM is actually installed on the system
- Host-specific setup scripts (like `hosts/firedragon/setup.sh`) can still override the default theme
- Theme changes apply on next login unless `--restart` is passed to `sddm-set`
