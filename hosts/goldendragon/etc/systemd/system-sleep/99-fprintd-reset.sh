#!/usr/bin/env bash
# Reset fprintd service AND USB device on suspend/resume to prevent corruption
# This script runs before suspend and after resume

USB_DEVICE="3-3"
USB_DEVICE_PATH="/sys/bus/usb/devices/${USB_DEVICE}"
USB_DRIVER_PATH="/sys/bus/usb/drivers/usb"

case "${1}" in
  pre)
    # Before suspend: stop fprintd and unbind USB device
    logger -t fprintd-reset "Stopping fprintd before suspend"
    systemctl stop fprintd.service
    
    logger -t fprintd-reset "Unbinding USB fingerprint device to prevent corruption"
    if [ -d "$USB_DEVICE_PATH" ] && [ -f "$USB_DRIVER_PATH/unbind" ]; then
      echo "$USB_DEVICE" > "$USB_DRIVER_PATH/unbind" 2>/dev/null || true
      logger -t fprintd-reset "USB device unbound"
    fi
    ;;
  post)
    # After resume: rebind USB device and start fprintd
    logger -t fprintd-reset "Rebinding USB fingerprint device after resume"
    sleep 2
    
    if [ -f "$USB_DRIVER_PATH/bind" ]; then
      echo "$USB_DEVICE" > "$USB_DRIVER_PATH/bind" 2>/dev/null || true
      sleep 1
    fi
    
    # Ensure power stays on
    if [ -f "$USB_DEVICE_PATH/power/control" ]; then
      echo "on" > "$USB_DEVICE_PATH/power/control" 2>/dev/null || true
      logger -t fprintd-reset "USB power set to on"
    fi
    
    # Reset device authorization to clear any stuck states
    if [ -f "$USB_DEVICE_PATH/authorized" ]; then
      echo 0 > "$USB_DEVICE_PATH/authorized" 2>/dev/null || true
      sleep 0.5
      echo 1 > "$USB_DEVICE_PATH/authorized" 2>/dev/null || true
      logger -t fprintd-reset "USB device authorization reset"
    fi
    
    sleep 2
    logger -t fprintd-reset "Starting fprintd with fresh USB device"
    systemctl start fprintd.service
    ;;
esac
