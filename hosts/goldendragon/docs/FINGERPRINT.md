# Fingerprint Authentication - GoldenDragon

Complete guide for fingerprint authentication setup, troubleshooting, and maintenance.

## Quick Start

### Initial Setup

```bash
cd ~/dotfiles/hosts/goldendragon
bash ./setup.sh  # Automatically configures fingerprint if hardware detected
```

### Enroll Your Fingerprint

```bash
fprintd-enroll
# Follow prompts to scan finger multiple times
```

### Test Authentication

```bash
fprintd-verify
# Or try: sudo true
```

---

## How It Works

### Components

1. **fprintd** - Fingerprint daemon (DBus-activated)
2. **PAM modules** - `pam_fprintd.so` for authentication
3. **USB power management** - Prevents device sleep
4. **System-sleep hook** - Resets device on suspend/resume
5. **Watchdog** - Monitors and auto-recovers from issues

### PAM Configuration

Fingerprint authentication is configured in these PAM files:

- `/etc/pam.d/sudo` - Terminal sudo commands
- `/etc/pam.d/polkit-1` - GUI authentication dialogs
- `/etc/pam.d/system-local-login` - Console/display manager login
- `/etc/pam.d/sddm` - SDDM display manager

Each has `timeout=10` parameter to prevent long delays:

```
auth      sufficient pam_fprintd.so timeout=10
```

### USB Power Management

**Problem:** USB autosuspend puts fingerprint reader to sleep, causing 30-40s wake-up delays.

**Solutions:**

1. **Udev rule**: `/etc/udev/rules.d/99-fingerprint-no-autosuspend.rules`
2. **TLP denylist**: `/etc/tlp.d/01-goldendragon.conf` - `USB_DENYLIST="06cb:00f9"`
3. **Boot service**: `/etc/systemd/system/fprintd-usb-power.service` - Forces power on at boot

### System-Sleep Hook

**Location:** `/usr/lib/systemd/system-sleep/99-fprintd-reset.sh`

**Function:**

- **Before suspend**: Stop fprintd, unbind USB device
- **After resume**: Rebind USB device, reset authorization, start fprintd

This prevents USB firmware corruption during suspend/resume cycles.

### Watchdog System

**Components:**

- Script: `~/.local/bin/fprintd-watchdog`
- Service: `~/.config/systemd/user/fprintd-watchdog.service`
- Timer: `~/.config/systemd/user/fprintd-watchdog.timer`

**Function:**

- Runs every 30 minutes (5 min after boot)
- Checks fprintd logs for "Device was already claimed" errors
- Auto-restarts fprintd if >3 errors detected in last 5 minutes

**Enable:**

```bash
systemctl --user enable --now fprintd-watchdog.timer
```

---

## Troubleshooting

### Issue: Login Takes >40 Seconds

**Symptoms:**

- SDDM login slow on cold boot
- Lock screen slow after full sleep
- Works fine during active session

**Diagnosis:**

```bash
cd ~/dotfiles/hosts/goldendragon
bash ./scripts/diagnostics/diagnose-both-issues.sh
```

**Common Causes:**

1. **USB device suspended**

   ```bash
   cat /sys/bus/usb/devices/3-3/power/control
   # Should output: on (not auto)
   ```

2. **PAM timeout missing**

   ```bash
   grep "pam_fprintd.so" /etc/pam.d/sudo
   # Should contain: timeout=10
   ```

3. **Watchdog not enabled**

   ```bash
   systemctl --user is-enabled fprintd-watchdog.timer
   # Should output: enabled (not disabled or linked)
   ```

**Fixes:**

```bash
# Apply all fixes
cd ~/dotfiles/hosts/goldendragon
bash ./scripts/fixes/fix-persistence-issues.sh

# Or individually:
bash ./scripts/fingerprint/fix-fingerprint-delays.sh     # USB + PAM timeout
bash ./scripts/fingerprint/install-fprintd-watchdog.sh   # Watchdog system
bash ./scripts/fixes/fix-watchdog-enable.sh              # Fix enable status
```

### Issue: "Device Was Already Claimed"

**Symptom:** Fingerprint stops working after lock/unlock

**Cause:** Hyprlock doesn't properly release device claim

**Fix:**

```bash
# Quick fix
bash ~/dotfiles/hosts/goldendragon/scripts/fingerprint/restart-fprintd.sh

# Permanent fix (install watchdog)
bash ~/dotfiles/hosts/goldendragon/scripts/fingerprint/install-fprintd-watchdog.sh
```

### Issue: USB Device Corruption After Suspend

**Symptom:** Fingerprint doesn't work after waking from suspend

**Cause:** USB firmware gets corrupted during suspend

**Fix:**

```bash
bash ~/dotfiles/hosts/goldendragon/scripts/fingerprint/fix-usb-and-update-hook.sh
```

This installs an improved sleep hook that resets the USB device.

### Issue: Fingerprint Reader Not Detected

**Check detection:**

```bash
lsusb | grep -i "fingerprint\|06cb:00f9"
# Should show: Bus 003 Device 002: ID 06cb:00f9 Synaptics, Inc.
```

**Check fprintd:**

```bash
systemctl status fprintd.service
fprintd-list $USER
```

**If not detected:**

1. Check if driver loaded: `lsmod | grep synaptics`
2. Check USB port: Try different USB port or reboot
3. Check BIOS: Ensure fingerprint reader is enabled

---

## Maintenance

### Check System Health

```bash
# Full diagnostic
cd ~/dotfiles/hosts/goldendragon
bash ./scripts/diagnostics/diagnose-both-issues.sh

# Quick checks
systemctl --user status fprintd-watchdog.timer
cat /sys/bus/usb/devices/3-3/power/control  # Should be: on
systemctl status fprintd.service
```

### Monitor Logs

```bash
# Fprintd service
journalctl -u fprintd.service -f

# Watchdog activity
journalctl --user -u fprintd-watchdog.service -f

# System-sleep hook
journalctl -t fprintd-reset --since "1 hour ago"

# Boot-time USB power service
journalctl -u fprintd-usb-power.service
```

### Re-enroll Fingerprint

```bash
# Remove existing
fprintd-delete $USER

# Enroll new
fprintd-enroll
# Scan finger 5-7 times when prompted
```

### Verify Setup

```bash
cd ~/dotfiles/hosts/goldendragon
bash ./scripts/fingerprint/verify-fingerprint.sh
```

---

## Files Reference

### Host-Specific Files (in goldendragon/)

**Scripts:**

- `scripts/fingerprint/install-fprintd-watchdog.sh` - Install watchdog system
- `scripts/fingerprint/fix-fingerprint-delays.sh` - Fix USB autosuspend + PAM timeout
- `scripts/fingerprint/restart-fprintd.sh` - Quick restart fprintd
- `scripts/fingerprint/verify-fingerprint.sh` - Verify setup
- `scripts/fingerprint/fix-usb-and-update-hook.sh` - Fix USB corruption
- `scripts/fixes/fix-persistence-issues.sh` - Fix all persistence issues
- `scripts/fixes/fix-watchdog-enable.sh` - Fix watchdog enable status

**Configuration Templates:**

- `etc/pam.d/hyprlock` - Hyprlock PAM config
- `etc/pam.d/polkit-1` - Polkit PAM config
- `etc/systemd/system-sleep/99-fprintd-reset.sh` - Sleep hook
- `etc/systemd/user/fprintd-watchdog.{service,timer}` - Watchdog units
- `etc/tlp.d/01-goldendragon.conf` - TLP USB denylist
- `etc/udev/rules.d/99-fingerprint-no-autosuspend.rules` - Udev rule
- `.local/bin/fprintd-watchdog` - Watchdog script

### System Files (installed)

**User-Level:**

- `~/.local/bin/fprintd-watchdog` - Watchdog script (copied)
- `~/.config/systemd/user/fprintd-watchdog.{service,timer}` - Watchdog units (copied)

**System-Level:**

- `/etc/pam.d/{sudo,polkit-1,system-local-login,sddm}` - PAM configs (modified)
- `/etc/udev/rules.d/99-fingerprint-no-autosuspend.rules` - Udev rule (copied)
- `/etc/tlp.d/01-goldendragon.conf` - TLP config (copied)
- `/usr/lib/systemd/system-sleep/99-fprintd-reset.sh` - Sleep hook (copied)
- `/etc/systemd/system/fprintd-usb-power.service` - Boot service (created)
- `/etc/sudoers.d/fprintd-watchdog` - Sudo rules for watchdog (optional)

---

## Technical Details

### Why PAM timeout=10 Alone Isn't Enough

PAM's `timeout=10` tells PAM to give up after 10 seconds if the module doesn't respond.

However:

1. PAM module responds immediately
2. Module asks fprintd daemon
3. fprintd tries to talk to USB device
4. USB device is asleep (takes 30-40s to wake)
5. fprintd waits (its internal timeout, not PAM's)
6. PAM module waits for fprintd to finish

**Solution:** Device must be awake BEFORE authentication attempt.

### Why Udev Rule Alone Isn't Sufficient

Udev rules run on device add events, but:

1. Device may not be fully initialized when rule runs
2. Other services (TLP) may override power settings later
3. Race conditions in boot sequence

**Solution:** Multiple layers - udev + TLP + systemd service + sleep hook.

### USB Device Path

The fingerprint reader is at USB device `3-3`:

- Bus 3, Port 3
- Device ID: `06cb:00f9` (Synaptics)
- Power control: `/sys/bus/usb/devices/3-3/power/control`

If device moves to different port, update scripts:

```bash
lsusb | grep 06cb
# Note the bus and device number
# Update USB_DEVICE variable in scripts
```

---

## Alternatives

If issues persist despite all fixes, alternative approaches:

### 1. Disable Fingerprint Auth

```bash
# Remove pam_fprintd.so from PAM files
sudo sed -i '/pam_fprintd.so/d' /etc/pam.d/sudo
sudo sed -i '/pam_fprintd.so/d' /etc/pam.d/polkit-1
sudo sed -i '/pam_fprintd.so/d' /etc/pam.d/system-local-login
sudo sed -i '/pam_fprintd.so/d' /etc/pam.d/sddm
```

### 2. Use Different Biometric Method

- FIDO2 security key
- TPM-based authentication
- Face recognition (if hardware available)

### 3. Password-Only Authentication

Fastest and most reliable - just requires password entry.

---

## See Also

- [../docs/FPRINTD_WATCHDOG.md](FPRINTD_WATCHDOG.md) - Watchdog system details
- [../docs/KNOWN_ISSUES.md](../KNOWN_ISSUES.md) - Known issues and status
- [Arch Wiki: Fingerprint authentication](https://wiki.archlinux.org/title/Fprint)
- [fprintd documentation](https://fprint.freedesktop.org/)
