#!/bin/bash
# Disable spurious ACPI wakeup sources on goldendragon (ThinkPad P16s Gen 4).
#
# /proc/acpi/wakeup TOGGLES a device's state when you write its name to it.
# We must first CHECK if the device is enabled, then and only then write to it.
#
# Run at: boot (via systemd service) AND after resume (via system-sleep hook).

WAKEUP=/proc/acpi/wakeup

# Devices that must never be wakeup sources.
# SLPB (sleep button) is intentionally kept enabled.
DISABLE_LIST=(AWAC LID XHCI RP01 RP09 RP11 RP12 TXHC TDM0 TDM1 TRP0 TRP2)

[ -f "$WAKEUP" ] || { logger -t acpi-wakeup "ERROR: $WAKEUP not found"; exit 1; }

for device in "${DISABLE_LIST[@]}"; do
    # Exact match: "^DEVICE<tab>" followed by anything containing "*enabled"
    if grep -qE "^${device}[[:space:]].*\*enabled" "$WAKEUP" 2>/dev/null; then
        echo "$device" > "$WAKEUP"
        logger -t acpi-wakeup "Disabled wakeup: $device"
    fi
done

logger -t acpi-wakeup "Wakeup disable pass complete. Remaining enabled:"
grep "\*enabled" "$WAKEUP" | awk '{print $1}' | xargs -I{} logger -t acpi-wakeup "  enabled: {}"
