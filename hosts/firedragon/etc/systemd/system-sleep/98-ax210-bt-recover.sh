#!/usr/bin/env bash
# Recover Intel AX210 Bluetooth (8087:0032) after resume and keep it out of USB autosuspend.
#
# Symptoms this targets:
# - bluetoothctl: "SetDiscoveryFilter failed: org.bluez.Error.NotReady"
# - dmesg: "Bluetooth: hci0: Opcode 0x0c03 failed: -110"
#
# systemd calls scripts in /etc/systemd/system-sleep with:
#   $1 = pre|post
#   $2 = suspend|hibernate|hybrid-sleep|suspend-then-hibernate

set -euo pipefail

VENDOR="8087"
PRODUCT="0032"

find_usb_dev() {
  local dev
  for dev in /sys/bus/usb/devices/*; do
    [[ -f "$dev/idVendor" && -f "$dev/idProduct" ]] || continue
    [[ "$(cat "$dev/idVendor")" == "$VENDOR" ]] || continue
    [[ "$(cat "$dev/idProduct")" == "$PRODUCT" ]] || continue
    basename "$dev"
    return 0
  done
  return 1
}

set_usb_power() {
  local dev="$1"
  local base="/sys/bus/usb/devices/$dev/power"

  [[ -w "$base/control" ]] && echo "on" > "$base/control" 2>/dev/null || true
  [[ -w "$base/autosuspend" ]] && echo "-1" > "$base/autosuspend" 2>/dev/null || true
  [[ -w "$base/autosuspend_delay_ms" ]] && echo "-1" > "$base/autosuspend_delay_ms" 2>/dev/null || true
}

bt_is_ready() {
  command -v btmgmt >/dev/null 2>&1 || return 1
  btmgmt --index 0 info >/dev/null 2>&1
}

reset_btusb() {
  local dev="$1"
  local intf_dir intf_name driver_name

  shopt -s nullglob
  for intf_dir in "/sys/bus/usb/devices/${dev}:1."*; do
    [[ -d "$intf_dir" ]] || continue
    [[ -L "$intf_dir/driver" ]] || continue
    driver_name="$(basename "$(readlink "$intf_dir/driver")")"
    [[ "$driver_name" == "btusb" ]] || continue

    intf_name="$(basename "$intf_dir")"
    echo "$intf_name" > /sys/bus/usb/drivers/btusb/unbind 2>/dev/null || true
    sleep 0.5
    echo "$intf_name" > /sys/bus/usb/drivers/btusb/bind 2>/dev/null || true
  done
}

case "${1:-}" in
  post)
    dev="$(find_usb_dev || true)"
    [[ -n "${dev:-}" ]] || exit 0

    # Re-assert power settings (resume can flip devices back to autosuspend)
    set_usb_power "$dev"

    # If BlueZ/controller is already happy, don't disrupt existing connections.
    if bt_is_ready; then
      exit 0
    fi

    # Recover: restart bluetooth + rebind btusb interfaces.
    systemctl stop bluetooth.service >/dev/null 2>&1 || true
    reset_btusb "$dev"
    systemctl start bluetooth.service >/dev/null 2>&1 || true
    ;;
esac

exit 0


