# Bibata Cursor Theme

A modern and stylish cursor theme with 12 variants, installed system-wide via the AUR package `bibata-cursor-theme`.

## Available Variants

The AUR package provides all Bibata cursor variants:

**Modern Style** (rounded, contemporary):

- `Bibata-Modern-Classic` - Black/white classic colors
- `Bibata-Modern-Ice` - Blue accent
- `Bibata-Modern-Amber` - Orange accent

**Original Style** (sharper, traditional):

- `Bibata-Original-Classic` - Black/white classic colors
- `Bibata-Original-Ice` - Blue accent
- `Bibata-Original-Amber` - Orange accent

**Right-Handed Variants**: All above themes have `-Right` versions for right-handed users.

## Installation

### Via Theme Manager (Recommended)

```bash
# Interactive cursor menu
./scripts/theme-manager/cursor-menu
# Then select: Install → bibata
```

### Manual Installation

```bash
./scripts/theme-manager/cursors/bibata/install.sh
```

### Automatic Installation

The Bibata cursor theme is automatically installed on Hyprland hosts via `install-deps.sh`.

## How It Works

1. **AUR Package**: Installs all 12 variants to `/usr/share/icons/`
2. **Symlinks**: Creates user-level symlinks in `~/.local/share/icons/` for theme manager access
3. **Selection**: Use `cursor-menu` or `set-cursor.sh` to choose your preferred variant

## Switching Variants

Use the cursor menu to switch between variants:

```bash
./scripts/theme-manager/cursor-menu
# Select: Pick → [Choose your variant]
```

Or manually:

```bash
./scripts/theme-manager/cursors/set-cursor.sh Bibata-Modern-Ice
```
