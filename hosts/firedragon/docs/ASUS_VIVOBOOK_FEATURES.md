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

## MediaTek MT7902 WiFi 6E

Many Asus VivoBooks ship with the MediaTek MT7902 WiFi chip, which lacks official Linux kernel support.

### Status Check

Check if you have MT7902:
```bash
lspci -nn | grep -i "14c3\|network"
```

Check if WiFi is working:
```bash
ip link show | grep -E "wlan|wlp"
nmcli device
```

### Driver Installation

**Important**: Only run this if WiFi is NOT working after main setup.

```bash
cd ~/dotfiles/hosts/firedragon
bash setup-mt7902-wifi.sh
```

### What the Script Does

1. **Safety Checks**:
   - Detects if MT7902 chip is present
   - Checks if WiFi already works (skips if working)
   - Backs up current network configuration

2. **Installation**:
   - Installs build dependencies
   - Clones community driver repository
   - Builds driver from source
   - Sets up DKMS for automatic kernel rebuilds
   - Installs firmware files
   - Configures module loading

3. **Post-Installation**:
   - Loads modules
   - Creates systemd configuration
   - Verifies WiFi interface

### DKMS Integration

DKMS (Dynamic Kernel Module Support) ensures the driver survives kernel updates:

```bash
# Check DKMS status
dkms status

# Manually rebuild (if needed)
sudo dkms build mt7902/1.0
sudo dkms install mt7902/1.0
```

### Troubleshooting

**WiFi not appearing**:
```bash
# Check modules
lsmod | grep mt7902

# Check firmware
ls /lib/firmware/mediatek/

# Check logs
dmesg | grep -i mt7902
journalctl -xeu NetworkManager
```

**Manual module loading**:
```bash
sudo modprobe mt76-connac-lib
sudo modprobe mt76
sudo modprobe mt792x-lib
sudo modprobe mt792x-usb
sudo modprobe mt7902
```

**Rollback/Uninstall**:
```bash
sudo dkms remove mt7902/1.0 --all
sudo modprobe -r mt7902
sudo rm /etc/modules-load.d/mt7902.conf
sudo rm /etc/modprobe.d/mt7902.conf
```

### Alternative Solutions

If the community driver doesn't work well:

1. **USB WiFi Adapter**:
   - TP-Link Archer T3U/T4U (Realtek RTL8812AU)
   - Intel AX200/AX210 compatible adapters

2. **Replace WiFi Card**:
   - Intel AX210 (WiFi 6E, excellent Linux support)
   - Intel AX200 (WiFi 6, excellent Linux support)
   - Check M.2 slot compatibility first

3. **Wait for Official Support**:
   - Monitor Linux kernel releases
   - Check MediaTek/MT76 driver updates

### Full Documentation

See [MT7902_WIFI_SETUP.md](./MT7902_WIFI_SETUP.md) for complete details including:
- Detailed troubleshooting
- Safety features
- DKMS explained
- Uninstallation procedures
- Alternative solutions

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

**Enable advanced gestures**:
```bash
cd ~/dotfiles/hosts/firedragon
bash enable-advanced-gestures.sh
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
setup_mt7902_wifi()      # WiFi driver check
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

### WiFi (MT7902)
```bash
# Setup WiFi driver (if needed)
bash ~/dotfiles/hosts/firedragon/setup-mt7902-wifi.sh

# Check WiFi status
nmcli device wifi list
ip link show

# Debug WiFi
dmesg | grep mt7902
lsmod | grep mt7902
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
- `/etc/modprobe.d/mt7902.conf` - MT7902 driver options (if installed)
- `/etc/modules-load.d/mt7902.conf` - Auto-load MT7902 (if installed)

### User Configuration
- `~/.local/bin/kbd-backlight` - Keyboard backlight control script
- `~/.config/hypr/config/host-config.conf` - Laptop-specific Hyprland config
- `~/.config/hypr/config/gestures.conf` - Touchpad gesture configuration

### Scripts
- `setup.sh` - Main setup (includes all Asus-specific setup)
- `setup-mt7902-wifi.sh` - MT7902 WiFi driver installer
- `enable-advanced-gestures.sh` - Advanced gesture plugin enabler

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

### WiFi Issues

See [MT7902_WIFI_SETUP.md](./MT7902_WIFI_SETUP.md) for comprehensive WiFi troubleshooting.

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

**Last Updated**: October 31, 2024
**Hardware**: Asus VivoBook with AMD chipset, Radeon graphics, MT7902 WiFi
**Software**: Arch Linux (CachyOS), Hyprland, TLP, iwd/NetworkManager

