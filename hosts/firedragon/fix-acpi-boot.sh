#!/bin/bash
# Quick fix to add ACPI parameters to the bootloader for Asus VivoBook
# Run this on the FIREDRAGON host after setup

set -e

# Resolve paths and source libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LOG_LIB="${PROJECT_ROOT}/scripts/lib/logging.sh"
BOOT_LIB="${PROJECT_ROOT}/scripts/lib/bootloader.sh"
# shellcheck disable=SC1091
source "$LOG_LIB"
# shellcheck disable=SC1091
source "$BOOT_LIB"

echo
log_info "🔧 Ensuring ACPI parameters for Asus VivoBook across bootloader configuration..."
echo

# ACPI parameters needed for Asus VivoBook
ASUS_PARAMS="acpi_osi=! acpi_osi='Windows 2020' acpi_backlight=native"

# Check if already applied in current boot
if grep -q "acpi_osi=!" /proc/cmdline; then
    log_success "✅ ACPI parameters already present in current kernel cmdline"
    exit 0
fi

bootloader="$(detect_bootloader)"
log_info "Detected bootloader: $bootloader"
if [[ "$bootloader" == "unknown" ]]; then
    log_warning "Unable to detect bootloader automatically; attempting best-effort update"
fi

# Ensure sudo availability
echo
log_info "Escalating privileges to modify bootloader configuration..."
if ! sudo -v 2>/dev/null; then
    log_error "❌ sudo authentication failed; cannot modify bootloader configuration"
    exit 1
fi

echo
if sudo env ASUS_PARAMS="$ASUS_PARAMS" LOG_LIB="$LOG_LIB" BOOT_LIB="$BOOT_LIB" bash -c '
    set -e
    # shellcheck disable=SC1091
    source "$LOG_LIB"
    # shellcheck disable=SC1091
    source "$BOOT_LIB"
    boot_append_kernel_params "$ASUS_PARAMS"
    boot_rebuild_if_changed
'; then
    log_success "🎉 ACPI parameters ensured across bootloader configuration"
    log_warning "⚠️  REBOOT REQUIRED to apply changes"
else
    log_error "❌ Failed to update bootloader configuration automatically"
    log_info "Please update your bootloader manually with parameters: $ASUS_PARAMS"
    exit 1
fi

echo
log_info "After reboot, verify with:"
echo "  cat /proc/cmdline | grep acpi_osi"
log_info "Expected output includes:"
echo "  $ASUS_PARAMS"
