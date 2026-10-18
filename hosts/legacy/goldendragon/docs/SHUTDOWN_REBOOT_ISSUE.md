# Shutdown Reboot Issue - GoldenDragon

## Problem

When attempting to shut down the system (`shutdown -h now`, `poweroff`, or via GUI), the system automatically reboots instead of powering off completely.

**Symptoms:**

- Running `shutdown -h now` or `systemctl poweroff` causes the system to restart
- System goes through shutdown sequence but then immediately boots back up
- This happens consistently, not intermittently

## Root Cause

Multiple ACPI wake devices are enabled on the ThinkPad P16s Gen 4, which can trigger system wake events during the shutdown process. When these wake events occur while the system is powering down, the firmware interprets this as a reboot signal rather than allowing complete power-off.

**Problematic wake-enabled devices:**

- **AWAC** - ACPI timer that can trigger spurious wakes
- **LID** - Lid switch (vibration during shutdown can trigger)
- **XHCI** - USB controller (USB devices can send wake signals)
- **RP01, RP09, RP11, RP12** - PCIe root ports
- **TXHC, TDM0, TDM1, TRP0, TRP2** - Thunderbolt controllers

These devices are enabled for wake from S3 (suspend) and S4 (hibernate) states, but can also interfere with the shutdown (S5) process.

## Solution

Disable ACPI wake for the problematic devices. This prevents them from triggering wake events during shutdown while still allowing normal suspend/resume to work.

### Quick Fix

Run the automated fix script:

```bash
cd ~/dotfiles/hosts/goldendragon
bash ./fix-shutdown-reboot-issue.sh
```

This script will:

1. Backup current wake settings
2. Disable wake for problematic devices
3. Create a systemd service to persist settings across reboots
4. Enable and start the service

### Manual Fix

If you prefer to apply the fix manually:

**Step 1: Check current wake settings**

```bash
cat /proc/acpi/wakeup | grep enabled
```

**Step 2: Disable problematic devices**

For each problematic device (AWAC, LID, XHCI, RP01, RP09, RP11, RP12, TXHC, TDM0, TDM1, TRP0, TRP2):

```bash
echo "AWAC" | sudo tee /proc/acpi/wakeup
echo "LID" | sudo tee /proc/acpi/wakeup
echo "XHCI" | sudo tee /proc/acpi/wakeup
# ... repeat for each device
```

**Step 3: Create systemd service to persist settings**

Create `/etc/systemd/system/disable-acpi-wakeup.service`:

```ini
[Unit]
Description=Disable ACPI wake devices to prevent spurious wakeups
DefaultDependencies=no
Before=sysinit.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c '\
  for device in AWAC LID XHCI RP01 RP09 RP11 RP12 TXHC TDM0 TDM1 TRP0 TRP2; do \
    if grep -q "^${device}.*\*enabled" /proc/acpi/wakeup 2>/dev/null; then \
      echo "$device" > /proc/acpi/wakeup; \
      logger -t acpi-wakeup "Disabled wake for $device"; \
    fi; \
  done'

[Install]
WantedBy=sysinit.target
```

**Step 4: Enable the service**

```bash
sudo systemctl daemon-reload
sudo systemctl enable disable-acpi-wakeup.service
sudo systemctl start disable-acpi-wakeup.service
```

## Verification

### Test Shutdown

After applying the fix, test shutdown:

```bash
sudo shutdown -h now
```

The system should:

1. Complete the shutdown sequence
2. Power off completely
3. **NOT** automatically reboot

### Verify Wake Settings

Check that problematic devices are disabled:

```bash
cat /proc/acpi/wakeup | grep -E "AWAC|LID|XHCI|RP0|RP1|TXHC|TDM|TRP"
```

Each should show `*disabled` instead of `*enabled`.

### Verify Service

Check that the systemd service is running:

```bash
systemctl status disable-acpi-wakeup.service
```

Should show `active (exited)` or `enabled`.

Check system logs:

```bash
journalctl -u disable-acpi-wakeup.service
```

Should show messages like:

```
Disabled wake for AWAC
Disabled wake for LID
...
```

## Impact on Suspend/Resume

**Important:** Disabling these wake devices for ACPI events does **NOT** break suspend/resume functionality. The system will still:

- Suspend normally when requested
- Resume from suspend via power button
- Resume from suspend via keyboard input
- Resume from suspend via lid open (hardware event, not ACPI wake)

The only thing disabled is **spurious wake events** that can occur during shutdown or when the system is supposed to remain powered off.

## Troubleshooting

### Shutdown still causes reboot

1. **Verify wake settings are applied:**

   ```bash
   cat /proc/acpi/wakeup | grep enabled
   ```

   Should show minimal devices enabled (ideally only SLPB for sleep button).

2. **Check service status:**

   ```bash
   systemctl status disable-acpi-wakeup.service
   journalctl -u disable-acpi-wakeup.service
   ```

3. **Check for additional wake sources:**

   ```bash
   # Check RTC (real-time clock) wake
   cat /sys/class/rtc/rtc0/wakealarm
   
   # Should be empty; if not, disable it:
   echo 0 | sudo tee /sys/class/rtc/rtc0/wakealarm
   ```

4. **Check BIOS/UEFI settings:**
   Some firmware settings can override OS-level wake configurations:
   - Wake on LAN (disable if not needed)
   - USB wake support (consider disabling)
   - Intel AMT / vPro wake features (disable if not needed)

5. **Check for USB devices causing wake:**

   ```bash
   # List USB devices and their power management
   for d in /sys/bus/usb/devices/*/power/wakeup; do
     echo "$d: $(cat $d)"
   done
   ```

   Disable wake for specific USB devices:

   ```bash
   echo "disabled" | sudo tee /sys/bus/usb/devices/DEVICE_ID/power/wakeup
   ```

### Service fails to start

Check service logs:

```bash
sudo journalctl -xe -u disable-acpi-wakeup.service
```

Common issues:

- Missing `/proc/acpi/wakeup` (check if ACPI is enabled in kernel)
- Permission issues (service should run as root via systemd)

## Alternative Solutions

### BIOS/UEFI Level

If the software fix doesn't work, you can also disable wake sources in BIOS:

1. Reboot and enter BIOS/UEFI setup (usually F1 or F12 on ThinkPads)
2. Navigate to Power settings
3. Disable:
   - Wake on LAN
   - USB wake support
   - Thunderbolt wake support

### Kernel Parameter

As a last resort, you can pass kernel parameters to disable ACPI wake completely:

Add to kernel command line (bootloader configuration):

```
acpi.ec_no_wakeup=1
```

**Warning:** This may affect suspend/resume functionality.

## Related Issues

This issue is related to the fingerprint reader USB wake issue but is a separate problem:

- **Fingerprint issue:** USB device waking up slowly causes login delays
- **Shutdown issue:** Multiple wake-enabled devices causing spurious reboots

Both are caused by overly aggressive wake configuration but affect different system functions.

## References

- [Arch Wiki: Power management](https://wiki.archlinux.org/title/Power_management)
- [Arch Wiki: Suspend and hibernate](https://wiki.archlinux.org/title/Power_management/Suspend_and_hibernate)
- [ThinkPad P16s specifications](https://www.lenovo.com/us/en/p/laptops/thinkpad/thinkpadp/thinkpad-p16s-gen-4-16-inch-intel/len101t0105)

## Diagnostic Script

Run the comprehensive diagnostic script:

```bash
cd ~/dotfiles/hosts/goldendragon
bash ./diagnose-both-issues.sh
```

This will check:

- Current wake device status
- Service configuration
- Known problematic devices
- Provide specific recommendations
