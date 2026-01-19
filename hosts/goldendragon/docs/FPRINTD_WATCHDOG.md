# Fprintd Watchdog System

## Problem

Hyprlock (and other lock screens) sometimes don't properly release the fingerprint device after authentication, especially after:
- System suspend/resume
- Long idle periods  
- Multiple failed authentication attempts

This causes the "Device was already claimed" error, making fingerprint authentication completely non-functional until fprintd is manually restarted.

## Solution: Multi-Layered Watchdog System

This implements a **three-layer defense** against stuck fingerprint device claims:

### Layer 1: Suspend/Resume Hook
**File**: `/usr/lib/systemd/system-sleep/99-fprintd-reset.sh`

- **Before suspend**: Stops fprintd to release all device claims
- **After resume**: Starts fresh fprintd instance with clean state
- **Prevents**: Device claims persisting across suspend/resume cycles

### Layer 2: Periodic Watchdog
**Files**: 
- `~/.local/bin/fprintd-watchdog` (monitoring script)
- `~/.config/systemd/user/fprintd-watchdog.service` (systemd service)
- `~/.config/systemd/user/fprintd-watchdog.timer` (runs every 30 minutes)

**How it works:**
1. Checks fprintd logs every 30 minutes
2. Counts "Device was already claimed" errors in last 5 minutes
3. If >3 errors detected, automatically restarts fprintd
4. Sends desktop notification when restart occurs

**Benefits**:
- Auto-recovers from stuck states without manual intervention
- Runs in background, no user action needed
- Low overhead (only runs every 30 minutes)

### Layer 3: Manual Recovery
**File**: `restart-fprintd.sh`

Quick manual recovery script when needed:
```bash
bash ~/dotfiles/hosts/goldendragon/restart-fprintd.sh
```

## Installation

### Automatic (via setup.sh)

The watchdog system is automatically installed during fingerprint setup:

```bash
cd ~/dotfiles/hosts/goldendragon
bash setup.sh
```

### Manual Installation

If not installed automatically:

```bash
cd ~/dotfiles/hosts/goldendragon
bash ./install-fprintd-watchdog.sh
```

This will:
1. Install system-sleep hook
2. Install watchdog binary
3. Install and enable systemd user timer
4. Optionally configure sudo permissions for automatic restart

## Verify Installation

### Check system-sleep hook:
```bash
ls -la /usr/lib/systemd/system-sleep/99-fprintd-reset.sh
```

### Check watchdog timer status:
```bash
systemctl --user status fprintd-watchdog.timer
```

Should show: **Active: active (waiting)**

### Check watchdog logs:
```bash
journalctl --user -u fprintd-watchdog.service -n 20
```

### Test suspend/resume manually:
```bash
# Before testing, check fprintd is running
systemctl status fprintd.service

# Suspend and resume your system
systemctl suspend

# After resume, check logs
journalctl -u fprintd.service --since "5 minutes ago" | grep -E "Starting|Started|Stopping|Stopped"
```

You should see fprintd being stopped before suspend and started after resume.

## Configuration

### Adjust watchdog frequency

Edit the timer file:
```bash
nano ~/.config/systemd/user/fprintd-watchdog.timer
```

Change `OnUnitActiveSec=30min` to your preferred interval (e.g., `15min`, `1h`).

Then reload:
```bash
systemctl --user daemon-reload
systemctl --user restart fprintd-watchdog.timer
```

### Adjust error threshold

Edit the watchdog script:
```bash
nano ~/.local/bin/fprintd-watchdog
```

Change `if [ "$RECENT_ERRORS" -gt 3 ]` to your preferred threshold.

### Enable automatic restart without sudo prompt

Add to `/etc/sudoers.d/fprintd-watchdog`:
```
your_username ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart fprintd.service
your_username ALL=(ALL) NOPASSWD: /usr/bin/systemctl stop fprintd.service
your_username ALL=(ALL) NOPASSWD: /usr/bin/systemctl start fprintd.service
```

Set correct permissions:
```bash
sudo chmod 0440 /etc/sudoers.d/fprintd-watchdog
```

**Note**: The install script can do this automatically if you answer "yes" to the prompt.

## Troubleshooting

### Watchdog not running

```bash
# Check timer status
systemctl --user status fprintd-watchdog.timer

# If not running, enable and start
systemctl --user enable fprintd-watchdog.timer
systemctl --user start fprintd-watchdog.timer
```

### Watchdog can't restart fprintd

If you see "Could not restart fprintd" in logs:

1. **Option A**: Configure sudo permissions (see above)
2. **Option B**: Manually restart when you see issues:
   ```bash
   sudo systemctl restart fprintd.service
   ```

### Sleep hook not working

```bash
# Check if hook exists
ls -la /usr/lib/systemd/system-sleep/99-fprintd-reset.sh

# Check hook logs after suspend/resume
journalctl -t fprintd-reset --since "10 minutes ago"
```

### Too many restarts happening

If watchdog is restarting fprintd too frequently, there may be a deeper issue:

1. **Check hyprlock version**:
   ```bash
   hyprlock --version
   ```
   Consider updating if on an older version.

2. **Check for USB power management conflicts**:
   ```bash
   # Verify fingerprint reader stays powered
   grep -r "06cb" /sys/bus/usb/devices/*/idVendor 2>/dev/null | while read line; do
     dev=$(dirname $(echo $line | cut -d: -f1))
     echo "Power: $(cat $dev/power/control)"
   done
   ```
   Should show "on" not "auto".

3. **Check fprintd logs for patterns**:
   ```bash
   journalctl -u fprintd.service --since "1 hour ago" | grep -E "error|failed|claim"
   ```

## Disable Watchdog (if needed)

If you want to disable the watchdog system:

```bash
# Stop and disable timer
systemctl --user stop fprintd-watchdog.timer
systemctl --user disable fprintd-watchdog.timer

# Remove sleep hook
sudo rm /usr/lib/systemd/system-sleep/99-fprintd-reset.sh
```

## Technical Details

### Why suspend/resume is problematic

When the system suspends:
1. Hyprlock locks the screen and claims the fingerprint device
2. System enters suspend with the claim still active
3. On resume, the USB device may reset or change state
4. Fprintd's internal state doesn't match the hardware state
5. Device remains "claimed" but non-functional

The sleep hook solves this by forcing a clean stop/start cycle.

### Why periodic checking is needed

Even with the sleep hook, device claims can get stuck due to:
- Hyprlock bugs/crashes
- PAM timeout edge cases
- DBus communication failures
- Multi-user concurrent access

The watchdog provides a safety net by periodically checking for stuck states and auto-recovering.

### Performance Impact

- **Sleep hook**: Negligible (only runs on suspend/resume)
- **Watchdog timer**: Minimal (runs once every 30 minutes, completes in <1 second)
- **Total overhead**: < 0.01% CPU/memory usage

## Related Documentation

- [PAM_FINGERPRINT_TIMEOUT.md](PAM_FINGERPRINT_TIMEOUT.md) - Original timeout issue and fixes
- [FIX_FINGERPRINT_CLAIMED.md](../FIX_FINGERPRINT_CLAIMED.md) - Manual recovery guide
- [FINGERPRINT_QUICKSTART.md](../FINGERPRINT_QUICKSTART.md) - Quick reference

## Known Issues & Workarounds

### Issue: hyprlock version <0.4.0

Older versions of hyprlock have bugs with device release. Update to the latest version:
```bash
paru -S hyprlock
```

### Issue: Multiple authentication dialogs

If you see multiple fingerprint prompts, you may have conflicting PAM configurations. Check:
```bash
grep -r "pam_fprintd" /etc/pam.d/
```

Ensure only one fingerprint auth line per PAM file.

### Issue: Fingerprint works but password doesn't

This can happen if hyprlock crashes during fingerprint auth. The password prompt should still work. If not:
```bash
# Switch to TTY2 (Ctrl+Alt+F2)
# Login
# Kill hyprlock
pkill -9 hyprlock
# Switch back to GUI (Ctrl+Alt+F1 or F7)
```

## Future Improvements

Potential enhancements being considered:

1. **DBus monitoring**: Watch for claim/release events in real-time
2. **Proactive release**: Force release after configurable timeout
3. **Integration with hyprlock**: Upstream fix to ensure proper device release
4. **Smart frequency**: Increase watchdog frequency after detecting issues

## Feedback & Issues

If you experience fingerprint issues not resolved by this watchdog system, please collect:

```bash
# Fprintd service logs
journalctl -u fprintd.service --since "1 hour ago" > fprintd.log

# Watchdog logs  
journalctl --user -u fprintd-watchdog.service --since "1 hour ago" > watchdog.log

# Sleep hook logs
journalctl -t fprintd-reset --since "1 day ago" > sleep-hook.log

# System info
hyprlock --version > system-info.txt
fprintd --version >> system-info.txt
lsusb | grep -i fingerprint >> system-info.txt
```

Then report the issue with these logs.
