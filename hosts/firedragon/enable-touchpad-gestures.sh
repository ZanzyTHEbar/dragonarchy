#!/bin/bash
# Enable touchpad gestures by adding kernel parameter for ASUS I2C touchpad
# This fixes the libinput gesture detection issue

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
log_info "🔧 Enabling touchpad gesture support for ASUS I2C touchpad"
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root (use sudo)"
   exit 1
fi

# Find Limine configuration
LIMINE_CFG=""

log_info "Searching for Limine configuration..."

# Search in multiple locations (both .cfg and .conf extensions)
search_paths=(
    "/boot/limine.conf"
    "/boot/limine.cfg"
    "/boot/EFI/BOOT/limine.conf"
    "/boot/EFI/BOOT/limine.cfg"
    "/boot/EFI/Boot/limine.conf"
    "/boot/EFI/Boot/limine.cfg"
    "/boot/efi/limine.conf"
    "/boot/efi/limine.cfg"
    "/boot/efi/EFI/BOOT/limine.conf"
    "/boot/efi/EFI/BOOT/limine.cfg"
    "/efi/limine.conf"
    "/efi/limine.cfg"
    "/esp/limine.conf"
    "/esp/limine.cfg"
)

for path in "${search_paths[@]}"; do
    if [[ -f "$path" ]]; then
        LIMINE_CFG="$path"
        break
    fi
done

# If not found, do a broader search
if [[ -z "$LIMINE_CFG" ]]; then
    log_info "Searching entire boot partition..."
    LIMINE_CFG=$(find /boot -name "limine.conf" -o -name "limine.cfg" 2>/dev/null | head -1)
fi

if [[ -z "$LIMINE_CFG" ]]; then
    log_error "Could not find Limine configuration file!"
    echo
    log_info "Searched locations:"
    for path in "${search_paths[@]}"; do
        echo "  - $path"
    done
    echo
    log_info "Manual steps:"
    echo "  1. Find your Limine config: sudo find /boot -name 'limine.conf'"
    echo "  2. Edit it: sudo nano /path/to/limine.conf"
    echo "  3. Add 'i2c_hid.enable_gestures=1' to end of each kernel_cmdline: line"
    echo "  4. Save and reboot"
    echo
    log_info "Or share the output of: sudo ls -la /boot/"
    exit 1
fi

log_info "Found Limine configuration: $LIMINE_CFG"

# Backup the configuration
BACKUP="${LIMINE_CFG}.backup.$(date +%Y%m%d-%H%M%S)"
cp "$LIMINE_CFG" "$BACKUP"
log_success "Created backup: $BACKUP"

# Check if parameter already exists
if grep -q "i2c_hid.enable_gestures=1" "$LIMINE_CFG"; then
    log_warning "Kernel parameter 'i2c_hid.enable_gestures=1' already present in config"
    log_info "No changes needed"
    exit 0
fi

# Add the kernel parameter to all kernel_cmdline entries
log_info "Adding i2c_hid.enable_gestures=1 to kernel command line..."

# Use sed to add the parameter to kernel_cmdline: lines (Limine format)
sed -i '/kernel_cmdline:/s/$/ i2c_hid.enable_gestures=1/' "$LIMINE_CFG"

# Verify the change
if grep -q "i2c_hid.enable_gestures=1" "$LIMINE_CFG"; then
    log_success "Successfully added kernel parameter!"
    echo
    log_info "📋 Modified lines:"
    grep "kernel_cmdline:.*i2c_hid.enable_gestures=1" "$LIMINE_CFG" | while IFS= read -r line; do
        echo "  $line"
    done
    echo
    log_success "✅ Configuration updated successfully!"
    echo
    log_warning "⚠️  REBOOT REQUIRED"
    echo
    log_info "After reboot, test gestures with:"
    echo "  sudo libinput debug-events --device /dev/input/event7"
    echo "  (perform 3-finger swipes while it's running)"
    echo
else
    log_error "Failed to add kernel parameter"
    log_info "Restoring backup..."
    cp "$BACKUP" "$LIMINE_CFG"
    exit 1
fi

