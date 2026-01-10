# FireDragon - Quick Setup Reference

## Bootloader: Limine

FireDragon uses **Limine** as the bootloader. The setup script automatically detects this and configures ACPI kernel parameters accordingly.

## First Time Setup

```bash
cd ~/dotfiles/hosts/firedragon
bash setup.sh
```

## Post-Setup Steps

### 1. Reboot
```bash
sudo reboot
```

### 2. Verify ACPI Parameters Applied

After reboot, check if Asus ACPI fixes are active:
```bash
cat /proc/cmdline | grep acpi_osi
```

You should see:
```
acpi_osi=! acpi_osi='Windows 2020' acpi_backlight=native
```

### 3. Verify Limine Configuration (Optional)

Check that the parameters were added to Limine:
```bash
# Check main Limine config
cat /boot/limine.conf | grep CMDLINE

# OR if Limine is in subdirectory
cat /boot/limine/limine.conf | grep CMDLINE
```

### 4. Test Keyboard Backlight

```bash
kbd-backlight toggle    # Turn on/off
kbd-backlight up        # Increase brightness
kbd-backlight down      # Decrease brightness
```

### 5. Check WiFi Status

```bash
# List network interfaces
ip link show

# If WiFi (wlan0 or wlpXsX) is present - you're good!
# If not:
rfkill list
lspci -nn | grep -i network
journalctl -b | grep -iE "iwlwifi|ath|mt76|wifi" | tail -50
```

### 6. Test Touchpad Gestures

Try these multi-touch gestures:
- **3-finger swipe left/right**: Switch workspace
- **3-finger swipe up**: Toggle fullscreen
- **3-finger swipe down**: Minimize window
- **4-finger swipe left/right**: Move window to workspace

## Limine Configuration Location

The setup script automatically handles Limine configuration at either:
- `/boot/limine.conf` (most common)
- `/boot/limine/limine.conf` (alternative location)

**No manual Limine reconfiguration needed** - parameters are applied directly and take effect on next boot.

## Difference from GRUB

Unlike GRUB (which requires running `grub-mkconfig` after changes), Limine reads its configuration file directly at boot time. Changes to `limine.conf` take effect immediately on the next boot - no rebuild step required.

## Troubleshooting

### ACPI Errors Still Appearing

If you still see ACPI errors in `dmesg`:

1. **Verify parameters are in cmdline**:
   ```bash
   cat /proc/cmdline
   ```

2. **Check Limine config**:
   ```bash
   cat /boot/limine.conf | grep CMDLINE
   ```

3. **Manual edit if needed**:
   ```bash
   sudo vim /boot/limine.conf
   # Find the CMDLINE line for your kernel
   # Add: acpi_osi=! acpi_osi="Windows 2020" acpi_backlight=native
   # Save and reboot
   ```

### Keyboard Backlight Not Working

```bash
# Check if driver loaded
lsmod | grep asus

# Check device exists
ls /sys/class/leds/asus::kbd_backlight/

# Reload udev rules
sudo udevadm control --reload-rules
sudo udevadm trigger
```

### WiFi Not Working

FireDragon is configured for Intel AX210-class devices (in-kernel `iwlwifi` + `btusb`).
If WiFi is missing, check `rfkill`, confirm `linux-firmware` is installed, and inspect the logs shown above.

## Quick Commands

```bash
# System Info
battery          # Battery status
temp             # Temperatures
gpuinfo          # GPU info

# Power Management
powersave        # Battery mode
powerperf        # Performance mode

# Asus Specific
kbd-backlight up|down|toggle    # Keyboard backlight

# Gestures
libinput list-devices           # List input devices
libinput debug-events          # Watch gestures live

# WiFi
nmcli device wifi list         # List networks
ip link show                   # Check interfaces
```

## File Locations

### Limine Configuration
- `/boot/limine.conf` or `/boot/limine/limine.conf`
- Backup created at: `/boot/limine.conf.backup.YYYYMMDD_HHMMSS`

### Asus Configuration
- `/etc/modprobe.d/asus-vivobook.conf`
- `/etc/modules-load.d/asus.conf`
- `/etc/udev/rules.d/90-asus-kbd-backlight.rules`
- `~/.local/bin/kbd-backlight`

### Hyprland Configuration
- `~/.config/hypr/config/host-config.conf` (laptop-specific)
- `~/.config/hypr/config/gestures.conf` (touchpad gestures)

## For Other Bootloaders

The setup script also supports:

### systemd-boot
- Config: `/boot/loader/entries/*.conf`
- Parameters added to `options` line
- No rebuild needed

### GRUB (if detected)
- Config: `/etc/default/grub.d/asus-vivobook.cfg`
- **Requires**: `sudo grub-mkconfig -o /boot/grub/grub.cfg` after setup
- Then reboot

## Additional Documentation

- [Full Setup Guide](./README.md)
- [Asus VivoBook Features](./ASUS_VIVOBOOK_FEATURES.md)
- [Gesture Guide](./GESTURES_QUICKSTART.md)
- [Suspend/Resume Fix](./SUSPEND_RESUME_COMPLETE_FIX.md)

---

**Quick Start**: `bash setup.sh` → `reboot` → verify with `cat /proc/cmdline`

