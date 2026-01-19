# Apply Fingerprint Authentication Fix (goldendragon)

## What This Fixes

Your 40+ second login/lock screen delays are caused by **USB autosuspend** putting the fingerprint reader to sleep. The fix keeps the device awake and adds a PAM timeout for faster fallback.

## Quick Fix (3 minutes)

### Step 1: Run the fix script

```bash
cd ~/dotfiles/hosts/goldendragon
bash ./fix-fingerprint-delays.sh
```

**What it does:**
- ✅ Adds `timeout=10` to all PAM fingerprint configs
- ✅ Creates udev rule to disable USB autosuspend for fingerprint reader
- ✅ Backs up all modified files
- ✅ Applies changes immediately

### Step 2: Reboot (recommended)

```bash
sudo reboot
```

Or manually reload udev:
```bash
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=usb
```

### Step 3: Test

1. Lock your screen:
   ```bash
   loginctl lock-session
   ```

2. Try unlocking with fingerprint or password
   - **Before fix**: 40+ seconds
   - **After fix**: Instant (<1 second)

3. Verify USB power status:
   ```bash
   # Should show "on" not "auto"
   lsusb | grep -i fingerprint
   grep -r "06cb" /sys/bus/usb/devices/*/idVendor 2>/dev/null | while read line; do
     dev=$(dirname $(echo $line | cut -d: -f1))
     echo "Power: $(cat $dev/power/control)"
   done
   ```

## What Changed on Your System

### Files Modified:
- `/etc/pam.d/sudo` - Added timeout parameter
- `/etc/pam.d/polkit-1` - Added timeout parameter
- `/etc/pam.d/system-local-login` - Added timeout parameter
- `/etc/pam.d/sddm` - Added timeout parameter

### Files Created:
- `/etc/udev/rules.d/99-fingerprint-no-autosuspend.rules` - Prevents USB suspend

### Backups:
- All PAM files backed up to: `/etc/pam.d/.dragonarchy-backups/`

## Current Fingerprint Reader Info

```
Device: Synaptics fingerprint reader
USB ID: 06cb:00f9
Issue: USB autosuspend causing 30-40s wake-up delay
```

## Troubleshooting

### Still experiencing delays?

1. **Check fprintd service:**
   ```bash
   sudo systemctl status fprintd.service
   sudo journalctl -u fprintd.service -n 50
   ```

2. **Verify device power status:**
   ```bash
   # Should output "on"
   find /sys/bus/usb/devices -name "idVendor" -exec sh -c '
     if grep -q "06cb" "$1"; then
       dir=$(dirname "$1")
       echo "Power: $(cat "$dir/power/control")"
     fi
   ' _ {} \;
   ```

3. **Manually force device to stay on:**
   ```bash
   FP_DEV=$(find /sys/bus/usb/devices -type f -name idVendor -exec sh -c 'grep -l "06cb" "$1"' _ {} \; | head -1 | xargs dirname)
   echo "on" | sudo tee "$FP_DEV/power/control"
   ```

4. **Restart fprintd:**
   ```bash
   sudo systemctl restart fprintd.service
   fprintd-verify
   ```

### Need help?

See comprehensive documentation:
- `FINGERPRINT_QUICKSTART.md` - Quick reference
- `docs/PAM_FINGERPRINT_TIMEOUT.md` - Detailed troubleshooting

## Why This Works

**During an active session**: Fingerprint reader is awake → responds instantly
**At login/lock screens**: Fingerprint reader was suspended → 40s to wake up

**The fix**: Keep fingerprint reader always awake (negligible power impact) → always responds instantly

## Power Impact

**Q: Will this drain my battery?**  
**A:** No. The fingerprint reader uses <0.1% of battery capacity even when awake. TLP still manages all other USB devices and components.

## Future Installs

The fix is now integrated into `setup.sh`. New installations will automatically apply both fixes.

## Rollback (if needed)

```bash
# Restore PAM files
sudo cp /etc/pam.d/.dragonarchy-backups/*/sudo /etc/pam.d/sudo
sudo cp /etc/pam.d/.dragonarchy-backups/*/polkit-1 /etc/pam.d/polkit-1
sudo cp /etc/pam.d/.dragonarchy-backups/*/system-local-login /etc/pam.d/system-local-login
sudo cp /etc/pam.d/.dragonarchy-backups/*/sddm /etc/pam.d/sddm

# Remove udev rule
sudo rm /etc/udev/rules.d/99-fingerprint-no-autosuspend.rules
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=usb
```

---

**Ready?** Run the fix now:
```bash
cd ~/dotfiles/hosts/goldendragon && bash ./fix-fingerprint-delays.sh
```
