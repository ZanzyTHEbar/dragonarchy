# SDDM Theme Installation Fix - Summary

## Issue

After running `./install.sh`, SDDM themes were not being installed, resulting in the default SDDM theme appearing after reboot instead of custom themes.

## Root Cause

The install script was not:
1. Stowing the SDDM system package
2. Copying themes to `/usr/share/sddm/themes/`
3. Configuring the active theme in `/etc/sddm.conf.d/10-theme.conf`

## Changes Made

### 1. **scripts/install/stow-system.sh**
- Changed `SYSTEM_PACKAGES=("")` to `SYSTEM_PACKAGES=("sddm")`
- This enables SDDM system package stowing during host-specific setup

### 2. **install.sh** (main installation script)
- Added SDDM theme installation in the theme refresh phase (lines ~555-576)
- Now runs after plymouth theme setup
- Checks if SDDM is installed before attempting setup
- Calls `refresh-sddm -y` to copy themes
- Calls `sddm-set` to configure default theme (catppuccin-mocha-sky-sddm)
- Only overwrites theme config if it doesn't already exist

### 3. **scripts/theme-manager/refresh-sddm**
- Added `-y` flag for non-interactive mode (used by install.sh)
- Added confirmation prompt with `gum` for interactive use
- Improved documentation and usage instructions

### 4. **Created verification script: scripts/utilities/verify-sddm-setup.sh**
- Comprehensive verification of SDDM theme installation
- Checks:
  - SDDM installation
  - Dotfiles themes
  - System themes
  - Theme configuration
  - SDDM service status
- Provides actionable feedback and instructions

### 5. **Created documentation: docs/SDDM_THEME_FIX.md**
- Detailed explanation of the problem and solution
- Usage instructions
- Testing procedures
- Future improvement ideas

## How to Use

### For Fresh Installation

Simply run the install script as usual:

```bash
./install.sh
```

The SDDM themes will now be installed automatically if SDDM is detected on your system.

### For Existing Installations

If you've already run `install.sh` before this fix, you have two options:

**Option 1: Run the full install script again**
```bash
./install.sh
```

**Option 2: Manually install SDDM themes**
```bash
# 1. Copy themes to system directory
./scripts/theme-manager/refresh-sddm

# 2. Set the default theme
./scripts/theme-manager/sddm-set catppuccin-mocha-sky-sddm

# 3. Verify installation
./scripts/utilities/verify-sddm-setup.sh
```

### Verify Installation

Run the verification script to check if everything is set up correctly:

```bash
./scripts/utilities/verify-sddm-setup.sh
```

Expected output for successful installation:
- ✓ SDDM is installed
- ✓ All dotfiles themes are installed in system
- ✓ Configuration file exists with valid theme
- ✓ SDDM service is enabled and running

## Available Themes

The following themes are included in `packages/sddm/`:

1. **catppuccin-mocha-sky-sddm** (default)
2. chili
3. darkevil
4. flateos
5. sugar-dark
6. sugar-light

## Managing Themes

### Change Theme Interactively
```bash
./scripts/theme-manager/sddm-menu
```

### Set Specific Theme
```bash
./scripts/theme-manager/sddm-set <theme-name>
```

### Set Theme and Restart SDDM Immediately
```bash
./scripts/theme-manager/sddm-set <theme-name> --restart
```
⚠️ **Warning**: This will end your current session!

### Refresh/Update Themes from Dotfiles
```bash
./scripts/theme-manager/refresh-sddm
```

## Flags and Options

The SDDM setup respects the following install.sh flags:

- `--no-theme`: Skips all theme setup (including SDDM)
- `--packages-only`: Skips theme setup
- `--dotfiles-only`: Includes SDDM theme setup

## Testing the Fix

To test that the fix works properly:

```bash
# 1. Verify current state
./scripts/utilities/verify-sddm-setup.sh

# 2. Install/refresh themes
./scripts/theme-manager/refresh-sddm -y

# 3. Set default theme
./scripts/theme-manager/sddm-set catppuccin-mocha-sky-sddm

# 4. Verify installation again
./scripts/utilities/verify-sddm-setup.sh

# 5. Check configuration file
cat /etc/sddm.conf.d/10-theme.conf

# 6. List installed themes
ls -la /usr/share/sddm/themes/
```

## Files Modified

1. `scripts/install/stow-system.sh` - Added "sddm" to SYSTEM_PACKAGES array
2. `install.sh` - Added SDDM theme installation logic
3. `scripts/theme-manager/refresh-sddm` - Added -y flag and confirmation

## Files Created

1. `scripts/utilities/verify-sddm-setup.sh` - Verification script
2. `docs/SDDM_THEME_FIX.md` - Detailed documentation
3. `SDDM_FIX_SUMMARY.md` - This summary (can be deleted after reading)

## Technical Details

### Theme Installation Process

1. **Theme Copying**: `refresh-sddm` uses `rsync` to copy themes from `packages/sddm/usr/share/sddm/themes/` to `/usr/share/sddm/themes/`

2. **Theme Configuration**: `sddm-set` writes to `/etc/sddm.conf.d/10-theme.conf`:
   ```ini
   [Theme]
   Current=catppuccin-mocha-sky-sddm
   ```

3. **Theme Loading**: SDDM reads theme configuration from `/etc/sddm.conf.d/` directory on startup

### Why rsync Instead of stow?

SDDM themes are data files (QML, images, config) that need to be present in the system directory, not symlinks. Using `rsync` ensures:
- Proper file permissions
- No broken symlinks if dotfiles are moved
- Compatibility with SDDM's theme loader

## Troubleshooting

### Themes not appearing after installation

```bash
# Check if themes are in system directory
ls -la /usr/share/sddm/themes/

# If not, run refresh manually
sudo ./scripts/theme-manager/refresh-sddm -y
```

### Theme shows as "Invalid theme" in SDDM

```bash
# Verify Main.qml exists
ls -la /usr/share/sddm/themes/catppuccin-mocha-sky-sddm/Main.qml

# Check theme configuration
cat /etc/sddm.conf.d/10-theme.conf
```

### Changes not taking effect

```bash
# Restart SDDM (WARNING: ends current session)
sudo systemctl restart sddm

# Or reboot the machine
sudo reboot
```

### Permission denied errors

The scripts automatically request sudo when needed. If you get permission errors:

```bash
# Ensure scripts are executable
chmod +x scripts/theme-manager/refresh-sddm
chmod +x scripts/theme-manager/sddm-set

# Run with sudo if needed
sudo ./scripts/theme-manager/refresh-sddm
```

## Next Steps

1. Run `./install.sh` or manually install themes as shown above
2. Run `./scripts/utilities/verify-sddm-setup.sh` to confirm installation
3. Reboot to see the new SDDM theme at login
4. (Optional) Change theme using `./scripts/theme-manager/sddm-menu`

## Questions or Issues?

If you encounter any problems:

1. Run the verification script: `./scripts/utilities/verify-sddm-setup.sh`
2. Check the detailed documentation: `docs/SDDM_THEME_FIX.md`
3. Review SDDM logs: `journalctl -u sddm.service`

