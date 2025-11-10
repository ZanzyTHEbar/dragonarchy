# Dragon CLI - SDDM Theme Management

## Overview

The Dragon CLI now includes integrated SDDM theme management, allowing you to list, install, update, and select SDDM themes directly from the interactive menu system.

## Features

### Quick Access

Access SDDM theme management directly from the command line:

```bash
dragon-cli sddm
```

Or navigate through the menu:

```bash
dragon-cli → Theme → SDDM Themes
```

## Menu Options

### 1. List Themes

Shows a comprehensive overview of available SDDM themes:

- **Available in Dotfiles**: All themes from `packages/sddm/usr/share/sddm/themes/`
- **Installation Status**: Shows whether each theme is installed on the system
- **Active Theme**: Highlights which theme is currently configured
- **Visual Indicators**:
  - `✓ theme-name (active, installed)` - Currently active theme
  - `✓ theme-name (installed)` - Installed but not active
  - `○ theme-name (not installed)` - Available in dotfiles but not yet installed

**Example Output:**

```bash
SDDM Themes

Available in Dotfiles:
  ✓ catppuccin-mocha-sky-sddm (active, installed)
  ✓ chili (installed)
  ○ darkevil (not installed)
  ✓ flateos (installed)
  ○ sugar-dark (not installed)
  ○ sugar-light (not installed)

Current Active Theme:
  → catppuccin-mocha-sky-sddm

Tip: Use 'Select Theme' to change, 'Refresh/Update' to install from dotfiles
```

### 2. Select Theme

Interactive theme selector using the existing `sddm-menu` script:

1. Displays all installed themes in a gum menu
2. Select your preferred theme
3. Automatically configures `/etc/sddm.conf.d/10-theme.conf`
4. Changes take effect on next login/reboot

**Usage:**

- Choose "Select Theme" from the SDDM Themes menu
- Use arrow keys to navigate available themes
- Press Enter to select
- Theme is configured immediately (requires sudo)

### 3. Refresh/Update Themes

Copies all themes from your dotfiles to the system:

- **Source**: `packages/sddm/usr/share/sddm/themes/`
- **Destination**: `/usr/share/sddm/themes/`
- **Method**: Uses `rsync` to ensure proper copying
- **Permission**: Requires sudo access

**When to Use:**

- After adding new themes to your dotfiles
- After pulling updates from git
- When themes are missing or corrupted
- During initial setup

**Confirmation Required:**
The menu will ask "Refresh SDDM themes from dotfiles? (requires sudo)" before proceeding.

### 4. Verify Setup

Runs the comprehensive verification script to check:

1. ✓ SDDM installation and version
2. ✓ Themes present in dotfiles (count)
3. ✓ Themes installed on system (count and status)
4. ✓ Current theme configuration validity
5. ✓ SDDM service status (enabled/running)

**Example Output:**

```
=== SDDM Theme Installation Verification ===

1. Checking if SDDM is installed... ✓ SDDM is installed
   Version: 0.20.0
2. Checking dotfiles SDDM package... ✓ Found 6 theme(s) in dotfiles
   Location: /home/user/dotfiles/packages/sddm/usr/share/sddm/themes
   - catppuccin-mocha-sky-sddm
   - chili
   - darkevil
   - flateos
   - sugar-dark
   - sugar-light
3. Checking system SDDM themes... ✓ Found 9 theme(s) in system
   Location: /usr/share/sddm/themes
   Checking for dotfiles themes... ✓ All dotfiles themes are installed
4. Checking SDDM theme configuration... ✓ Configuration file exists
   Location: /etc/sddm.conf.d/10-theme.conf
   Current theme: catppuccin-mocha-sky-sddm
   ✓ Theme directory exists
   ✓ Main.qml found (theme is valid)
5. Checking SDDM service status... ✓ SDDM service is enabled and running

=== Summary ===
✓ SDDM theme setup appears to be complete!

To change themes:
  • Interactive: dragon-cli sddm
  • Direct: ~/dotfiles/scripts/theme-manager/sddm-set <theme-name>

To apply changes immediately (will end current session):
  sudo systemctl restart sddm
```

## Available Themes

The dotfiles include 6 SDDM themes:

1. **catppuccin-mocha-sky-sddm** (default)
   - Modern, minimal design
   - Catppuccin Mocha color scheme
   - Sky accent color

2. **chili**
   - Clean and modern
   - Customizable background

3. **darkevil**
   - Dark theme with modern aesthetics
   - Custom components

4. **flateos**
   - Flat design
   - Material-inspired

5. **sugar-dark**
   - Sweet dark theme
   - Qt-based components

6. **sugar-light**
   - Light variant of sugar theme
   - Clean and simple

## Integration with Install Script

The SDDM themes are now automatically handled during installation:

```bash
./install.sh
```

This will:

1. Copy all themes to `/usr/share/sddm/themes/`
2. Configure `catppuccin-mocha-sky-sddm` as the default (if not already configured)
3. Create `/etc/sddm.conf.d/10-theme.conf` with proper settings

## Command Line Usage

### Direct Access

```bash
# Open SDDM theme menu directly
dragon-cli sddm

# Or use the full menu path
dragon-cli
# Then: Theme → SDDM Themes
```

### Manual Scripts (Advanced)

If you prefer using scripts directly:

```bash
# List and select theme interactively
~/dotfiles/scripts/theme-manager/sddm-menu

# Set specific theme
~/dotfiles/scripts/theme-manager/sddm-set catppuccin-mocha-sky-sddm

# Refresh themes from dotfiles
~/dotfiles/scripts/theme-manager/refresh-sddm

# Verify setup
~/dotfiles/scripts/utilities/verify-sddm-setup.sh
```

## Error Handling

### SDDM Not Installed

If SDDM is not installed, the menu will display:

```
┌─────────────────────────────────────────┐
│ SDDM is not installed on this system.  │
│ Install SDDM to manage themes.          │
└─────────────────────────────────────────┘

Return to menu? (Y/n)
```

### Script Not Found

If any required script is missing:

```
sddm-menu script not found
```

The menu will pause for 2 seconds and return to the SDDM Themes menu.

### Permission Denied

If sudo is required and denied:

```
This action requires sudo to copy themes into /usr/share/sddm/themes
[sudo] password for user:
```

## Technical Details

### File Structure

```
dotfiles/
├── packages/sddm/
│   └── usr/share/sddm/themes/
│       ├── catppuccin-mocha-sky-sddm/
│       ├── chili/
│       ├── darkevil/
│       ├── flateos/
│       ├── sugar-dark/
│       └── sugar-light/
├── scripts/
│   ├── dragon-cli (with SDDM menu integration)
│   ├── theme-manager/
│   │   ├── sddm-menu
│   │   ├── sddm-set
│   │   └── refresh-sddm
│   └── utilities/
│       └── verify-sddm-setup.sh
└── packages/dragon-cli/.local/share/dragon/
    └── dragon-cli@ → ../../../../../scripts/dragon-cli
```

### Configuration

SDDM theme configuration is stored in:

```
/etc/sddm.conf.d/10-theme.conf
```

Format:

```ini
[Theme]
Current=catppuccin-mocha-sky-sddm
```

### Theme Requirements

Valid SDDM themes must contain:

- `Main.qml` - Required entry point
- `metadata.desktop` - Theme metadata (optional but recommended)
- `theme.conf` - Theme configuration (optional)
- Assets (images, icons, etc.)

## Troubleshooting

### Theme doesn't appear after selection

1. Verify theme is properly installed:

   ```bash
   dragon-cli sddm → Verify Setup
   ```

2. Check for Main.qml:

   ```bash
   ls /usr/share/sddm/themes/your-theme/Main.qml
   ```

3. Restart SDDM (will end current session):

   ```bash
   sudo systemctl restart sddm
   ```

### Themes not showing in "Select Theme"

Run "Refresh/Update Themes" to copy themes from dotfiles:

```bash
dragon-cli sddm → Refresh/Update Themes
```

### Permission errors

Ensure your user has sudo access:

```bash
sudo -v
```

The scripts will automatically request sudo when needed.

### Changes not taking effect

SDDM themes are applied on next login. Either:

- Log out and log back in
- Restart the system
- Restart SDDM service (ends current session): `sudo systemctl restart sddm`

## Best Practices

1. **Verify Before Changing**: Always run "Verify Setup" before making changes
2. **Refresh After Updates**: Run "Refresh/Update Themes" after pulling dotfiles updates
3. **Test Themes**: Preview themes before applying (some themes have preview images)
4. **Backup Config**: Keep a backup of working configuration
5. **Check Logs**: Use `journalctl -u sddm.service` if themes fail to load

## See Also

- [SDDM_THEME_FIX.md](./SDDM_THEME_FIX.md) - Technical details about the SDDM setup
- [SDDM Official Documentation](https://github.com/sddm/sddm)
- Main dragon-cli documentation in `packages/dragon-cli/README.md`
