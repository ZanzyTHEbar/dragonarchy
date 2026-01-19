# Fingerprint Authentication Delay Issues

## Problem

Login and lock screens on `goldendragon` take 40+ seconds to resolve after entering a password or using fingerprint authentication. This issue started after integrating fingerprint sensing and PAM support.

**Symptom**: The fingerprint reader works fine during an active session but is extremely slow at login/lock screens.

## Root Causes

There are **two separate issues** that combine to create the 40+ second delay:

### Issue 1: PAM Timeout (Minor)

The `pam_fprintd.so` module was configured without a timeout parameter. When PAM attempts authentication and the fingerprint reader doesn't respond, PAM waits for the default timeout (30-40+ seconds) before falling through to password authentication.

### Issue 2: USB Autosuspend (Major - Primary Cause)

**This is the main issue**. The fingerprint reader is being put into USB autosuspend by TLP's power management. When the system is locked or at the login screen:

1. The fingerprint reader USB device goes into suspend mode after inactivity
2. When PAM tries to use it, the device must wake up and reinitialize
3. This wake-up process takes 30-40+ seconds
4. During an active session, the device stays awake, so it responds instantly

Evidence from fprintd logs:
```
USB error on device 06cb:00f9 : No such device (it may have been disconnected) [-4]
```

This delay occurs on:
- Login screen (SDDM)
- Lock screen (Hyprlock)
- sudo prompts (if device has been suspended)
- Polkit authentication dialogs (if device has been suspended)

## Solution

**Both fixes must be applied** to fully resolve the issue:

### Fix 1: PAM Timeout Parameter

Add `timeout=10` parameter to all `pam_fprintd.so` lines in PAM configuration files.

**Before:**
```
auth      sufficient pam_fprintd.so
```

**After:**
```
auth      sufficient pam_fprintd.so timeout=10
```

This limits the fingerprint reader wait time to 10 seconds before falling through to password authentication.

### Fix 2: Disable USB Autosuspend for Fingerprint Reader

Create a udev rule to prevent the fingerprint reader from being suspended:

**File**: `/etc/udev/rules.d/99-fingerprint-no-autosuspend.rules`
```
# Disable USB autosuspend for Synaptics fingerprint reader (06cb:00f9)
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="06cb", ATTR{idProduct}=="00f9", TEST=="power/control", ATTR{power/control}="on"
```

**Or** add to TLP configuration:

**File**: `/etc/tlp.d/01-goldendragon.conf`
```
# Exclude fingerprint reader from USB autosuspend
USB_DENYLIST="06cb:00f9"
```

This keeps the fingerprint reader always awake and ready to respond instantly.

## Apply the Fix

### Option 1: Run the fix script (Recommended)

```bash
cd ~/dotfiles/hosts/goldendragon
bash ./fix-fingerprint-delays.sh
```

This script will:
- Back up all existing PAM files to `/etc/pam.d/.dragonarchy-backups/`
- Add `timeout=10` to all `pam_fprintd.so` lines
- Create udev rule to disable USB autosuspend for the fingerprint reader
- Reload udev rules and apply changes immediately
- Verify all changes

### Option 2: Manual fix

**Step A: Fix PAM timeout**

Edit each PAM file and add `timeout=10` to the `pam_fprintd.so` line:

```bash
sudo nano /etc/pam.d/sudo
sudo nano /etc/pam.d/polkit-1
sudo nano /etc/pam.d/system-local-login
sudo nano /etc/pam.d/sddm
```

**Step B: Fix USB autosuspend**

1. Identify your fingerprint reader USB ID:
   ```bash
   lsusb | grep -i fingerprint
   # Example output: Bus 003 Device 007: ID 06cb:00f9 Synaptics, Inc.
   ```

2. Create udev rule (replace `06cb` and `00f9` with your device's vendor:product ID):
   ```bash
   sudo nano /etc/udev/rules.d/99-fingerprint-no-autosuspend.rules
   ```
   
   Add:
   ```
   ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="06cb", ATTR{idProduct}=="00f9", TEST=="power/control", ATTR{power/control}="on"
   ```

3. Reload udev rules:
   ```bash
   sudo udevadm control --reload-rules
   sudo udevadm trigger --subsystem-match=usb
   ```

4. Verify (should show "on" not "auto"):
   ```bash
   grep . /sys/bus/usb/devices/*/power/control 2>/dev/null | grep -i 06cb
   ```

### Option 3: Reinstall via setup script

The `setup.sh` script has been updated to include the timeout parameter. You can re-run the fingerprint setup:

```bash
cd ~/dotfiles/hosts/goldendragon
bash setup.sh
```

The `ensure_pam_fprintd_enabled` function will now add `timeout=10` automatically.

## Verification

After applying the fix, test authentication:

1. **Lock screen test:**
   ```bash
   loginctl lock-session
   # Try unlocking with password - should respond within 10 seconds
   ```

2. **sudo test:**
   ```bash
   sudo true
   # Should prompt and respond within 10 seconds
   ```

3. **Fingerprint test:**
   ```bash
   fprintd-verify
   # Should complete within 10 seconds
   ```

4. **Check PAM configuration:**
   ```bash
   grep -r "pam_fprintd.so" /etc/pam.d/
   # All lines should show: pam_fprintd.so timeout=10
   ```

5. **Verify USB autosuspend is disabled:**
   ```bash
   # Find fingerprint reader device
   lsusb | grep -i fingerprint
   
   # Check power control status (should show "on" not "auto")
   grep . /sys/bus/usb/devices/*/idVendor /sys/bus/usb/devices/*/idProduct /sys/bus/usb/devices/*/power/control 2>/dev/null | grep -B2 "06cb" | grep "power/control"
   # Expected: power/control:on
   
   # Or check all USB devices
   for d in /sys/bus/usb/devices/*/power/control; do 
     echo "$d: $(cat $d)"; 
   done | grep -v "auto" | head -5
   ```

## Affected Files

The following PAM configuration files are modified:

- `/etc/pam.d/sudo`
- `/etc/pam.d/polkit-1`
- `/etc/pam.d/system-local-login`
- `/etc/pam.d/sddm`

Additionally, the dotfiles repository includes these static configurations:
- `hosts/goldendragon/etc/pam.d/polkit-1`
- `hosts/goldendragon/etc/pam.d/hyprlock` (references the timeout in comments)

## Troubleshooting

### Issue persists after fix

1. **Verify PAM changes applied:**
   ```bash
   sudo grep "pam_fprintd.so" /etc/pam.d/sudo /etc/pam.d/polkit-1 /etc/pam.d/system-local-login /etc/pam.d/sddm
   ```
   All lines should show `timeout=10`.

2. **Verify USB autosuspend fix applied:**
   ```bash
   # Check udev rule exists
   cat /etc/udev/rules.d/99-fingerprint-no-autosuspend.rules
   
   # Check device power status
   lsusb | grep -i fingerprint
   # Note the vendor:product ID (e.g., 06cb:00f9)
   
   # Find device path and check power control
   find /sys/bus/usb/devices -name "power" -type d -exec sh -c '
     for d; do
       parent=$(dirname "$d")
       if [ -f "$parent/idVendor" ] && [ -f "$parent/idProduct" ]; then
         vid=$(cat "$parent/idVendor")
         pid=$(cat "$parent/idProduct")
         ctl=$(cat "$d/control")
         echo "$vid:$pid -> $ctl"
       fi
     done
   ' sh {} + | grep 06cb
   # Should show: 06cb:00f9 -> on
   ```

3. **Check fprintd service status and logs:**
   ```bash
   sudo systemctl status fprintd.service
   sudo journalctl -u fprintd.service -n 50
   ```
   Look for USB errors or device disconnection messages.

4. **Test fingerprint reader directly:**
   ```bash
   fprintd-list $USER
   fprintd-verify
   ```
   Should complete quickly (within seconds, not 40+ seconds).

5. **Force device wake-up:**
   ```bash
   # Find fingerprint device path
   FP_DEV=$(find /sys/bus/usb/devices -type f -name idVendor -exec sh -c 'grep -l "06cb" "$1"' _ {} \; | head -1 | xargs dirname)
   
   # Force it to stay on
   echo "on" | sudo tee "$FP_DEV/power/control"
   
   # Verify
   cat "$FP_DEV/power/control"
   # Should output: on
   ```

6. **Restart fprintd service:**
   ```bash
   sudo systemctl restart fprintd.service
   fprintd-verify
   ```

### Fingerprint reader not detected

If the fingerprint reader isn't detected:

```bash
lsusb | grep -i fingerprint
sudo systemctl restart fprintd.service
fprintd-list $USER
```

### Restore from backup

If you need to restore the original PAM configuration:

```bash
# List backups
ls -la /etc/pam.d/.dragonarchy-backups/

# Restore a specific file
sudo cp /etc/pam.d/.dragonarchy-backups/timeout-fix-YYYYMMDD-HHMMSS/sudo /etc/pam.d/sudo
```

## Why firedragon doesn't have this issue

The `firedragon` host doesn't have fingerprint authentication configured, so it:
1. Doesn't use `pam_fprintd.so` (no PAM timeout)
2. Doesn't have a fingerprint reader affected by USB autosuspend

## Why it works fine during an active session

During an active session:
- The fingerprint reader is awake and actively responding to authentication requests
- The USB device hasn't gone into suspend mode due to recent activity
- `fprintd` service is running and maintaining communication with the device

At login/lock screens (especially after the screen has been locked for a while):
- The fingerprint reader may have been suspended by USB power management
- The device needs to wake up and reinitialize before responding
- This wake-up process takes 30-40+ seconds without the USB autosuspend fix

## Technical Details

### PAM Module Behavior

- `auth sufficient`: If this module succeeds, authentication is granted immediately. If it fails, PAM continues to the next module.
- Without `timeout=`: The module waits indefinitely (or for a very long system default) for the fingerprint reader to respond.
- With `timeout=10`: The module gives up after 10 seconds and falls through to the next authentication method (password).

### Why this started happening

The issue appeared after:
1. Installing `fprintd` and `libfprint` packages
2. Adding `pam_fprintd.so` to PAM configuration files
3. TLP's USB autosuspend putting the fingerprint reader to sleep
4. The combination of PAM waiting + USB wake-up creating 40+ second delays

### Alternative timeout values

You can adjust the timeout value based on your preferences:

- `timeout=5`: Faster fallback to password (5 seconds)
- `timeout=15`: More time for fingerprint scanning (15 seconds)
- `timeout=10`: Recommended balance (10 seconds)

To change the timeout, edit the PAM files and adjust the value:
```bash
sudo sed -i 's/timeout=[0-9]\+/timeout=5/g' /etc/pam.d/sudo
```

## References

- [fprintd documentation](https://fprint.freedesktop.org/)
- [PAM module documentation](https://www.linux-pam.org/Linux-PAM-html/)
- [Arch Wiki: Fingerprint authentication](https://wiki.archlinux.org/title/Fprint)
