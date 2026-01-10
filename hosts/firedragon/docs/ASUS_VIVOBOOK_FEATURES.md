# FireDragon - Asus VivoBook Specific Features

## Asus VivoBook Integration

FireDragon includes specialized support for Asus VivoBook laptops, addressing common Linux compatibility issues and enabling all hardware features.

### Keyboard Backlight

The Asus keyboard backlight is fully supported with a custom control script.

**Command**: `kbd-backlight {up|down|toggle}`

**Examples**:
```bash
kbd-backlight up       # Increase brightness
kbd-backlight down     # Decrease brightness
kbd-backlight toggle   # On/off
```

**Technical Details**:
- Driver: `asus-nb-wmi` and `asus_wmi`
- Control path: `/sys/class/leds/asus::kbd_backlight/brightness`
- User permissions: Handled via udev rules

### ACPI Fixes

Asus VivoBooks often have ACPI issues on Linux. FireDragon applies kernel parameters to resolve these:

**Applied Fixes** (automatically added to bootloader config):
```bash
acpi_osi=! acpi_osi='Windows 2020' acpi_backlight=native
```

**What this fixes**:
- ACPI errors in dmesg
- Backlight control issues
- Sleep/suspend problems
- Special function keys
- Battery reporting

**Bootloader Support**:
The setup script automatically detects and configures:
- **Limine** - `/boot/limine.conf` or `/boot/limine/limine.conf`
- **systemd-boot** - `/boot/loader/entries/*.conf`
- **GRUB** - `/etc/default/grub.d/asus-vivobook.cfg`

**For Limine users**:
```bash
# Parameters are automatically added to CMDLINE in limine.conf
# No manual intervention needed - just reboot after setup
```

**For GRUB users** (if detected):
```bash
# After first setup, regenerate GRUB config
sudo grub-mkconfig -o /boot/grub/grub.cfg
# OR (on some systems)
sudo update-grub
```

**Manual verification**:
```bash
# Check current kernel parameters
cat /proc/cmdline | grep acpi_osi

# For Limine, check config
cat /boot/limine.conf | grep CMDLINE
```

### Special Function Keys

All Asus special keys are supported:

- **Fn + F1-F12**: Multimedia keys (volume, brightness, etc.)
- **Fn + F7**: Screen blank
- **Fn + F9**: Touchpad toggle
- **ROG Key** (if present): Custom mapping available

### Kernel Modules

Automatically loaded:
- `asus_wmi` - WMI driver for Asus notebooks
- `asus_nb_wmi` - Notebook-specific features

**Configuration**: `/etc/modprobe.d/asus-vivobook.conf`

## WiFi + Bluetooth (Intel AX210-class)

FireDragon’s current config includes power-management + recovery helpers for Intel AX210-class WiFi/Bluetooth devices:

- **Bluetooth recovery after resume**: `/etc/systemd/system-sleep/98-ax210-bt-recover.sh`
- **Keep btusb out of autosuspend**: `/etc/udev/rules.d/99-intel-ax210-btusb-power.rules`

Quick checks:

```bash
rfkill list
ip link show
nmcli device
dmesg | grep -iE "iwlwifi|bluetooth|btusb" | tail -80
```

## Touchpad Gestures

FireDragon includes advanced touchpad gesture support for Hyprland.

### Native Gestures

**3-Finger Swipes** (always available):
- Left/Right: Switch workspace
- Up: Toggle fullscreen
- Down: Minimize window

**4-Finger Swipes** (always available):
- Left/Right: Move window to workspace

### Plugin-Based Gestures

For advanced features like pinch-to-zoom workspace overview and edge swipes:

**Load plugins** (if not already loaded):
```bash
bash ~/.config/hypr/scripts/load-gesture-plugins.sh
hyprctl plugin list
```

**Advanced gestures include**:
- **Pinch**: Workspace overview (hyprexpo plugin)
- **Edge Swipes**: Monitor switching (hyprgrass plugin)

### Configuration

**Edit gesture settings**:
```bash
vim ~/.config/hypr/config/gestures.conf
```

**Test in real-time**:
```bash
libinput debug-events
```

**Check device support**:
```bash
libinput list-devices
```

### Gesture Sensitivity

Adjust in `~/.config/hypr/config/gestures.conf`:

```ini
gestures {
    workspace_swipe = true
    workspace_swipe_fingers = 3
    workspace_swipe_distance = 500        # Lower = less distance
    workspace_swipe_cancel_ratio = 0.15
    workspace_swipe_min_speed_to_force = 20
    workspace_swipe_forever = false
}
```

## Integration with Repository Patterns

### Host-Specific Loading

Asus-specific and laptop-specific configurations are loaded conditionally:

**Hyprland Configuration**:
- Desktop hosts: Empty `host-config.conf`
- Laptop hosts: `host-config.conf` sources `gestures.conf`

**Shell Configuration**:
- Desktop: Uses `.zshrc.dragon` or `.zshrc.goldendragon`
- Laptop: Uses `.zshrc.firedragon` with power management aliases

### Setup Script Integration

The `setup.sh` script handles everything:

```bash
# Check hardware
setup_asus_vivobook()    # Asus-specific config
setup_gesture_plugins()  # Touchpad gestures

# Create configurations
create_host_config()     # Hyprland host config
```

## Quick Command Reference

### Asus VivoBook
```bash
kbd-backlight up          # Keyboard brightness +
kbd-backlight down        # Keyboard brightness -
kbd-backlight toggle      # Keyboard light on/off
```

### WiFi / Bluetooth
```bash
# Check WiFi status
nmcli device wifi list
ip link show
rfkill list

# Debug WiFi/Bluetooth
dmesg | grep -iE "iwlwifi|bluetooth|btusb" | tail -80
```

### Gestures
```bash
# Debug gestures
libinput list-devices     # List input devices
libinput debug-events     # Watch gestures live

# Edit configuration
vim ~/.config/hypr/config/gestures.conf
```

### Power & Battery
```bash
battery                   # Battery status
powersave                 # Power-save mode
powerperf                 # Performance mode
temp                      # System temperatures
```

## Files Modified/Created

### System Configuration
- `/etc/modprobe.d/asus-vivobook.conf` - Asus driver options
- `/etc/modules-load.d/asus.conf` - Auto-load Asus modules
- `/boot/limine.conf` or `/boot/limine/limine.conf` - Limine bootloader (ACPI fixes)
- `/boot/loader/entries/*.conf` - systemd-boot entries (ACPI fixes, if applicable)
- `/etc/default/grub.d/asus-vivobook.cfg` - GRUB config (ACPI fixes, if GRUB detected)
- `/etc/udev/rules.d/90-asus-kbd-backlight.rules` - Keyboard backlight permissions

### User Configuration
- `~/.local/bin/kbd-backlight` - Keyboard backlight control script
- `~/.config/hypr/config/host-config.conf` - Laptop-specific Hyprland config
- `~/.config/hypr/config/gestures.conf` - Touchpad gesture configuration

### Scripts
- `setup.sh` - Main setup (includes all Asus-specific setup)
- (Advanced gestures) use `~/.config/hypr/scripts/load-gesture-plugins.sh` if you need to load plugins manually

## Troubleshooting

### Keyboard Backlight Not Working

```bash
# Check if driver loaded
lsmod | grep asus

# Check sysfs path
ls /sys/class/leds/asus::kbd_backlight/

# Check permissions
ls -la /sys/class/leds/asus::kbd_backlight/brightness

# Reload udev rules
sudo udevadm control --reload-rules
sudo udevadm trigger
```

### ACPI Errors in dmesg

```bash
# Check current kernel parameters
cat /proc/cmdline

# For Limine users - check if parameters applied
cat /boot/limine.conf | grep CMDLINE
# Should contain: acpi_osi=! acpi_osi='Windows 2020' acpi_backlight=native

# For systemd-boot users
cat /boot/loader/entries/*.conf | grep options

# For GRUB users - if changes not applied
sudo grub-mkconfig -o /boot/grub/grub.cfg
sudo reboot
```

### WiFi / Bluetooth Issues

Start with:

```bash
rfkill list
nmcli device
journalctl -b -u NetworkManager | tail -80
dmesg | grep -iE "iwlwifi|bluetooth|btusb" | tail -120
```

### Gesture Not Working

```bash
# Check if device supports gestures
libinput list-devices | grep -A 20 "Touchpad"

# Watch events
libinput debug-events --device /dev/input/eventX

# Check Hyprland config
grep -r "gesture" ~/.config/hypr/

# Reload Hyprland config
hyprctl reload
```

## Resources

- [Arch Wiki: ASUS Notebooks](https://wiki.archlinux.org/title/ASUS)
- [Arch Wiki: TLP](https://wiki.archlinux.org/title/TLP)
- [Arch Wiki: Libinput](https://wiki.archlinux.org/title/Libinput)
- [MT76 Driver Project](https://wireless.wiki.kernel.org/en/users/drivers/mt76)
- [Hyprland Wiki: Gestures](https://wiki.hyprland.org/Configuring/Variables/#gestures)

---

**Last Updated**: January 10, 2026
**Hardware**: Asus VivoBook with AMD chipset, Radeon graphics, Intel AX210-class WiFi/Bluetooth
**Software**: Arch Linux (CachyOS), Hyprland, TLP, iwd/NetworkManager

