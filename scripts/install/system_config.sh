#!/usr/bin/env bash

# System Configuration Script
# Handles BTRFS optimization, hardware-specific configuration, and CachyOS optimizations

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Options
SETUP_BTRFS=true
SETUP_HARDWARE=true
SETUP_OPTIMIZATIONS=true
SETUP_SERVICES=true
FORCE=false

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Show usage information
usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

System Configuration Script

OPTIONS:
    -h, --help              Show this help message
    --btrfs-only            Only setup BTRFS optimizations
    --hardware-only         Only setup hardware configuration
    --optimizations-only    Only setup performance optimizations
    --services-only         Only setup systemd services
    --force                 Force overwrite existing configurations
    --no-btrfs              Skip BTRFS setup
    --no-hardware           Skip hardware setup
    --no-optimizations      Skip performance optimizations
    --no-services           Skip systemd services

EXAMPLES:
    $0                      # Complete system setup
    $0 --btrfs-only         # Only BTRFS optimizations
    $0 --force              # Force overwrite existing configs

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
        -h | --help)
            usage
            exit 0
            ;;
        --btrfs-only)
            SETUP_HARDWARE=false
            SETUP_OPTIMIZATIONS=false
            SETUP_SERVICES=false
            shift
            ;;
        --hardware-only)
            SETUP_BTRFS=false
            SETUP_OPTIMIZATIONS=false
            SETUP_SERVICES=false
            shift
            ;;
        --optimizations-only)
            SETUP_BTRFS=false
            SETUP_HARDWARE=false
            SETUP_SERVICES=false
            shift
            ;;
        --services-only)
            SETUP_BTRFS=false
            SETUP_HARDWARE=false
            SETUP_OPTIMIZATIONS=false
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --no-btrfs)
            SETUP_BTRFS=false
            shift
            ;;
        --no-hardware)
            SETUP_HARDWARE=false
            shift
            ;;
        --no-optimizations)
            SETUP_OPTIMIZATIONS=false
            shift
            ;;
        --no-services)
            SETUP_SERVICES=false
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
        esac
    done
}

# Check if we're running as root or with sudo
check_privileges() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script requires root privileges"
        log_info "Please run with sudo: sudo $0"
        exit 1
    fi
}

# Detect hardware type
detect_hardware() {
    local cpu_vendor=""
    local gpu_vendor=""

    # Detect CPU vendor
    if grep -q "vendor_id.*AuthenticAMD" /proc/cpuinfo; then
        cpu_vendor="amd"
    elif grep -q "vendor_id.*GenuineIntel" /proc/cpuinfo; then
        cpu_vendor="intel"
    fi

    # Detect GPU vendor
    if lspci | grep -qi "amd\|radeon"; then
        gpu_vendor="amd"
    elif lspci | grep -qi "intel.*graphics"; then
        gpu_vendor="intel"
    elif lspci | grep -qi "nvidia"; then
        gpu_vendor="nvidia"
    fi

    echo "${cpu_vendor}-${gpu_vendor}"
}

# Setup BTRFS optimizations
setup_btrfs_config() {
    if [[ "$SETUP_BTRFS" != "true" ]]; then
        return 0
    fi

    log_info "Setting up BTRFS optimizations..."

    # Check if root filesystem is BTRFS
    if ! mount | grep -q "on / type btrfs"; then
        log_warning "Root filesystem is not BTRFS, skipping BTRFS optimizations"
        return 0
    fi

    # Create BTRFS maintenance scripts
    log_info "Creating BTRFS maintenance scripts..."

    # BTRFS manager script
    cat >/usr/local/bin/btrfs-manager <<'EOF'
#!/bin/bash
# BTRFS Management Script

show_usage() {
  echo "BTRFS Manager - System Edition"
  echo "Usage: btrfs-manager [COMMAND]"
  echo ""
  echo "Commands:"
  echo "  status     - Show filesystem status and usage"
  echo "  balance    - Run filesystem balance"
  echo "  scrub      - Run filesystem scrub"
  echo "  defrag     - Defragment filesystem"
  echo "  snapshots  - List snapshots (if snapper installed)"
  echo "  cleanup    - Clean old snapshots"
  echo "  compress   - Show compression stats"
  echo "  health     - Full health check"
}

case "$1" in
  status)
    echo "=== BTRFS Filesystem Status ==="
    btrfs filesystem show
    echo ""
    echo "=== Space Usage ==="
    btrfs filesystem usage /
    ;;
  balance)
    echo "Starting BTRFS balance..."
    btrfs balance start -dusage=50 -musage=50 /
    ;;
  scrub)
    echo "Starting BTRFS scrub..."
    btrfs scrub start /
    btrfs scrub status /
    ;;
  defrag)
    echo "Starting BTRFS defragmentation..."
    btrfs filesystem defragment -r -v -czstd /
    ;;
  snapshots)
    if command -v snapper >/dev/null 2>&1; then
      echo "=== Root Snapshots ==="
      snapper -c root list 2>/dev/null || echo "No root config"
      echo ""
      echo "=== Home Snapshots ==="
      snapper -c home list 2>/dev/null || echo "No home config"
    else
      echo "Snapper not installed"
    fi
    ;;
  cleanup)
    if command -v snapper >/dev/null 2>&1; then
      echo "Cleaning up old snapshots..."
      snapper -c root cleanup number 2>/dev/null || true
      snapper -c home cleanup number 2>/dev/null || true
    else
      echo "Snapper not installed"
    fi
    ;;
  compress)
    echo "=== Compression Statistics ==="
    if command -v compsize >/dev/null 2>&1; then
      compsize /
    else
      echo "compsize not installed"
    fi
    ;;
  health)
    echo "=== BTRFS Health Check ==="
    echo "Filesystem status:"
    btrfs filesystem show
    echo ""
    echo "Space usage:"
    btrfs filesystem usage /
    echo ""
    if command -v compsize >/dev/null 2>&1; then
      echo "Compression stats:"
      compsize /
      echo ""
    fi
    ;;
  *)
    show_usage
    ;;
esac
EOF

    chmod +x /usr/local/bin/btrfs-manager

    # Create systemd services for BTRFS maintenance
    log_info "Creating BTRFS systemd services..."

    # Auto-defrag service
    cat >/etc/systemd/system/btrfs-autodefrag.service <<EOF
[Unit]
Description=BTRFS auto defragmentation
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/bin/btrfs filesystem defragment -r -v -czstd /
EOF

    cat >/etc/systemd/system/btrfs-autodefrag.timer <<EOF
[Unit]
Description=Run BTRFS defragmentation weekly
Requires=btrfs-autodefrag.service

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
EOF

    # Balance service
    cat >/etc/systemd/system/btrfs-balance.service <<EOF
[Unit]
Description=BTRFS balance for optimal space allocation
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/bin/btrfs balance start -dusage=50 -musage=50 /
EOF

    cat >/etc/systemd/system/btrfs-balance.timer <<EOF
[Unit]
Description=Run BTRFS balance monthly
Requires=btrfs-balance.service

[Timer]
OnCalendar=monthly
Persistent=true

[Install]
WantedBy=timers.target
EOF

    # Scrub service
    cat >/etc/systemd/system/btrfs-scrub.service <<EOF
[Unit]
Description=BTRFS filesystem scrub
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/bin/btrfs scrub start /
EOF

    cat >/etc/systemd/system/btrfs-scrub.timer <<EOF
[Unit]
Description=Run BTRFS scrub monthly
Requires=btrfs-scrub.service

[Timer]
OnCalendar=monthly
Persistent=true

[Install]
WantedBy=timers.target
EOF

    # Enable timers
    systemctl daemon-reload
    systemctl enable btrfs-autodefrag.timer
    systemctl enable btrfs-balance.timer
    systemctl enable btrfs-scrub.timer

    log_success "BTRFS optimizations configured"
}

# Setup hardware-specific configuration
setup_hardware_config() {
    if [[ "$SETUP_HARDWARE" != "true" ]]; then
        return 0
    fi

    log_info "Setting up hardware-specific configuration..."

    local hardware_type
    hardware_type=$(detect_hardware)

    log_info "Detected hardware: $hardware_type"

    case "$hardware_type" in
    amd-amd)
        setup_amd_configuration
        ;;
    intel-intel)
        setup_intel_configuration
        ;;
    amd-nvidia)
        setup_amd_nvidia_configuration
        ;;
    intel-nvidia)
        setup_intel_nvidia_configuration
        ;;
    *)
        log_warning "Unknown hardware configuration: $hardware_type"
        ;;
    esac
}

# Setup AMD CPU + NVIDIA GPU configuration
setup_amd_nvidia_configuration() {
    log_info "Setting up AMD CPU + NVIDIA GPU configuration..."

    # AMD CPU parameters + NVIDIA GPU parameters
    local kernel_params="amd_pstate=active nvidia-drm.modeset=1 nvidia.NVreg_PreserveVideoMemoryAllocations=1"

    # Add to systemd-boot configuration
    if [[ -d "/boot/loader/entries" ]]; then
        log_info "Adding AMD CPU + NVIDIA GPU kernel parameters to systemd-boot..."

        local boot_entry=$(find /boot/loader/entries -name "*.conf" | head -1)
        if [[ -n "$boot_entry" ]]; then
            if ! grep -q "amd_pstate=active" "$boot_entry"; then
                cp "$boot_entry" "${boot_entry}.backup.$(date +%Y%m%d_%H%M%S)"
                sed -i "/^options/ s/$/ $kernel_params/" "$boot_entry"
                log_info "Updated boot entry: $boot_entry"
            else
                log_info "AMD+NVIDIA parameters already present in boot entry"
            fi
        fi
    else
        echo "$kernel_params" >/etc/kernel/cmdline
    fi

    # Load modules
    mkdir -p /etc/modules-load.d
    echo "nvidia" >>/etc/modules-load.d/nvidia.conf
    echo "nvidia_modeset" >>/etc/modules-load.d/nvidia.conf
    echo "nvidia_uvm" >>/etc/modules-load.d/nvidia.conf
    echo "nvidia_drm" >>/etc/modules-load.d/nvidia.conf

    log_success "AMD CPU + NVIDIA GPU configuration applied"
}

# Setup Intel CPU + NVIDIA GPU configuration
setup_intel_nvidia_configuration() {
    log_info "Setting up Intel CPU + NVIDIA GPU configuration..."

    # Intel CPU parameters + NVIDIA GPU parameters
    local kernel_params="intel_pstate=active i915.modeset=1 nvidia-drm.modeset=1 nvidia.NVreg_PreserveVideoMemoryAllocations=1"

    # Add to systemd-boot configuration
    if [[ -d "/boot/loader/entries" ]]; then
        log_info "Adding Intel CPU + NVIDIA GPU kernel parameters to systemd-boot..."

        local boot_entry=$(find /boot/loader/entries -name "*.conf" | head -1)
        if [[ -n "$boot_entry" ]]; then
            if ! grep -q "intel_pstate=active" "$boot_entry"; then
                cp "$boot_entry" "${boot_entry}.backup.$(date +%Y%m%d_%H%M%S)"
                sed -i "/^options/ s/$/ $kernel_params/" "$boot_entry"
                log_info "Updated boot entry: $boot_entry"
            else
                log_info "Intel+NVIDIA parameters already present in boot entry"
            fi
        fi
    else
        echo "$kernel_params" >/etc/kernel/cmdline
    fi

    # Load modules
    mkdir -p /etc/modules-load.d
    echo "i915" >>/etc/modules-load.d/intel.conf
    echo "nvidia" >>/etc/modules-load.d/nvidia.conf
    echo "nvidia_modeset" >>/etc/modules-load.d/nvidia.conf
    echo "nvidia_uvm" >>/etc/modules-load.d/nvidia.conf
    echo "nvidia_drm" >>/etc/modules-load.d/nvidia.conf

    log_success "Intel CPU + NVIDIA GPU configuration applied"
}

# Setup AMD CPU + AMD GPU configuration
setup_amd_configuration() {
    log_info "Setting up AMD CPU + AMD GPU configuration..."

    # Add kernel parameters to systemd-boot
    local kernel_params="amd_pstate=active amdgpu.si_support=1 amdgpu.cik_support=1 amdgpu.dc=1 amdgpu.ppfeaturemask=0xffffffff radeon.si_support=0 radeon.cik_support=0 processor.max_cstate=1"

    # Add to systemd-boot configuration
    if [[ -d "/boot/loader/entries" ]]; then
        log_info "Adding AMD kernel parameters to systemd-boot..."

        # Find the current boot entry
        local boot_entry=$(find /boot/loader/entries -name "*.conf" | head -1)
        if [[ -n "$boot_entry" ]]; then
            # Check if AMD parameters are already present
            if ! grep -q "amd_pstate=active" "$boot_entry"; then
                # Backup the original entry
                cp "$boot_entry" "${boot_entry}.backup.$(date +%Y%m%d_%H%M%S)"

                # Add kernel parameters to options line
                sed -i "/^options/ s/$/ $kernel_params/" "$boot_entry"
                log_info "Updated boot entry: $boot_entry"
            else
                log_info "AMD parameters already present in boot entry"
            fi
        else
            log_warning "No systemd-boot entries found in /boot/loader/entries"
        fi
    else
        log_warning "systemd-boot not detected, trying alternative kernel parameter method"
        # Fallback: create kernel parameters file
        echo "$kernel_params" >/etc/kernel/cmdline
    fi

    # AMD GPU modules
    mkdir -p /etc/modules-load.d
    echo "amdgpu" >>/etc/modules-load.d/amd.conf
    echo "crc32c" >>/etc/modules-load.d/amd.conf

    log_success "AMD configuration applied"
}

# Setup Intel CPU + Intel GPU configuration
setup_intel_configuration() {
    log_info "Setting up Intel CPU + Intel GPU configuration..."

    # Add kernel parameters to systemd-boot
    local kernel_params="intel_pstate=active i915.fastboot=1 i915.enable_fbc=1 i915.enable_psr=2 i915.modeset=1 acpi_osi=Linux mem_sleep_default=deep"

    # Add to systemd-boot configuration
    if [[ -d "/boot/loader/entries" ]]; then
        log_info "Adding Intel kernel parameters to systemd-boot..."

        # Find the current boot entry
        local boot_entry=$(find /boot/loader/entries -name "*.conf" | head -1)
        if [[ -n "$boot_entry" ]]; then
            # Check if Intel parameters are already present
            if ! grep -q "intel_pstate=active" "$boot_entry"; then
                # Backup the original entry
                cp "$boot_entry" "${boot_entry}.backup.$(date +%Y%m%d_%H%M%S)"

                # Add kernel parameters to options line
                sed -i "/^options/ s/$/ $kernel_params/" "$boot_entry"
                log_info "Updated boot entry: $boot_entry"
            else
                log_info "Intel parameters already present in boot entry"
            fi
        else
            log_warning "No systemd-boot entries found in /boot/loader/entries"
        fi
    else
        log_warning "systemd-boot not detected, trying alternative kernel parameter method"
        # Fallback: create kernel parameters file
        echo "$kernel_params" >/etc/kernel/cmdline
    fi

    # Intel GPU modules
    mkdir -p /etc/modules-load.d
    echo "i915" >>/etc/modules-load.d/intel.conf
    echo "crc32c" >>/etc/modules-load.d/intel.conf

    log_success "Intel configuration applied"
}

# Setup performance optimizations
setup_performance_optimizations() {
    if [[ "$SETUP_OPTIMIZATIONS" != "true" ]]; then
        return 0
    fi

    log_info "Setting up performance optimizations..."

    # Sysctl optimizations
    cat >/etc/sysctl.d/99-performance.conf <<'EOF'
# Performance optimizations

# Memory management
vm.swappiness = 10
vm.vfs_cache_pressure = 50
vm.dirty_background_ratio = 5
vm.dirty_ratio = 10

# Network performance
#net.core.rmem_max = 16777216
#net.core.wmem_max = 16777216
#net.core.rmem_default = 262144
#net.core.wmem_default = 262144
#net.core.netdev_max_backlog = 5000
#
## TCP optimizations
#net.ipv4.tcp_rmem = 4096 65536 16777216
#net.ipv4.tcp_wmem = 4096 65536 16777216
#net.ipv4.tcp_congestion_control = bbr

# File system performance
fs.file-max = 2097152
fs.inotify.max_user_watches = 1048576

# Kernel performance
kernel.sched_migration_cost_ns = 5000000
kernel.sched_autogroup_enabled = 0

# BTRFS-specific optimizations
vm.dirty_writeback_centisecs = 1500
vm.dirty_expire_centisecs = 3000
EOF

    # I/O scheduler optimization
    cat >/etc/udev/rules.d/60-ioschedulers.rules <<'EOF'
# Set I/O scheduler for different device types
ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
EOF

    log_success "Performance optimizations configured"
}

# Setup systemd services
setup_systemd_services() {
    if [[ "$SETUP_SERVICES" != "true" ]]; then
        return 0
    fi

    log_info "Setting up systemd services..."

    # Enable useful services
    local services=(
        "fstrim.timer"
        "systemd-oomd"
        "irqbalance"
    )

    for service in "${services[@]}"; do
        if systemctl list-unit-files | grep -q "$service"; then
            systemctl enable "$service" || log_warning "Failed to enable $service"
        fi
    done

    log_success "Systemd services configured"
}

# Setup user configuration
setup_user_config() {
    log_info "Setting up user configuration..."

    # Get the actual user (not root when using sudo)
    local actual_user="${SUDO_USER:-$USER}"

    if [[ "$actual_user" == "root" ]]; then
        log_warning "Could not determine actual user, skipping user configuration"
        return 0
    fi

    # Add user to important groups
    local groups=(
        "wheel"
        "docker"
        "audio"
        "video"
        "networkmanager"
        "bluetooth"
        "input"
        "plugdev"
        "lp"
        "dialout"
        "users"
    )

    for group in "${groups[@]}"; do
        if getent group "$group" >/dev/null 2>&1; then
            usermod -aG "$group" "$actual_user" || log_warning "Failed to add user to $group"
        fi
    done

    log_success "User configuration completed"
}

setup_plymouth() {
    log_info "Setting up Plymouth..."
    local plymouth_script="$SCRIPT_DIR/setup/plymouth.sh"

    if [ -f "$plymouth_script" ]; then
        log_info "Running Plymouth setup script..."
        bash "$plymouth_script"
    else
        log_warning "Plymouth setup script not found at $plymouth_script"
    fi
}

# Setup PAM authentication for hyprlock
setup_pam_hyprlock() {
    log_info "Setting up PAM authentication for hyprlock..."

    local pam_installer="$SCRIPT_DIR/setup/install-pam-hyprlock.sh"

    # Check if the PAM installer script exists
    if [[ ! -x "$pam_installer" ]]; then
        log_warning "PAM installer script not found at $pam_installer"
        return 0
    fi

    # Run the PAM installer
    log_info "Running PAM installer: $pam_installer"
    if "$pam_installer"; then
        log_success "PAM authentication for hyprlock configured successfully"
    else
        log_warning "PAM installer failed - you may need to run it manually"
        log_info "Manual installation: sudo $pam_installer"
    fi
}

# Main function
main() {
    echo
    log_info "🔧 Starting system configuration..."
    echo

    check_privileges

    setup_btrfs_config
    echo
    setup_hardware_config
    echo
    setup_performance_optimizations
    echo
    setup_systemd_services
    echo
    setup_user_config
    echo
    setup_pam_hyprlock
    echo
    setup_plymouth

    echo
    log_success "🎉 System configuration completed!"

    # Show what was configured based on options
    if [[ "$SETUP_BTRFS" == "true" || "$SETUP_HARDWARE" == "true" || "$SETUP_OPTIMIZATIONS" == "true" || "$SETUP_SERVICES" == "true" ]]; then
        log_warning "A reboot is recommended to apply all changes"

        if [[ "$SETUP_HARDWARE" == "true" ]]; then
            log_info "Hardware-specific kernel parameters have been applied"
        fi

        if [[ "$SETUP_BTRFS" == "true" ]]; then
            log_info "BTRFS maintenance services are now enabled"
        fi

        if [[ "$SETUP_OPTIMIZATIONS" == "true" ]]; then
            log_info "Performance optimizations are active"
        fi

        if [[ "$FORCE" == "true" ]]; then
            log_info "Configuration was applied with --force option"
        fi
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_args "$@"
    main
fi
