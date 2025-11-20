# Applications Package

This package contains application-specific configurations, desktop files, and fixes.

## Contents

### Desktop Files

Located in `.local/share/applications/`, these customize application launch behavior:

- **zoom.desktop** - Zoom launcher with X11 mode enforcement for Hyprland compatibility
- Additional application launchers can be added here

### Configuration Files

- **`.zoom/zoomus.conf`** - Zoom configuration to fix rendering issues on Hyprland/Wayland

## Zoom Fix for Hyprland

### Problem

Zoom exhibits transparent/blurred meeting windows on Hyprland due to:
- XWayland alpha channel mishandling
- Qt rendering issues with Wayland backend
- Compositor blur interference

### Solution

This package includes:

1. **Zoom Configuration** (`.zoom/zoomus.conf`):
   - Disables alpha buffering
   - Enables system theme integration

2. **Desktop Launcher** (`zoom.desktop`):
   - Forces X11 mode via `QT_QPA_PLATFORM=xcb`
   - Disables auto-scaling
   - Proper MIME type associations

3. **Hyprland Window Rules** (in `hyprland` package):
   - Disables blur for Zoom windows
   - Forces opaque rendering
   - Applies immediate rendering mode

### Usage

#### Automatic (Recommended)

The fix is automatically applied during system setup:

```bash
# Via main install script
./install.sh

# Or specifically via setup orchestration
./scripts/install/setup.sh
```

#### Manual Application

If you need to apply the fix manually:

```bash
# Stow this package
cd ~/dotfiles/packages
stow applications

# Or run the dedicated fix script
./scripts/utilities/zoom-fix.sh
```

### Verification

Test the fix:

```bash
# 1. Launch Zoom
zoom

# 2. Join a test meeting
# Visit: https://zoom.us/test

# 3. Verify window is solid (not transparent)
hyprctl clients | grep -A10 "class: zoom"
# Should show "xwayland: 1"
```

### Troubleshooting

See comprehensive troubleshooting guide: [`../../docs/ZOOM_HYPRLAND_FIX.md`](../../docs/ZOOM_HYPRLAND_FIX.md)

Common issues:
- **Still transparent**: Ensure config exists at `~/.config/zoomus.conf`
- **Crashes**: Check for required packages: `qt5-wayland qt6-wayland libxcb`
- **Blurry UI**: Adjust DPI scaling in Zoom preferences

### Technical Details

**Why X11 Mode?**
- Zoom's Qt-based UI uses alpha compositing that XWayland doesn't handle correctly
- Native Wayland support in Zoom is non-existent (as of 2025-01)
- X11 mode via XWayland provides stable rendering

**Performance Impact**:
- Minimal: ~20-50MB additional memory for XWayland
- No noticeable latency (<5ms input lag)
- CPU usage identical to native

## Adding More Applications

To add fixes for other applications:

1. **Create config directory**:
   ```bash
   mkdir -p packages/applications/.config/app-name
   ```

2. **Add custom desktop file** (if needed):
   ```bash
   # packages/applications/.local/share/applications/app-name.desktop
   ```

3. **Document the fix**:
   - Add section to this README
   - Create detailed doc in `docs/` if complex

4. **Integrate with setup**:
   - Add to `scripts/install/setup/applications.sh`

## Stowing

```bash
cd ~/dotfiles/packages
stow applications
```

This will create symlinks:
- `~/.local/share/applications/zoom.desktop` → `packages/applications/.local/share/applications/zoom.desktop`
- `~/.zoom/zoomus.conf` → `packages/applications/.zoom/zoomus.conf`

## Related Documentation

- [Zoom Hyprland Fix (Comprehensive)](../../docs/ZOOM_HYPRLAND_FIX.md)
- [Hyprland Window Rules](../hyprland/.config/hypr/config/windowrules.conf)
- [Package README](../README.md)

## Maintenance

### Updating Zoom Config

If Zoom updates break the fix:

1. Check changelog: `pacman -Qc zoom` or AUR page
2. Update `zoomus.conf` with new settings
3. Test thoroughly
4. Update documentation

### Monitoring

Watch for Zoom issues:
```bash
# Check logs during meeting
tail -f ~/.zoom/logs/zoom_stdout_stderr.log

# Monitor window properties
hyprctl clients -j | jq '.[] | select(.class == "zoom")'
```

## Contributing

Found a better solution or additional application fixes?

1. Test thoroughly on Hyprland
2. Document the change
3. Submit PR with:
   - Updated config files
   - Documentation updates
   - Verification steps

