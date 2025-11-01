#!/bin/bash
# Quick fix to add ACPI parameters to Limine bootloader for Asus VivoBook
# Run this on the FIREDRAGON host after setup

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo
log_info "🔧 Adding ACPI parameters for Asus VivoBook to Limine bootloader..."
echo

# Check if already applied
if grep -q "acpi_osi=!" /proc/cmdline; then
    log_success "✅ ACPI parameters already applied in current boot!"
    exit 0
fi

# ACPI parameters needed for Asus VivoBook
ASUS_PARAMS="acpi_osi=! acpi_osi='Windows 2020' acpi_backlight=native"

# Detect Limine configuration file
LIMINE_CONF=""
if sudo test -f "/boot/limine.conf"; then
    LIMINE_CONF="/boot/limine.conf"
    log_info "Found Limine config: /boot/limine.conf"
elif sudo test -f "/boot/limine/limine.conf"; then
    LIMINE_CONF="/boot/limine/limine.conf"
    log_info "Found Limine config: /boot/limine/limine.conf"
else
    log_error "❌ Limine configuration not found!"
    echo
    log_info "Expected locations:"
    echo "  • /boot/limine.conf"
    echo "  • /boot/limine/limine.conf"
    echo
    log_info "If you're using a different bootloader, add these parameters manually:"
    echo "  $ASUS_PARAMS"
    exit 1
fi

echo
log_info "Limine configuration: $LIMINE_CONF"

# Check if ACPI params already in config
if sudo grep -q "acpi_osi=!" "$LIMINE_CONF"; then
    log_success "✅ ACPI parameters already present in Limine config!"
    log_warning "But not in current boot - you need to reboot"
    exit 0
fi

# Backup the config
BACKUP="${LIMINE_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
log_info "Creating backup: $BACKUP"
sudo cp "$LIMINE_CONF" "$BACKUP"

# Show current CMDLINE
echo
log_info "Current CMDLINE in $LIMINE_CONF:"
sudo grep "^CMDLINE" "$LIMINE_CONF" || log_warning "No CMDLINE found"
echo

# Add ACPI parameters to CMDLINE
log_info "Adding ACPI parameters to CMDLINE..."
if sudo grep -q "^CMDLINE" "$LIMINE_CONF"; then
    # CMDLINE line exists, append to it
    sudo sed -i "/^CMDLINE/ s/\"$/ $ASUS_PARAMS\"/" "$LIMINE_CONF"
    log_success "✅ ACPI parameters added!"
else
    log_error "No CMDLINE line found in $LIMINE_CONF"
    log_info "You may need to add it manually"
    exit 1
fi

echo
log_info "New CMDLINE in $LIMINE_CONF:"
sudo grep "^CMDLINE" "$LIMINE_CONF"
echo

log_success "🎉 ACPI parameters successfully added to Limine!"
echo
log_warning "⚠️  REBOOT REQUIRED to apply changes"
echo
log_info "After reboot, verify with:"
echo "  cat /proc/cmdline | grep acpi_osi"
echo
log_info "Expected to see:"
echo "  acpi_osi=! acpi_osi='Windows 2020' acpi_backlight=native"
echo
