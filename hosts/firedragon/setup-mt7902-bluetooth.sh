#!/bin/bash
# MT7902 Bluetooth Setup for FireDragon (Asus VivoBook)
# Handles MediaTek MT7902 Bluetooth module compilation and installation

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
KERNEL_VERSION=$(uname -r)
KERNEL_SOURCE_DIR="/usr/lib/modules/$KERNEL_VERSION/build"
BLUETOOTH_BUILD_DIR="$HOME/.local/src/mt7902_bluetooth"
BACKUP_DIR="$HOME/.config/mt7902_bluetooth_backup"
DKMS_MODULE_NAME="mt7902-bluetooth"
DKMS_MODULE_VERSION="1.0"

# Check if MT7902 chip is present
check_mt7902_present() {
    log_info "Checking for MT7902 Bluetooth chip..."
    
    # Check for MT7902 via lsusb or lspci
    if lsusb | grep -qi "0e8d:7902\|MediaTek.*MT7902" || \
       lspci -nn | grep -qi "14c3:7902\|14c3:0608"; then
        log_success "MT7902 chip detected"
        return 0
    else
        log_info "MT7902 chip not detected"
        return 1
    fi
}

# Check if Bluetooth is already working
check_bluetooth_working() {
    log_info "Checking if Bluetooth is already functional..."
    
    # Check if bluetooth service exists and is running
    if systemctl is-active --quiet bluetooth 2>/dev/null; then
        log_success "Bluetooth service is running"
        
        # Check if hci0 device exists
        if hciconfig hci0 2>/dev/null | grep -q "UP RUNNING"; then
            log_success "Bluetooth adapter is active"
            return 0
        fi
        
        if bluetoothctl list 2>/dev/null | grep -q "Controller"; then
            log_success "Bluetooth controller detected"
            return 0
        fi
    fi
    
    log_warning "Bluetooth not functional, driver installation needed"
    return 1
}

# Install build dependencies
install_dependencies() {
    log_info "Installing Bluetooth build dependencies..."
    
    local deps=(
        "base-devel"
        "linux-headers"
        "dkms"
        "bluez"
        "bluez-utils"
        "bc"
        "pahole"
    )
    
    for dep in "${deps[@]}"; do
        if ! pacman -Qi "$dep" &>/dev/null; then
            log_info "Installing $dep..."
            sudo pacman -S --noconfirm --needed "$dep" || log_warning "Failed to install $dep"
        fi
    done
    
    log_success "Dependencies installed"
}

# Check for kernel source
check_kernel_source() {
    log_info "Checking for kernel source..."
    
    if [[ ! -d "$KERNEL_SOURCE_DIR" ]]; then
        log_error "Kernel source not found at: $KERNEL_SOURCE_DIR"
        log_info "Install kernel headers: sudo pacman -S linux-headers"
        return 1
    fi
    
    if [[ ! -d "$KERNEL_SOURCE_DIR/drivers/bluetooth" ]]; then
        log_error "Bluetooth drivers directory not found in kernel source"
        return 1
    fi
    
    log_success "Kernel source found: $KERNEL_SOURCE_DIR"
    return 0
}

# Build Bluetooth modules
build_bluetooth_modules() {
    log_info "Building MT7902 Bluetooth modules..."
    
    # Create build directory
    mkdir -p "$BLUETOOTH_BUILD_DIR"
    cd "$BLUETOOTH_BUILD_DIR"
    
    # Copy bluetooth driver source from kernel
    log_info "Copying Bluetooth driver source..."
    cp -r "$KERNEL_SOURCE_DIR/drivers/bluetooth" "$BLUETOOTH_BUILD_DIR/" 2>/dev/null || {
        log_error "Failed to copy Bluetooth drivers"
        return 1
    }
    
    cd "$BLUETOOTH_BUILD_DIR/bluetooth"
    
    # Create Makefile if it doesn't exist
    if [[ ! -f "Makefile" ]]; then
        log_info "Creating Makefile..."
        cat > Makefile << 'EOF'
# Bluetooth driver Makefile for out-of-tree build
obj-m += btusb.o btmtk.o

KDIR := /lib/modules/$(shell uname -r)/build
PWD := $(shell pwd)

all:
	$(MAKE) -C $(KDIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean

install:
	$(MAKE) -C $(KDIR) M=$(PWD) modules_install
EOF
    fi
    
    # Clean previous builds
    make clean 2>/dev/null || true
    
    # Build modules
    log_info "Compiling Bluetooth modules (this may take a moment)..."
    if make -j$(nproc) 2>&1 | tee "$BLUETOOTH_BUILD_DIR/build.log"; then
        log_success "Bluetooth modules built successfully"
        
        # Verify modules were created
        if [[ -f "btusb.ko" ]] && [[ -f "btmtk.ko" ]]; then
            log_success "Found btusb.ko and btmtk.ko"
            return 0
        else
            log_error "Modules not found after build"
            return 1
        fi
    else
        log_error "Build failed. Check: $BLUETOOTH_BUILD_DIR/build.log"
        return 1
    fi
}

# Backup existing modules
backup_existing_modules() {
    log_info "Backing up existing Bluetooth modules..."
    
    mkdir -p "$BACKUP_DIR"
    
    # Find existing btusb and btmtk modules
    local btusb_path=$(modinfo -n btusb 2>/dev/null || true)
    local btmtk_path=$(modinfo -n btmtk 2>/dev/null || true)
    
    if [[ -n "$btusb_path" ]] && [[ -f "$btusb_path" ]]; then
        log_info "Backing up btusb from: $btusb_path"
        sudo cp "$btusb_path" "$BACKUP_DIR/btusb.ko.backup" || true
    fi
    
    if [[ -n "$btmtk_path" ]] && [[ -f "$btmtk_path" ]]; then
        log_info "Backing up btmtk from: $btmtk_path"
        sudo cp "$btmtk_path" "$BACKUP_DIR/btmtk.ko.backup" || true
    fi
    
    log_success "Backup completed at: $BACKUP_DIR"
}

# Install Bluetooth modules
install_bluetooth_modules() {
    log_info "Installing MT7902 Bluetooth modules..."
    
    cd "$BLUETOOTH_BUILD_DIR/bluetooth"
    
    # Unload existing modules
    log_info "Unloading existing Bluetooth modules..."
    sudo modprobe -r btusb 2>/dev/null || true
    sudo modprobe -r btmtk 2>/dev/null || true
    
    # Install new modules to updates directory
    local updates_dir="/lib/modules/$KERNEL_VERSION/updates"
    sudo mkdir -p "$updates_dir"
    
    log_info "Installing modules to: $updates_dir"
    sudo cp btmtk.ko "$updates_dir/" || {
        log_error "Failed to copy btmtk.ko"
        return 1
    }
    sudo cp btusb.ko "$updates_dir/" || {
        log_error "Failed to copy btusb.ko"
        return 1
    }
    
    # Update module dependencies
    log_info "Updating module dependencies..."
    sudo depmod -a
    
    log_success "Modules installed"
}

# Setup DKMS for automatic rebuilds
setup_dkms() {
    log_info "Setting up DKMS for automatic kernel updates..."
    
    local dkms_dir="/usr/src/${DKMS_MODULE_NAME}-${DKMS_MODULE_VERSION}"
    
    # Remove old DKMS module if exists
    if dkms status | grep -q "$DKMS_MODULE_NAME"; then
        log_info "Removing old DKMS module..."
        sudo dkms remove "$DKMS_MODULE_NAME/$DKMS_MODULE_VERSION" --all 2>/dev/null || true
    fi
    
    # Create DKMS source directory
    sudo mkdir -p "$dkms_dir"
    
    # Copy Bluetooth driver source to DKMS directory
    log_info "Copying Bluetooth drivers to DKMS directory..."
    sudo cp -r "$BLUETOOTH_BUILD_DIR/bluetooth"/* "$dkms_dir/" || {
        log_warning "Failed to copy source to DKMS directory"
        return 1
    }
    
    # Create dkms.conf
    sudo tee "$dkms_dir/dkms.conf" > /dev/null << EOF
PACKAGE_NAME="$DKMS_MODULE_NAME"
PACKAGE_VERSION="$DKMS_MODULE_VERSION"

# Build both btmtk and btusb
BUILT_MODULE_NAME[0]="btmtk"
BUILT_MODULE_LOCATION[0]="."
DEST_MODULE_LOCATION[0]="/updates"

BUILT_MODULE_NAME[1]="btusb"
BUILT_MODULE_LOCATION[1]="."
DEST_MODULE_LOCATION[1]="/updates"

AUTOINSTALL="yes"

# Use existing Makefile
MAKE[0]="make -j\$(nproc)"
CLEAN="make clean"
EOF
    
    # Add and build DKMS module
    log_info "Building DKMS module..."
    if sudo dkms add -m "$DKMS_MODULE_NAME" -v "$DKMS_MODULE_VERSION" 2>&1 | grep -v "already added"; then
        if sudo dkms build -m "$DKMS_MODULE_NAME" -v "$DKMS_MODULE_VERSION" &&
           sudo dkms install -m "$DKMS_MODULE_NAME" -v "$DKMS_MODULE_VERSION"; then
            log_success "DKMS module installed successfully"
            log_success "Bluetooth drivers will auto-rebuild on kernel updates!"
            return 0
        else
            log_warning "DKMS build/install failed, will use manual installation"
            return 1
        fi
    else
        log_warning "DKMS setup failed, will use manual installation"
        return 1
    fi
}

# Install Bluetooth modules manually (fallback)
install_bluetooth_modules_manual() {
    log_info "Installing MT7902 Bluetooth modules manually..."
    
    cd "$BLUETOOTH_BUILD_DIR/bluetooth"
    
    # Unload existing modules
    log_info "Unloading existing Bluetooth modules..."
    sudo modprobe -r btusb 2>/dev/null || true
    sudo modprobe -r btmtk 2>/dev/null || true
    
    # Install new modules to updates directory
    local updates_dir="/lib/modules/$KERNEL_VERSION/updates"
    sudo mkdir -p "$updates_dir"
    
    log_info "Installing modules to: $updates_dir"
    sudo cp btmtk.ko "$updates_dir/" || {
        log_error "Failed to copy btmtk.ko"
        return 1
    }
    sudo cp btusb.ko "$updates_dir/" || {
        log_error "Failed to copy btusb.ko"
        return 1
    }
    
    # Update module dependencies
    log_info "Updating module dependencies..."
    sudo depmod -a
    
    log_success "Modules installed manually"
}

# Load Bluetooth modules
load_bluetooth_modules() {
    log_info "Loading MT7902 Bluetooth modules..."
    
    # Load modules in correct order
    if sudo modprobe btmtk && sudo modprobe btusb; then
        log_success "Bluetooth modules loaded"
        return 0
    else
        log_error "Failed to load Bluetooth modules"
        return 1
    fi
}

# Configure module loading at boot
configure_autoload() {
    log_info "Configuring Bluetooth modules to load at boot..."
    
    sudo tee /etc/modules-load.d/mt7902-bluetooth.conf > /dev/null << 'EOF'
# MT7902 Bluetooth modules
btmtk
btusb
EOF
    
    log_success "Autoload configuration created"
}

# Enable Bluetooth service
enable_bluetooth_service() {
    log_info "Enabling Bluetooth service..."
    
    sudo systemctl enable bluetooth.service
    sudo systemctl start bluetooth.service
    
    if systemctl is-active --quiet bluetooth; then
        log_success "Bluetooth service is running"
    else
        log_warning "Bluetooth service failed to start"
    fi
}

# Verify installation
verify_installation() {
    log_info "Verifying Bluetooth installation..."
    
    echo
    
    # Check if modules are loaded
    if lsmod | grep -q "btmtk"; then
        log_success "✓ btmtk module loaded"
    else
        log_warning "✗ btmtk module not loaded"
    fi
    
    if lsmod | grep -q "btusb"; then
        log_success "✓ btusb module loaded"
    else
        log_warning "✗ btusb module not loaded"
    fi
    
    # Check Bluetooth service
    if systemctl is-active --quiet bluetooth; then
        log_success "✓ Bluetooth service running"
    else
        log_warning "✗ Bluetooth service not running"
    fi
    
    # Check for Bluetooth adapter
    if hciconfig 2>/dev/null | grep -q "hci0"; then
        log_success "✓ Bluetooth adapter detected"
        hciconfig hci0
    else
        log_warning "✗ Bluetooth adapter not detected (may require reboot)"
    fi
    
    echo
}

# Provide usage instructions
show_usage_instructions() {
    log_info "📋 Bluetooth Usage Instructions:"
    echo
    echo "  Test Bluetooth:"
    echo "    bluetoothctl list                 # List controllers"
    echo "    bluetoothctl scan on              # Scan for devices"
    echo "    bluetoothctl devices              # List found devices"
    echo
    echo "  Connect to a device:"
    echo "    bluetoothctl pair <MAC_ADDRESS>"
    echo "    bluetoothctl connect <MAC_ADDRESS>"
    echo
    echo "  Check status:"
    echo "    hciconfig                         # Show adapter info"
    echo "    systemctl status bluetooth        # Service status"
    echo "    lsmod | grep bt                   # Check loaded modules"
    echo
}

# Rollback function
rollback() {
    log_warning "Rolling back Bluetooth installation..."
    
    # Remove DKMS module if it exists
    if dkms status | grep -q "$DKMS_MODULE_NAME"; then
        log_info "Removing DKMS module..."
        sudo dkms remove "$DKMS_MODULE_NAME/$DKMS_MODULE_VERSION" --all 2>/dev/null || true
        sudo rm -rf "/usr/src/${DKMS_MODULE_NAME}-${DKMS_MODULE_VERSION}"
    fi
    
    # Unload custom modules
    sudo modprobe -r btusb 2>/dev/null || true
    sudo modprobe -r btmtk 2>/dev/null || true
    
    # Remove custom modules
    sudo rm -f "/lib/modules/$KERNEL_VERSION/updates/btusb.ko"
    sudo rm -f "/lib/modules/$KERNEL_VERSION/updates/btmtk.ko"
    
    # Restore backups if they exist
    if [[ -f "$BACKUP_DIR/btusb.ko.backup" ]]; then
        local original_path=$(modinfo -n btusb 2>/dev/null || echo "/lib/modules/$KERNEL_VERSION/kernel/drivers/bluetooth/btusb.ko")
        sudo cp "$BACKUP_DIR/btusb.ko.backup" "$original_path" || true
    fi
    
    if [[ -f "$BACKUP_DIR/btmtk.ko.backup" ]]; then
        local original_path=$(modinfo -n btmtk 2>/dev/null || echo "/lib/modules/$KERNEL_VERSION/kernel/drivers/bluetooth/btmtk.ko")
        sudo cp "$BACKUP_DIR/btmtk.ko.backup" "$original_path" || true
    fi
    
    # Update dependencies
    sudo depmod -a
    
    # Remove autoload config
    sudo rm -f /etc/modules-load.d/mt7902-bluetooth.conf
    
    # Reload system modules
    sudo modprobe btmtk
    sudo modprobe btusb
    
    log_info "Rollback complete. Reboot may be required."
}

# Main installation function
main() {
    echo
    log_info "🔧 MT7902 Bluetooth Setup for FireDragon"
    echo
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        log_error "Do not run this script as root. It will use sudo when needed."
        exit 1
    fi
    
    # Safety check: Is MT7902 present?
    if ! check_mt7902_present; then
        log_info "MT7902 chip not detected. Bluetooth setup may not be necessary."
        log_info "If you believe this is an error, check: lsusb | grep -i mediatek"
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
    
    # Check if Bluetooth is already working
    if check_bluetooth_working; then
        log_info "Bluetooth appears to be working."
        read -p "Continue with installation anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Installation cancelled by user"
            exit 0
        fi
    fi
    
    # Install dependencies
    install_dependencies
    echo
    
    # Check kernel source
    if ! check_kernel_source; then
        log_error "Kernel source required but not found"
        exit 1
    fi
    echo
    
    # Backup existing modules
    backup_existing_modules
    echo
    
    # Build modules
    if ! build_bluetooth_modules; then
        log_error "Failed to build Bluetooth modules"
        log_info "Check build log: $BLUETOOTH_BUILD_DIR/build.log"
        exit 1
    fi
    echo
    
    # Install modules
    if ! install_bluetooth_modules; then
        log_error "Failed to install Bluetooth modules"
        exit 1
    fi
    echo
    
    # Try DKMS setup first
    if setup_dkms; then
        log_info "DKMS setup successful - drivers will auto-rebuild on kernel updates"
    else
        log_warning "DKMS setup failed - using manual installation"
        log_warning "You'll need to re-run this script after kernel updates"
        if ! install_bluetooth_modules_manual; then
            log_error "Manual installation also failed"
            exit 1
        fi
    fi
    echo
    
    # Load modules
    if ! load_bluetooth_modules; then
        log_warning "Failed to load modules automatically"
        log_info "This may be normal - try rebooting"
    fi
    echo
    
    # Configure autoload
    configure_autoload
    echo
    
    # Enable service
    enable_bluetooth_service
    echo
    
    # Verify
    verify_installation
    
    # Show usage
    show_usage_instructions
    
    log_success "🎉 MT7902 Bluetooth setup completed!"
    echo
    log_warning "⚠️  Important:"
    echo "  1. Reboot your system for changes to take full effect"
    echo "  2. After reboot, check: hciconfig"
    echo "  3. Test with: bluetoothctl list"
    echo
    if dkms status | grep -q "$DKMS_MODULE_NAME"; then
        log_success "🔄 DKMS is configured - drivers will auto-rebuild on kernel updates"
    else
        log_warning "⚠️  DKMS not active - recompile after kernel updates:"
        echo "     bash $0"
    fi
    echo
    log_info "🔄 To rollback if issues occur:"
    echo "  bash $0 --rollback"
    echo
}

# Handle command line arguments
if [[ "$1" == "--rollback" ]]; then
    rollback
    exit 0
elif [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    echo "MT7902 Bluetooth Setup Script"
    echo
    echo "Usage:"
    echo "  $0              Install MT7902 Bluetooth support"
    echo "  $0 --rollback   Restore original Bluetooth modules"
    echo "  $0 --help       Show this help"
    exit 0
fi

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

