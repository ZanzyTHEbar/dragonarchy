# Fingerprint Authentication Quick Start (goldendragon)

## TL;DR - Fix Fingerprint Issues

### Issue 1: 40+ Second Login Delays
```bash
cd ~/dotfiles/hosts/goldendragon
bash ./fix-fingerprint-delays.sh
```

### Issue 2: Fingerprint Stops Working After Lock/Resume
```bash
cd ~/dotfiles/hosts/goldendragon
bash ./install-fprintd-watchdog.sh
```

This installs automatic recovery from stuck device claims.

## What This Fixes

Three common fingerprint authentication issues:

1. **USB Autosuspend** (primary delay issue): Fingerprint reader goes to sleep, takes 40s to wake up
2. **PAM Timeout** (secondary delay): PAM waits indefinitely for the sleeping device
3. **Device Claim Stuck** (recurring issue): Hyprlock doesn't release device after auth, causing "already claimed" errors

## Quick Verification

Check if you have the issue:

```bash
# Check USB power status (should be "on" not "auto")
lsusb | grep -i fingerprint
# Note the vendor:product ID (e.g., 06cb:00f9)

# Check if device is being suspended
grep -r "06cb" /sys/bus/usb/devices/*/idVendor 2>/dev/null | while read line; do
  dev=$(dirname $(echo $line | cut -d: -f1))
  echo "Device: $(cat $dev/idVendor):$(cat $dev/idProduct)"
  echo "Power: $(cat $dev/power/control)"
  echo "---"
done
```

If you see `Power: auto`, that's the problem.

## After Running the Fix

The script will:
- ✅ Add `timeout=10` to PAM fingerprint authentication
- ✅ Create udev rule to keep fingerprint reader powered on
- ✅ Restart fprintd service to apply changes
- ✅ Back up all modified files
- ✅ Test fingerprint reader accessibility

## Testing (No Reboot Needed!)

You can test immediately after running the script:

1. **If fingerprint doesn't work** (shows "Device already claimed"):
   ```bash
   bash ./restart-fprintd.sh
   ```

2. **Test fingerprint authentication**:
   ```bash
   sudo udevadm control --reload-rules
   sudo udevadm trigger --subsystem-match=usb
   ```

2. **Lock screen and test**:
   ```bash
   loginctl lock-session
   # Unlock should be instant now
   ```

3. **Verify fingerprint reader status**:
   ```bash
   fprintd-verify
   # Should complete in < 5 seconds
   ```

4. **Check USB power** (should show "on"):
   ```bash
   lsusb | grep -i fingerprint
   # Find the device path and check power control
   grep -r "06cb" /sys/bus/usb/devices/*/idVendor 2>/dev/null | while read line; do
     dev=$(dirname $(echo $line | cut -d: -f1))
     cat $dev/power/control
   done
   # Output should be: on
   ```

## Files Modified/Created

### Delay Fix:
- `/etc/pam.d/sudo` - Added timeout parameter
- `/etc/pam.d/polkit-1` - Added timeout parameter
- `/etc/pam.d/system-local-login` - Added timeout parameter
- `/etc/pam.d/sddm` - Added timeout parameter
- `/etc/udev/rules.d/99-fingerprint-no-autosuspend.rules` - Disables USB autosuspend

### Watchdog System (prevents recurring issues):
- `/usr/lib/systemd/system-sleep/99-fprintd-reset.sh` - Restarts fprintd on suspend/resume
- `~/.local/bin/fprintd-watchdog` - Monitors and auto-restarts if claims stuck
- `~/.config/systemd/user/fprintd-watchdog.timer` - Runs watchdog every 30 minutes
- `~/.config/systemd/user/fprintd-watchdog.service` - Watchdog service unit

Backups: `/etc/pam.d/.dragonarchy-backups/`

## Rollback

If you need to revert:

```bash
# Restore PAM files from backup
sudo cp /etc/pam.d/.dragonarchy-backups/*/sudo /etc/pam.d/sudo
sudo cp /etc/pam.d/.dragonarchy-backups/*/polkit-1 /etc/pam.d/polkit-1
sudo cp /etc/pam.d/.dragonarchy-backups/*/system-local-login /etc/pam.d/system-local-login
sudo cp /etc/pam.d/.dragonarchy-backups/*/sddm /etc/pam.d/sddm

# Remove udev rule
sudo rm /etc/udev/rules.d/99-fingerprint-no-autosuspend.rules
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=usb
```

## Full Documentation

See [PAM_FINGERPRINT_TIMEOUT.md](docs/PAM_FINGERPRINT_TIMEOUT.md) for:
- Detailed root cause analysis
- Manual fix instructions
- Advanced troubleshooting
- Technical deep-dive

## Common Questions

**Q: Why does fingerprint work fine during an active session?**  
A: During a session, the fingerprint reader stays awake. At login/lock screens (especially after idle time), USB autosuspend puts it to sleep.

**Q: Will this increase power consumption?**  
A: Minimally. The fingerprint reader consumes very little power even when awake. The benefit of instant authentication far outweighs the negligible power cost.

**Q: Does this affect battery life?**  
A: The impact is negligible (< 0.1% of battery capacity). TLP still manages all other USB devices and system components for power efficiency.

**Q: Why isn't this fixed by default in the setup?**  
A: It is now! The updated `setup.sh` includes both fixes. Run `bash ./setup.sh` to apply them automatically on new installs.

## Related Files

- `setup.sh` - Automated setup (includes both fixes)
- `fix-fingerprint-delays.sh` - Manual fix script for existing installations
- `verify-fingerprint.sh` - Verification script
- `docs/PAM_FINGERPRINT_TIMEOUT.md` - Detailed documentation
- `etc/udev/rules.d/99-fingerprint-no-autosuspend.rules` - Udev rule template
- `etc/tlp.d/01-goldendragon.conf` - TLP configuration with fingerprint exclusion
