# FireDragon Touchpad Gestures - Quick Start Guide

## Current Status: Basic Gestures Working ✅

Your configuration is now set up to work **immediately** with native Hyprland gestures, and has **advanced gestures ready** to be enabled after plugin installation.

## What's Working Right Now

### ✅ Native Hyprland Gestures (No Setup Required)

These work immediately after reloading Hyprland:

```bash
hyprctl reload
```

**Available Now**:
- **3-finger swipe left** → Next workspace
- **3-finger swipe right** → Previous workspace
- **3-finger swipe up** → Toggle fullscreen
- **3-finger swipe down** → Minimize window
- **4-finger swipe left/right** → Move window between workspaces
- **4-finger swipe up** → Toggle floating
- **4-finger swipe down** → Close window

## Optional: Enable Advanced Gestures

If you want edge swipes and pinch gestures:

### Step 1: Install Plugins

Run the FireDragon setup script:

```bash
cd ~/dotfiles
bash hosts/firedragon/setup.sh
```

This will:
- Install build dependencies (glm, meson, ninja)
- Clone and build hyprgrass plugin
- Create plugin loader script

### Step 2: Logout/Login

After the setup completes, logout and login to load the plugins.

### Step 3: Enable Advanced Gestures

Run the enabler script:

```bash
bash ~/dotfiles/hosts/firedragon/enable-advanced-gestures.sh
```

This will:
- Check which plugins are available
- Uncomment the appropriate gesture configurations
- Reload Hyprland

### Step 4: Test Advanced Gestures

**Edge Swipes** (if hyprgrass loaded):
- Swipe from bottom edge → App launcher
- Swipe from right edge → Notifications  
- Swipe from top edge → Toggle waybar
- Long press + drag → Move window

**Pinch Gestures** (if hyprexpo available):
- Pinch out → Workspace overview
- Pinch in → Return from overview

## Troubleshooting

### "hyprexpo:expo does not exist"

This error means hyprexpo is not available. This is normal and expected until you:
1. Install plugins via setup script
2. Enable the gestures via enable-advanced-gestures.sh

The pinch gesture bindings are commented out by default.

### "invalid value edge:swipe:*:1"

This error means hyprgrass plugin is not loaded. This is normal and expected until you:
1. Install plugins via setup script
2. Logout/login to load plugins
3. Enable the gestures via enable-advanced-gestures.sh

The edge swipe configurations are commented out by default.

### Verify Plugin Status

Check if plugins are loaded:

```bash
hyprctl plugin list
```

Expected output after setup:
```
Plugin hyprgrass by horriblename:
  ...
```

### Test Gestures Live

Watch gesture events in real-time:

```bash
sudo libinput debug-events
```

Then perform gestures and watch for:
- `GESTURE_SWIPE_BEGIN`
- `GESTURE_SWIPE_UPDATE`
- `GESTURE_PINCH_BEGIN`

## Files

- **Configuration**: `~/.config/hypr/config/gestures.conf`
- **Plugin Loader**: `~/.config/hypr/scripts/load-gesture-plugins.sh`
- **Enable Script**: `~/dotfiles/hosts/firedragon/enable-advanced-gestures.sh`
- **Plugin Location**: `~/.local/share/hyprland-plugins/hyprgrass/`

## Quick Commands

```bash
# Reload Hyprland
hyprctl reload

# Check loaded plugins
hyprctl plugin list

# View gesture bindings
hyprctl binds | grep gesture

# Test gestures live
sudo libinput debug-events

# Check touchpad capabilities
libinput list-devices | grep -A 20 Touchpad

# Verify multi-touch support
libinput list-devices | grep -i "Size:"
```

## Current Configuration

✅ **Native gestures** - Working now
⏸️ **Pinch gestures** - Commented out (enable after plugin install)
⏸️ **Edge swipes** - Commented out (enable after plugin install)

This approach prevents errors while keeping advanced features ready to enable!

## Summary

1. **Right now**: Use 3/4-finger swipes (working immediately)
2. **Optional**: Run setup script to install plugins
3. **After setup**: Run enable script to unlock edge swipes and pinch gestures

**No errors, smooth experience! 🎉**

