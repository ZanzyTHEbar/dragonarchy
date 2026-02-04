#!/usr/bin/env bash
# Comprehensive diagnostic script for both goldendragon issues

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../../../scripts/lib/logging.sh"

log_step "GoldenDragon Issue Diagnostics"
log_info ""

# ========================================
# ISSUE 1: Login Delay (>40s)
# ========================================
log_step "Issue #1: Login Delay Diagnostics"
log_info ""

# Check PAM configuration
log_info "1. PAM Fingerprint Configuration:"
PAM_FILES=("/etc/pam.d/sudo" "/etc/pam.d/polkit-1" "/etc/pam.d/system-local-login" "/etc/pam.d/sddm")
for pam_file in "${PAM_FILES[@]}"; do
  if [ -f "$pam_file" ]; then
    if grep -q "pam_fprintd.so.*timeout" "$pam_file"; then
      timeout=$(grep "pam_fprintd.so" "$pam_file" | grep -oP 'timeout=\K\d+' || echo "MISSING")
      log_success "  ✅ $pam_file: timeout=$timeout"
    elif grep -q "pam_fprintd.so" "$pam_file"; then
      log_error "  ❌ $pam_file: pam_fprintd.so present but NO TIMEOUT (will cause delays)"
    else
      log_info "  ⊘ $pam_file: no fingerprint auth configured"
    fi
  fi
done

log_info ""

# Check fingerprint reader USB device
log_info "2. Fingerprint Reader USB Status:"
if lsusb | grep -qi "fingerprint\|06cb:00f9"; then
  FP_USB=$(lsusb | grep -i "fingerprint\|06cb:00f9" | head -1)
  log_success "  ✅ Device detected: $FP_USB"
  
  # Check USB power control
  log_info ""
  log_info "3. USB Power Management:"
  FP_VENDOR="06cb"
  FP_PRODUCT="00f9"
  
  found=false
  for dev_path in /sys/bus/usb/devices/*/idVendor; do
    if [ -f "$dev_path" ]; then
      vendor=$(cat "$dev_path" 2>/dev/null || echo "")
      if [ "$vendor" = "$FP_VENDOR" ]; then
        parent=$(dirname "$dev_path")
        product=$(cat "$parent/idProduct" 2>/dev/null || echo "")
        if [ "$product" = "$FP_PRODUCT" ]; then
          power_control=$(cat "$parent/power/control" 2>/dev/null || echo "unknown")
          if [ "$power_control" = "on" ]; then
            log_success "  ✅ USB power control: $power_control (device stays awake)"
          else
            log_error "  ❌ USB power control: $power_control (device will be suspended!)"
            log_info "     Fix: echo 'on' | sudo tee $parent/power/control"
          fi
          found=true
          break
        fi
      fi
    fi
  done
  
  if [ "$found" = false ]; then
    log_warning "  ⚠️  Could not find USB device path for power control check"
  fi
else
  log_error "  ❌ Fingerprint reader NOT DETECTED"
  log_info "     Check: lsusb | grep -i fingerprint"
fi

log_info ""

# Check udev rule
log_info "4. Udev Autosuspend Rule:"
UDEV_RULE="/etc/udev/rules.d/99-fingerprint-no-autosuspend.rules"
if [ -f "$UDEV_RULE" ]; then
  log_success "  ✅ Rule exists: $UDEV_RULE"
  grep -v "^#" "$UDEV_RULE" | grep -v "^$" | sed 's/^/     /'
else
  log_error "  ❌ Udev rule NOT FOUND"
  log_info "     Expected: $UDEV_RULE"
fi

log_info ""

# Check TLP configuration
log_info "5. TLP USB Denylist:"
TLP_CONF="/etc/tlp.d/01-goldendragon.conf"
if [ -f "$TLP_CONF" ]; then
  if grep -q 'USB_DENYLIST.*06cb:00f9' "$TLP_CONF"; then
    log_success "  ✅ Fingerprint reader excluded from TLP autosuspend"
  else
    log_error "  ❌ Fingerprint reader NOT in TLP denylist"
    log_info "     Add: USB_DENYLIST=\"06cb:00f9\""
  fi
else
  log_warning "  ⚠️  TLP config not found: $TLP_CONF"
fi

log_info ""

# Check sleep hook
log_info "6. System-Sleep Hook:"
SLEEP_HOOK="/usr/lib/systemd/system-sleep/99-fprintd-reset.sh"
if [ -f "$SLEEP_HOOK" ] && [ -x "$SLEEP_HOOK" ]; then
  log_success "  ✅ Sleep hook installed and executable"
else
  log_error "  ❌ Sleep hook NOT FOUND or not executable"
  log_info "     Expected: $SLEEP_HOOK"
fi

log_info ""

# Check fprintd service
log_info "7. Fprintd Service Status:"
if systemctl is-active fprintd.service >/dev/null 2>&1; then
  log_success "  ✅ fprintd.service is active"
else
  status=$(systemctl is-active fprintd.service 2>&1 || echo "inactive")
  log_warning "  ⚠️  fprintd.service status: $status"
  log_info "     Note: fprintd is socket-activated, inactive is normal when not in use"
fi

# Check watchdog
log_info ""
log_info "8. Fprintd Watchdog:"
# For user timers, check symlink existence (is-enabled always shows "disabled")
if [ -L ~/.config/systemd/user/timers.target.wants/fprintd-watchdog.timer ]; then
  log_success "  ✅ Watchdog timer enabled (symlink exists)"
  if systemctl --user is-active fprintd-watchdog.timer >/dev/null 2>&1; then
    log_success "  ✅ Watchdog timer active"
  else
    log_warning "  ⚠️  Watchdog timer not active"
  fi
else
  log_warning "  ⚠️  Watchdog timer not enabled (symlink missing)"
  log_info "     Install: bash ~/dotfiles/hosts/goldendragon/scripts/fingerprint/install-fprintd-watchdog.sh"
fi

# ========================================
# ISSUE 2: Shutdown Triggers Reboot
# ========================================
log_info ""
log_info ""
log_step "Issue #2: Shutdown/Reboot Diagnostics"
log_info ""

# Check ACPI wake devices
log_info "1. ACPI Wake-Enabled Devices:"
PROBLEMATIC_WAKE=("AWAC" "LID" "XHCI" "RP01" "RP09" "RP11" "RP12" "TXHC" "TDM0" "TDM1" "TRP0" "TRP2")
enabled_count=0
for device in "${PROBLEMATIC_WAKE[@]}"; do
  if grep -q "^${device}.*\*enabled" /proc/acpi/wakeup 2>/dev/null; then
    log_error "  ❌ $device: enabled (can trigger spurious wake/reboot)"
    ((enabled_count++))
  fi
done

if [ $enabled_count -eq 0 ]; then
  log_success "  ✅ No problematic wake devices enabled"
else
  log_error "  ❌ Found $enabled_count problematic wake device(s) enabled"
  log_info ""
  log_info "  These devices can cause the system to reboot instead of shutdown."
  log_info "  Run fix script: bash ${SCRIPT_DIR}/fix-shutdown-reboot-issue.sh"
fi

log_info ""

# Check if service exists
log_info "2. Wake Disable Service:"
if systemctl is-enabled disable-acpi-wakeup.service >/dev/null 2>&1; then
  log_success "  ✅ disable-acpi-wakeup.service is enabled"
else
  log_warning "  ⚠️  Service not found or not enabled"
  log_info "     This service persists wake settings across reboots"
  log_info "     Run: bash ${SCRIPT_DIR}/fix-shutdown-reboot-issue.sh"
fi

log_info ""

# All currently enabled wake devices
log_info "3. All Currently Enabled Wake Devices:"
awk '/\*enabled/ {print "  - " $1 " (" $4 ")"}' /proc/acpi/wakeup || log_info "  (none)"

log_info ""
log_info ""
log_step "Summary & Recommendations"
log_info ""

# Issue 1 summary
log_info "Issue #1: Login Delay (>40s)"
issue1_problems=0

if ! grep -q "pam_fprintd.so.*timeout" /etc/pam.d/sudo 2>/dev/null; then
  log_info "  ❌ PAM timeout not configured"
  ((issue1_problems++))
fi

if ! [ -f "/etc/udev/rules.d/99-fingerprint-no-autosuspend.rules" ]; then
  log_info "  ❌ Udev rule missing"
  ((issue1_problems++))
fi

if [ $issue1_problems -gt 0 ]; then
  log_error "  Status: NOT FIXED ($issue1_problems issues)"
  log_info "  Fix: bash ${SCRIPT_DIR}/fix-fingerprint-delays.sh"
else
  log_success "  Status: ✅ FIXED"
fi

log_info ""

# Issue 2 summary
log_info "Issue #2: Shutdown Triggers Reboot"
if [ $enabled_count -gt 0 ]; then
  log_error "  Status: NOT FIXED ($enabled_count problematic wake devices)"
  log_info "  Fix: bash ${SCRIPT_DIR}/fix-shutdown-reboot-issue.sh"
else
  log_success "  Status: ✅ FIXED"
fi

log_info ""
