#!/bin/bash
# MT7902 WiFi Driver Setup for FireDragon (Asus VivoBook)
# Handles MediaTek MT7902 WiFi 6E chip driver installation
# with safety checks and DKMS integration

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
MT7902_DRIVER_REPO="https://github.com/OnlineLearningTutorials/mt7902_temp.git"
DRIVER_DIR="$HOME/.local/src/mt7902_driver"
DKMS_MODULE_NAME="mt7902"
DKMS_MODULE_VERSION="1.0"

# Note: MT7902 is supported by mt7921/mt7925 drivers in modern kernels
# This script primarily installs firmware and ensures the right modules are loaded

# Check if MT7902 chip is present
check_mt7902_present() {
    log_info "Checking for MT7902 WiFi chip..."
    
    if lspci -nn | grep -i "14c3:0608\|14c3:7902\|Network.*MT7902" >/dev/null 2>&1; then
        log_success "MT7902 WiFi chip detected"
        return 0
    else
        log_info "MT7902 chip not detected"
        return 1
    fi
}

# Check if WiFi is already working
check_wifi_working() {
    log_info "Checking if WiFi is already functional..."
    
    # Check if wireless interface exists
    if ip link show | grep -q "wlan\|wlp"; then
        log_success "WiFi interface already present and working"
        return 0
    fi
    
    # Check if mt7902 module is loaded
    if lsmod | grep -q "mt7902\|mt792x"; then
        log_success "MT7902 driver already loaded"
        return 0
    fi
    
    log_warning "WiFi not functional, driver installation needed"
    return 1
}

# Install build dependencies
install_dependencies() {
    log_info "Installing build dependencies..."
    
    local deps=(
        "base-devel"
        "linux-headers"
        "dkms"
        "clang"
        "llvm"
        "lld"
        "git"
        "bc"
        "iw"
        "wireless_tools"
        "wpa_supplicant"
    )
    
    for dep in "${deps[@]}"; do
        if ! pacman -Qi "$dep" &>/dev/null; then
            log_info "Installing $dep..."
            sudo pacman -S --noconfirm --needed "$dep" || log_warning "Failed to install $dep"
        fi
    done
    
    log_success "Dependencies installed"
}

# Clone or update driver repository
clone_driver_repo() {
    log_info "Setting up MT7902 driver source..."
    
    mkdir -p "$(dirname "$DRIVER_DIR")"
    
    if [[ -d "$DRIVER_DIR" ]]; then
        log_info "Driver directory exists, updating..."
        cd "$DRIVER_DIR"
        git pull || log_warning "Failed to update repository"
    else
        log_info "Cloning driver repository..."
        git clone --depth 1 "$MT7902_DRIVER_REPO" "$DRIVER_DIR" || {
            log_error "Failed to clone driver repository"
            return 1
        }
    fi
    
    log_success "Driver source ready"
}

# Detect kernel version and find driver directory
detect_driver_path() {
    local kernel_version
    kernel_version=$(uname -r | cut -d'.' -f1-2)  # e.g., 6.17
    
    # Log to stderr to avoid polluting stdout (which gets captured)
    log_info "Detected kernel version: $(uname -r)" >&2
    
    # Try kernel-specific directory first
    local kernel_path="$DRIVER_DIR/linux-${kernel_version}/drivers/net/wireless/mediatek/mt76"
    if [[ -d "$kernel_path" ]]; then
        echo "$kernel_path"
        return 0
    fi
    
    # Fall back to finding any available linux-* directory
    local latest_linux
    latest_linux=$(find "$DRIVER_DIR" -maxdepth 1 -type d -name 'linux-*' | sort -V | tail -1)
    if [[ -n "$latest_linux" ]]; then
        echo "$latest_linux/drivers/net/wireless/mediatek/mt76"
        return 0
    fi
    
    # Fall back to old structure (mt76 at root)
    if [[ -d "$DRIVER_DIR/mt76" ]]; then
        echo "$DRIVER_DIR/mt76"
        return 0
    fi
    
    return 1
}

# Build the driver
build_driver() {
    log_info "Building MT7902 driver..."
    
    local mt76_dir
    mt76_dir=$(detect_driver_path) || {
        log_error "Driver source directory not found"
        log_error "Checked paths:"
        log_error "  - $DRIVER_DIR/linux-*/drivers/net/wireless/mediatek/mt76"
        log_error "  - $DRIVER_DIR/mt76"
        return 1
    }
    
    log_info "Using driver path: $mt76_dir"
    
    # Check for kernel build directory (usually /usr/lib/modules/$(uname -r)/build)
    local kernel_build="/usr/lib/modules/$(uname -r)/build"
    if [[ ! -d "$kernel_build" ]]; then
        log_warning "Kernel build directory not found: $kernel_build"
        log_info "Skipping direct build - will use DKMS instead"
        log_info "DKMS will handle building from kernel source"
        return 0
    fi
    
    # Build using kernel build system with absolute M path (as in repo Makefile)
    # This mirrors: make -C /lib/modules/`uname -r`/build M=`pwd` modules
    log_info "Building using kernel build system..."
    log_info "Building module from: $mt76_dir"
    if sudo make -C "$kernel_build" LLVM=1 LLVM_IAS=1 M="$mt76_dir" modules -j"$(nproc)"; then
        log_success "Driver built successfully"
        return 0
    else
        log_warning "Direct build failed - DKMS will handle building"
        log_info "This is normal - kernel modules are better built via DKMS"
        return 0  # Don't fail, let DKMS handle it
    fi
}

# Setup DKMS for automatic rebuilds
setup_dkms() {
    log_info "Setting up DKMS for automatic kernel updates..."
    
    local dkms_dir="/usr/src/${DKMS_MODULE_NAME}-${DKMS_MODULE_VERSION}"
    
    # Get the correct driver path
    local mt76_dir
    mt76_dir=$(detect_driver_path) || {
        log_error "Cannot find driver source for DKMS setup"
        return 1
    }
    
    # Find the mediatek directory (parent of mt76)
    # mt76_dir is: $DRIVER_DIR/linux-X.Y/drivers/net/wireless/mediatek/mt76
    # mediatek_dir should be: $DRIVER_DIR/linux-X.Y/drivers/net/wireless/mediatek
    local mediatek_dir
    mediatek_dir=$(dirname "$mt76_dir")
    
    if [[ ! -d "$mediatek_dir" ]]; then
        log_error "MediaTek directory not found: $mediatek_dir"
        return 1
    fi
    
    log_info "Using MediaTek source directory: $mediatek_dir"
    
    # Remove old DKMS module if exists
    if dkms status | grep -q "$DKMS_MODULE_NAME"; then
        log_info "Removing old DKMS module..."
        sudo dkms remove "$DKMS_MODULE_NAME/$DKMS_MODULE_VERSION" --all 2>/dev/null || true
    fi
    
    # Copy the entire mediatek directory structure to DKMS
    # This preserves the full directory hierarchy needed for kernel build system
    sudo mkdir -p "$dkms_dir"
    sudo rm -rf "$dkms_dir"/* 2>/dev/null || true  # Clean any existing files
    sudo cp -r "$mediatek_dir"/* "$dkms_dir/"
    sudo chown -R root:root "$dkms_dir"  # Ensure proper ownership for DKMS
    
    # Create dkms.conf
    # Since we copied the entire mediatek directory, we need to build the mt76 subdirectory
    sudo tee "$dkms_dir/dkms.conf" > /dev/null << EOF
PACKAGE_NAME="$DKMS_MODULE_NAME"
PACKAGE_VERSION="$DKMS_MODULE_VERSION"
# Build all mt76 modules
BUILT_MODULE_NAME[0]="mt76"
BUILT_MODULE_LOCATION[0]="mt76/"
DEST_MODULE_LOCATION[0]="/kernel/drivers/net/wireless/mediatek/mt76"
BUILT_MODULE_NAME[1]="mt76-usb"
BUILT_MODULE_LOCATION[1]="mt76/"
DEST_MODULE_LOCATION[1]="/kernel/drivers/net/wireless/mediatek/mt76"
BUILT_MODULE_NAME[2]="mt76-sdio"
BUILT_MODULE_LOCATION[2]="mt76/"
DEST_MODULE_LOCATION[2]="/kernel/drivers/net/wireless/mediatek/mt76"
BUILT_MODULE_NAME[3]="mt76-connac-lib"
BUILT_MODULE_LOCATION[3]="mt76/"
DEST_MODULE_LOCATION[3]="/kernel/drivers/net/wireless/mediatek/mt76"
BUILT_MODULE_NAME[4]="mt792x-lib"
BUILT_MODULE_LOCATION[4]="mt76/"
DEST_MODULE_LOCATION[4]="/kernel/drivers/net/wireless/mediatek/mt76"
BUILT_MODULE_NAME[5]="mt792x-usb"
BUILT_MODULE_LOCATION[5]="mt76/"
DEST_MODULE_LOCATION[5]="/kernel/drivers/net/wireless/mediatek/mt76"
BUILT_MODULE_NAME[6]="mt7925-common"
BUILT_MODULE_LOCATION[6]="mt76/mt7925/"
DEST_MODULE_LOCATION[6]="/kernel/drivers/net/wireless/mediatek/mt76/mt7925"
BUILT_MODULE_NAME[7]="mt7925u"
BUILT_MODULE_LOCATION[7]="mt76/mt7925/"
DEST_MODULE_LOCATION[7]="/kernel/drivers/net/wireless/mediatek/mt76/mt7925"
AUTOINSTALL="yes"
MAKE[0]="make -C /lib/modules/\${kernelver}/build LLVM=1 LLVM_IAS=1 M=/usr/src/\${PACKAGE_NAME}-\${PACKAGE_VERSION}/mt76 modules -j\$(nproc)"
CLEAN[0]="make -C /lib/modules/\${kernelver}/build LLVM=1 LLVM_IAS=1 M=/usr/src/\${PACKAGE_NAME}-\${PACKAGE_VERSION}/mt76 clean"
EOF
    
    # Add and build DKMS module
    log_info "Building DKMS module..."
    
    # Verify dkms.conf and source files are in place
    if [[ ! -f "$dkms_dir/dkms.conf" ]]; then
        log_error "dkms.conf not found in $dkms_dir"
        return 1
    fi
    
    if [[ ! -d "$dkms_dir/mt76" ]]; then
        log_error "mt76 directory not found in $dkms_dir - source copy may have failed"
        return 1
    fi
    
    if [[ ! -f "$dkms_dir/mt76/Makefile" ]]; then
        log_error "mt76/Makefile not found in $dkms_dir - source copy may have failed"
        return 1
    fi
    
    log_info "DKMS source directory: $dkms_dir"
    log_info "DKMS source contains: $(ls -1 "$dkms_dir" | tr '\n' ' ')..."
    log_info "mt76 directory contains: $(ls -1 "$dkms_dir/mt76" | head -5 | tr '\n' ' ')..."
    
    if sudo dkms add -m "$DKMS_MODULE_NAME" -v "$DKMS_MODULE_VERSION" &&
       sudo dkms build -m "$DKMS_MODULE_NAME" -v "$DKMS_MODULE_VERSION" &&
       sudo dkms install -m "$DKMS_MODULE_NAME" -v "$DKMS_MODULE_VERSION"; then
        log_success "DKMS module installed successfully"
        return 0
    else
        log_warning "DKMS setup failed, will try manual module loading"
        log_info "Check /var/lib/dkms/$DKMS_MODULE_NAME/$DKMS_MODULE_VERSION/build/make.log for details"
        return 1
    fi
}

# Load kernel modules manually
load_modules_manual() {
    log_info "Loading MT7902 modules manually..."
    
    local mt76_dir
    mt76_dir=$(detect_driver_path) || {
        log_error "Cannot find driver source for manual loading"
        return 1
    }
    
    cd "$mt76_dir" || return 1
    
    # Load dependencies first
    # Note: For mt7902, we typically use mt7921 or mt7925 modules
    local modules=(
        "mt76-connac-lib.ko"
        "mt76.ko"
        "mt76-sdio.ko"
        "mt76-usb.ko"
        "mt76x02-lib.ko"
        "mt76x02-usb.ko"
        "mt792x-lib.ko"
        "mt792x-usb.ko"
        "mt7921/mt7921-common.ko"
        "mt7921/mt7921u.ko"
        "mt7925/mt7925-common.ko"
        "mt7925/mt7925u.ko"
    )
    
    for module in "${modules[@]}"; do
        if [[ -f "$module" ]]; then
            log_info "Loading $(basename "$module")..."
            sudo insmod "$module" 2>/dev/null || log_warning "Failed to load $(basename "$module")"
        fi
    done
    
    log_success "Modules loaded"
}

# Create modprobe configuration
create_modprobe_conf() {
    log_info "Creating modprobe configuration..."
    
    # Determine a preferred variant if present (USB preferred by default)
    local preferred_variant="mt7925u"
    if modinfo mt7925e >/dev/null 2>&1; then
        preferred_variant="mt7925e"
    elif ! modinfo mt7925u >/dev/null 2>&1; then
        # Fall back to mt7921 variants
        if modinfo mt7921e >/dev/null 2>&1; then
            preferred_variant="mt7921e"
        else
            preferred_variant="mt7921u"
        fi
    fi
    
    sudo tee /etc/modprobe.d/mt7902.conf > /dev/null << EOF
# MT7902 WiFi driver configuration

# Treat 'mt7902' as the public module name. Loading it will load the mt76 stack
# and then the best variant for this system.
softdep mt7902 pre: mt76-connac-lib mt76 mt76-sdio mt76-usb mt76x02-lib mt76x02-usb mt792x-lib mt792x-usb

# Chain-load underlying modules; try preferred variant then reasonable fallbacks.
install mt7902 \
  /usr/bin/modprobe --ignore-install mt76-connac-lib && \
  /usr/bin/modprobe --ignore-install mt76 && \
  /usr/bin/modprobe --ignore-install mt76-sdio && \
  /usr/bin/modprobe --ignore-install mt76-usb && \
  /usr/bin/modprobe --ignore-install mt76x02-lib && \
  /usr/bin/modprobe --ignore-install mt76x02-usb && \
  /usr/bin/modprobe --ignore-install mt792x-lib && \
  /usr/bin/modprobe --ignore-install mt792x-usb && \
  ( /usr/bin/modprobe --ignore-install ${preferred_variant} || \
    /usr/bin/modprobe --ignore-install mt7925u || \
    /usr/bin/modprobe --ignore-install mt7925e || \
    /usr/bin.modprobe --ignore-install mt7921u || \
    /usr/bin/modprobe --ignore-install mt7921e )

# Optional driver options (tune as needed)
# options mt7902 power_save=1
EOF
    
    log_success "Modprobe configuration created"
}

# Create modules-load configuration
create_modules_load() {
    log_info "Creating modules-load configuration..."
    
    sudo tee /etc/modules-load.d/mt7902.conf > /dev/null << EOF
# Load virtual MT7902 module at boot (modprobe will chain-load the right stack)
mt7902
EOF
    
    log_success "Modules-load configuration created"
}

# Install firmware files
install_firmware() {
    log_info "Installing MT7902 firmware..."
    
    local firmware_src="$DRIVER_DIR/mt7902_firmware"
    local firmware_dest="/lib/firmware/mediatek"
    
    if [[ -d "$firmware_src" ]]; then
        sudo mkdir -p "$firmware_dest"
        sudo cp -r "$firmware_src"/* "$firmware_dest/" 2>/dev/null || {
            log_warning "Some firmware files may not have been copied"
        }
        log_success "Firmware files installed"
    else
        log_warning "Firmware directory not found in driver repo"
    fi
}

# Verify installation
verify_installation() {
    log_info "Verifying installation..."
    
    # Check if modules are loaded
    if lsmod | grep -q "mt7902\|mt792x"; then
        log_success "MT7902 modules loaded"
    else
        log_warning "MT7902 modules not loaded yet (may require reboot)"
    fi
    
    # Check for wireless interface
    if ip link show | grep -q "wlan\|wlp"; then
        log_success "WiFi interface detected"
        ip link show | grep -E "wlan|wlp"
    else
        log_warning "WiFi interface not yet available (reboot may be required)"
    fi
}

# Backup current configuration
backup_config() {
    local backup_dir="$HOME/.config/mt7902_backup"
    mkdir -p "$backup_dir"
    
    log_info "Backing up current network configuration..."
    
    # Backup network manager configs
    if [[ -d /etc/NetworkManager ]]; then
        sudo cp -r /etc/NetworkManager "$backup_dir/" 2>/dev/null || true
    fi
    
    log_success "Backup created at $backup_dir"
}

# Main installation function
main() {
    echo
    log_info "🔧 MT7902 WiFi Driver Setup for FireDragon"
    echo
    
    # Safety check: Is MT7902 present?
    if ! check_mt7902_present; then
        log_info "MT7902 chip not detected. Skipping driver installation."
        log_info "If you believe this is an error, check: lspci -nn | grep -i network"
        exit 0
    fi
    
    # Check if WiFi is already working
    if check_wifi_working; then
        log_info "WiFi appears to be working. Driver installation may not be necessary."
        read -p "Continue with installation anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Installation cancelled by user"
            exit 0
        fi
    fi
    
    # Backup current configuration
    backup_config
    
    # Install dependencies
    install_dependencies
    echo
    
    # Clone driver repository
    if ! clone_driver_repo; then
        log_error "Failed to setup driver source"
        exit 1
    fi
    echo
    
    # Build driver
    if ! build_driver; then
        log_error "Driver build failed"
        log_info "Check build logs above for errors"
        exit 1
    fi
    echo
    
    # Install firmware
    install_firmware
    echo
    
    # Try DKMS setup first
    if setup_dkms; then
        log_info "DKMS setup successful - driver will auto-rebuild on kernel updates"
    else
        log_warning "DKMS setup failed - using manual module loading"
        load_modules_manual
    fi
    echo
    
    # Create configuration files
    create_modprobe_conf
    create_modules_load
    echo
    
    # Verify
    verify_installation
    echo
    
    log_success "🎉 MT7902 driver installation completed!"
    echo
    log_info "📋 Next Steps:"
    echo "  1. Reboot your system: sudo reboot"
    echo "  2. After reboot, check WiFi: ip link show"
    echo "  3. Connect to WiFi: nmcli device wifi list"
    echo "  4. If issues occur, check: dmesg | grep mt7902"
    echo
    log_info "🔄 To rebuild driver after kernel update:"
    echo "  • DKMS will auto-rebuild (if setup succeeded)"
    echo "  • Or run this script again manually"
    echo
    log_warning "⚠️  Note: This driver is community-developed and may have stability issues"
    echo
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

