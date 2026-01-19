#!/usr/bin/env bash
# Fix fingerprint authentication delays on goldendragon
# 
# This script fixes two issues:
# 1. PAM timeout: adds timeout=10 to pam_fprintd.so to prevent indefinite waits
# 2. USB autosuspend: disables USB power management for the fingerprint reader
#
# Both fixes are needed to resolve the 40+ second delay at login/lock screens.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../scripts/lib/logging.sh"

log_step "Fixing fingerprint authentication delays..."

# Backup directory
BACKUP_DIR="/etc/pam.d/.dragonarchy-backups/timeout-fix-$(date +%Y%m%d-%H%M%S)"
sudo mkdir -p "$BACKUP_DIR"

fix_pam_file() {
  local pam_file="$1"
  
  if [[ ! -f "$pam_file" ]]; then
    log_warning "PAM file not found (skipping): $pam_file"
    return 0
  fi
  
  # Check if pam_fprintd.so exists in the file
  if ! sudo grep -qE '^\s*auth\s+.*pam_fprintd\.so' "$pam_file"; then
    log_info "No pam_fprintd.so found in: $pam_file (skipping)"
    return 0
  fi
  
  # Check if timeout parameter already exists
  if sudo grep -qE '^\s*auth\s+.*pam_fprintd\.so.*timeout=' "$pam_file"; then
    log_info "Timeout already configured in: $pam_file (skipping)"
    return 0
  fi
  
  # Backup the file
  sudo cp -a "$pam_file" "${BACKUP_DIR}/$(basename "$pam_file")"
  log_info "Backed up: $(basename "$pam_file") -> ${BACKUP_DIR}/$(basename "$pam_file")"
  
  # Add timeout=10 parameter to pam_fprintd.so line
  sudo sed -i.tmp \
    's/^\(\s*auth\s\+sufficient\s\+pam_fprintd\.so\)\s*$/\1 timeout=10/' \
    "$pam_file"
  
  # Verify the change
  if sudo grep -qE '^\s*auth\s+.*pam_fprintd\.so.*timeout=10' "$pam_file"; then
    log_success "Fixed timeout in: $pam_file"
    sudo rm -f "${pam_file}.tmp"
  else
    log_error "Failed to add timeout parameter to: $pam_file"
    sudo mv "${pam_file}.tmp" "$pam_file" 2>/dev/null || true
    return 1
  fi
}

# Fix all PAM files that have pam_fprintd.so
PAM_FILES=(
  /etc/pam.d/sudo
  /etc/pam.d/polkit-1
  /etc/pam.d/system-local-login
  /etc/pam.d/sddm
)

for pam_file in "${PAM_FILES[@]}"; do
  fix_pam_file "$pam_file"
done

log_success "PAM fingerprint timeout fix completed!"
log_info "Backups stored in: ${BACKUP_DIR}"
log_info ""

# Fix USB autosuspend issue
log_step "Fixing USB autosuspend for fingerprint reader..."

# Detect fingerprint reader
FINGERPRINT_USB_ID=$(lsusb 2>/dev/null | grep -Ei 'fingerprint|fprint|synaptics|validity|goodix|elan|egis' | awk '{print $6}' | head -1)

if [[ -z "$FINGERPRINT_USB_ID" ]]; then
  log_warning "Fingerprint reader not detected via lsusb. USB autosuspend fix skipped."
else
  log_info "Detected fingerprint reader: $FINGERPRINT_USB_ID"
  
  # Create udev rule to disable autosuspend for fingerprint reader
  UDEV_RULE="/etc/udev/rules.d/99-fingerprint-no-autosuspend.rules"
  VENDOR_ID="${FINGERPRINT_USB_ID%:*}"
  PRODUCT_ID="${FINGERPRINT_USB_ID#*:}"
  
  log_info "Creating udev rule to disable USB autosuspend..."
  sudo tee "$UDEV_RULE" >/dev/null <<EOF
# Disable USB autosuspend for fingerprint reader ($FINGERPRINT_USB_ID)
# This prevents the 30-40 second wakeup delay at login/lock screens.

ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="$VENDOR_ID", ATTR{idProduct}=="$PRODUCT_ID", TEST=="power/control", ATTR{power/control}="on"
EOF
  
  log_success "Created udev rule: $UDEV_RULE"
  
  # Reload udev rules
  log_info "Reloading udev rules..."
  sudo udevadm control --reload-rules
  sudo udevadm trigger --subsystem-match=usb
  
  # Apply to current device if present
  USB_DEVICE_PATH=$(find /sys/bus/usb/devices -name "power" -type d 2>/dev/null | while read -r pwr_dir; do
    dev_dir=$(dirname "$pwr_dir")
    if [[ -f "$dev_dir/idVendor" ]] && [[ -f "$dev_dir/idProduct" ]]; then
      vid=$(cat "$dev_dir/idVendor")
      pid=$(cat "$dev_dir/idProduct")
      if [[ "$vid" == "$VENDOR_ID" ]] && [[ "$pid" == "$PRODUCT_ID" ]]; then
        echo "$dev_dir"
        break
      fi
    fi
  done)
  
  if [[ -n "$USB_DEVICE_PATH" ]] && [[ -f "$USB_DEVICE_PATH/power/control" ]]; then
    log_info "Applying fix to current device..."
    echo "on" | sudo tee "$USB_DEVICE_PATH/power/control" >/dev/null
    log_success "USB autosuspend disabled for fingerprint reader"
  else
    log_warning "Fingerprint reader device path not found. Unplug and replug the device or reboot."
  fi
  
  log_info ""
  log_info "USB autosuspend fix applied. The fingerprint reader will no longer be suspended."
fi

log_info ""
log_success "All fixes completed!"
log_info ""
log_info "Next steps:"
log_info "  1. Reboot to ensure all changes take effect"
log_info "  2. Test login/lock screen - should respond immediately"
log_info "  3. If issues persist, check: sudo systemctl status fprintd.service"
log_info "  4. Verify fingerprint reader: fprintd-verify"
log_info ""
log_info "To verify USB autosuspend status:"
log_info "  lsusb -t | grep -i fingerprint -A5"
log_info "  cat /sys/bus/usb/devices/*/power/control | grep -v auto"
