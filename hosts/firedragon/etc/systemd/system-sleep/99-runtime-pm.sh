#!/bin/bash
# FireDragon runtime PM override for devices that misbehave with s2idle.

DEVICES=(
    "/sys/bus/pci/devices/0000:02:00.0/power/control" # NVMe
    "/sys/bus/pci/devices/0000:01:00.0/power/control" # Intel Wi-Fi
    "/sys/bus/pci/devices/0000:03:00.3/power/control" # USB controller
)

set_state() {
    local state="$1"
    for path in "${DEVICES[@]}"; do
        if [[ -w "$path" ]]; then
            echo "$state" > "$path" 2>/dev/null || true
        fi
    }
}

case "$1" in
    pre)
        set_state "on"
        ;;
    post)
        set_state "auto"
        ;;
esac

exit 0

