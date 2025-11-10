# SDDM Theme Installation Fix

## Problem

After running the install script, SDDM themes were not properly installed. After a reboot, the default SDDM theme was still being used instead of the custom themes from the dotfiles repository.

## Root Causes

1. **Empty `SYSTEM_PACKAGES` array**: The `scripts/install/stow-system.sh` file had an empty `SYSTEM_PACKAGES=("")` array, meaning no system packages (including SDDM) were being stowed.

2. **Missing SDDM setup in main install flow**: The main `install.sh` script was refreshing plymouth themes but not SDDM themes during the theme setup phase.

3. **No theme configuration**: While the SDDM package existed in `packages/sddm/`, the themes needed to be:
   - Copied to `/usr/share/sddm/themes/`
   - Configured in `/etc/sddm.conf.d/10-theme.conf`

## Solution

### 1. Updated `scripts/install/stow-system.sh`

Added "sddm" to the `SYSTEM_PACKAGES` array:

```bash
SYSTEM_PACKAGES=("sddm")
```

This ensures that SDDM system files are properly stowed during host-specific setup.

### 2. Updated `install.sh`

Added SDDM theme setup to the main installation flow (alongside plymouth):

- Checks if SDDM is installed
- Calls `refresh-sddm` to copy themes to `/usr/share/sddm/themes/`
- Sets default theme to `catppuccin-mocha-sky-sddm` if not already configured
- Only runs if the theme setup phase is enabled (`--no-theme` flag not used)

### 3. Enhanced `scripts/theme-manager/refresh-sddm`

Added features for better automation:

- Added `-y` flag support for non-interactive mode
- Added confirmation prompt using `gum` when running interactively
- Improved documentation and usage instructions

## How It Works Now

1. **During installation** (`./install.sh`):
   - When the theme setup phase runs (line ~551-579)
   - SDDM is detected on the system
   - `refresh-sddm -y` copies all themes from `packages/sddm/usr/share/sddm/themes/` to `/usr/share/sddm/themes/`
   - `sddm-set` configures `/etc/sddm.conf.d/10-theme.conf` with the default theme

2. **Available themes** (in `packages/sddm/usr/share/sddm/themes/`):
   - catppuccin-mocha-sky-sddm (default)
   - chili
   - darkevil
   - flateos
   - sugar-dark
   - sugar-light

3. **Manual theme management**:
   ```bash
   # Refresh/update themes from dotfiles
   ./scripts/theme-manager/refresh-sddm
   
   # Change theme interactively
   ./scripts/theme-manager/sddm-menu
   
   # Set specific theme
   ./scripts/theme-manager/sddm-set <theme-name>
   
   # Set theme and restart SDDM immediately
   ./scripts/theme-manager/sddm-set <theme-name> --restart
   ```

## Testing

To verify the fix works:

```bash
# 1. Run the install script (or just the theme portion)
./install.sh

# Or skip everything except themes:
./install.sh --dotfiles-only --no-shell --no-post-setup

# 2. Verify themes are copied
ls -la /usr/share/sddm/themes/

# 3. Verify theme configuration
cat /etc/sddm.conf.d/10-theme.conf
# Should show:
# [Theme]
# Current=catppuccin-mocha-sky-sddm

# 4. Restart SDDM to test (WARNING: ends current session)
sudo systemctl restart sddm
```

## Files Modified

1. `scripts/install/stow-system.sh`
   - Changed `SYSTEM_PACKAGES` from empty array to `("sddm")`

2. `install.sh`
   - Added SDDM theme setup in the theme refresh section (lines ~555-576)
   - Checks for SDDM installation
   - Calls `refresh-sddm -y` and `sddm-set` with default theme

3. `scripts/theme-manager/refresh-sddm`
   - Added `-y` flag for non-interactive mode
   - Added confirmation prompt with `gum` for interactive use
   - Improved documentation

## Notes

- The fix respects the `--no-theme` flag - if used, SDDM setup is skipped
- SDDM setup only runs if SDDM is actually installed on the system
- If a theme is already configured in `/etc/sddm.conf.d/10-theme.conf`, it won't be overwritten
- Host-specific setup scripts (like `hosts/firedragon/setup.sh`) can still override the default theme
- The default theme is `catppuccin-mocha-sky-sddm` but can be changed using `sddm-set` or `sddm-menu`

## Future Improvements

- [ ] Add option to select SDDM theme during installation (interactive mode)
- [ ] Add SDDM theme as a command-line argument (e.g., `--sddm-theme <name>`)
- [ ] Validate theme exists before setting it as default
- [ ] Add SDDM theme to the main theme-switching workflow (`theme-set`)

