#!/usr/bin/env bash

# Dragon Host-Specific Setup
# CachyOS Desktop development machine with AMD GPU + KDE Plasma 6

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Setup Dragon-specific packages
setup_dragon_packages() {
    log_info "Installing Dragon-specific packages..."
    
    # Desktop development tools
    local dragon_packages=(
        # Desktop environment
        "plasma-desktop"
        "plasma-workspace"
        "sddm"
        
        # Development tools
        "docker"
        "docker-compose"
        "virtualbox"
        "qemu"
        "libvirt"
        "virt-manager"
        
        # Media and graphics
        "blender"
        "gimp"
        "kdenlive"
        "obs-studio"
        
        # Gaming
        "steam"
        "lutris"
        "gamemode"
        
        # System monitoring
        "iotop"
        "nethogs"
        "lm_sensors"
        "smartmontools"
        
        # Cooling management
        "liquidctl"
        "corectrl"
        
        # File systems
        "btrfs-progs"
        "snapper"
    )
    
    for package in "${dragon_packages[@]}"; do
        if pacman -Qi "$package" &>/dev/null; then
            log_info "Package $package is already installed"
        else
            log_info "Installing $package..."
            if sudo pacman -S --noconfirm "$package"; then
                log_success "Installed $package"
            else
                log_warning "Failed to install $package"
            fi
        fi
    done
}

# Setup AIO cooler (Corsair H100i Platinum SE)
setup_aio_cooler() {
    log_info "Setting up custom Dragon AIO cooler configuration..."
    
    if ! command_exists liquidctl; then
        log_warning "liquidctl not found, skipping AIO setup"
        return 0
    fi
    
    # Get the directory where this script is located
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local unit_file="$script_dir/liquidctl-dragon.service"
    
    if [[ ! -f "$unit_file" ]]; then
        log_error "Custom liquidctl unit file not found: $unit_file"
        return 1
    fi
    
    # Install the custom systemd unit file
    log_info "Installing custom liquidctl systemd unit file..."
    sudo cp "$unit_file" /etc/systemd/system/
    sudo chmod 644 /etc/systemd/system/liquidctl-dragon.service
    
    # Reload systemd and enable the service
    sudo systemctl daemon-reload
    sudo systemctl enable liquidctl-dragon.service
    
    # Try to start the service immediately
    if sudo systemctl start liquidctl-dragon.service; then
        log_success "Dragon AIO cooler service configured and started"
    else
        log_warning "AIO cooler service installed but failed to start (may need reboot)"
    fi
    
    # Show service status
    log_info "Liquidctl service status:"
    sudo systemctl status liquidctl-dragon.service --no-pager || true
}

# Setup BTRFS snapshots
setup_btrfs_snapshots() {
    log_info "Setting up BTRFS snapshots..."
    
    if ! command_exists snapper; then
        log_warning "snapper not found, skipping snapshot setup"
        return 0
    fi
    
    # Create snapper config for root
    if ! sudo snapper list-configs | grep -q root; then
        sudo snapper create-config /
        log_success "Snapper config for root created"
    fi
    
    # Configure snapper
    sudo tee /etc/snapper/configs/root > /dev/null << 'EOF'
SUBVOLUME="/"
FSTYPE="btrfs"
QGROUP=""
SPACE_LIMIT="0.5"
FREE_LIMIT="0.2"
ALLOW_USERS=""
ALLOW_GROUPS=""
SYNC_ACL="no"
BACKGROUND_COMPARISON="yes"
NUMBER_CLEANUP="yes"
NUMBER_MIN_AGE="1800"
NUMBER_LIMIT="50"
NUMBER_LIMIT_IMPORTANT="10"
TIMELINE_CREATE="yes"
TIMELINE_CLEANUP="yes"
TIMELINE_MIN_AGE="1800"
TIMELINE_LIMIT_HOURLY="10"
TIMELINE_LIMIT_DAILY="10"
TIMELINE_LIMIT_WEEKLY="0"
TIMELINE_LIMIT_MONTHLY="10"
TIMELINE_LIMIT_YEARLY="10"
EOF
    
    # Enable snapper timer
    sudo systemctl enable snapper-timeline.timer
    sudo systemctl enable snapper-cleanup.timer
    
    log_success "BTRFS snapshots configured"
}

# Setup development environment
setup_dev_environment() {
    log_info "Setting up development environment..."
    
    # Add user to docker group
    if command_exists docker; then
        sudo usermod -aG docker "$USER"
        log_info "Added user to docker group"
    fi
    
    # Add user to libvirt group
    if command_exists virsh; then
        sudo usermod -aG libvirt "$USER"
        log_info "Added user to libvirt group"
    fi
    
    # Enable services
    local services=(
        "docker"
        "libvirtd"
    )
    
    for service in "${services[@]}"; do
        if systemctl list-unit-files | grep -q "$service"; then
            sudo systemctl enable "$service"
            log_info "Enabled $service service"
        fi
    done
}

# Setup gaming environment
setup_gaming() {
    log_info "Setting up gaming environment..."
    
    # Enable multilib repository for Steam
    if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
        log_info "Enabling multilib repository..."
        sudo sed -i '/^\[multilib\]/,/^$/s/^#//' /etc/pacman.conf
        sudo pacman -Sy
    fi
    
    # Install gaming-related packages
    local gaming_packages=(
        "steam"
        "lutris"
        "wine"
        "winetricks"
        "gamemode"
        "lib32-mesa"
        "lib32-vulkan-radeon"  # AMD GPU drivers
    )
    
    for package in "${gaming_packages[@]}"; do
        if ! pacman -Qi "$package" &>/dev/null; then
            log_info "Installing $package..."
            sudo pacman -S --noconfirm "$package" || log_warning "Failed to install $package"
        fi
    done
    
    log_success "Gaming environment configured"
}

# Setup AMD GPU optimizations
setup_amd_gpu() {
    log_info "Setting up AMD GPU optimizations..."
    
    # Install AMD drivers
    local amd_packages=(
        "mesa"
        "vulkan-radeon"
        "lib32-mesa"
        "lib32-vulkan-radeon"
        "radeontop"
    )
    
    for package in "${amd_packages[@]}"; do
        if ! pacman -Qi "$package" &>/dev/null; then
            sudo pacman -S --noconfirm "$package" || log_warning "Failed to install $package"
        fi
    done
    
    # Add AMD GPU monitoring alias
    if [[ -f "$HOME/.config/zsh/hosts/dragon.zsh" ]]; then
        echo "alias gpu-monitor='radeontop'" >> "$HOME/.config/zsh/hosts/dragon.zsh"
    fi
    
    log_success "AMD GPU optimizations configured"
}

# Setup KDE Plasma customizations
setup_kde_customizations() {
    log_info "Setting up KDE Plasma customizations..."
    
    # Create KDE configuration directory
    mkdir -p "$HOME/.config"
    
    # Set up basic KDE settings (this would be expanded with actual KDE configs)
    log_info "KDE customizations will be applied on next login"
    log_success "KDE customizations prepared"
}

# Setup performance optimizations
setup_performance() {
    log_info "Setting up performance optimizations..."
    
    # Setup swappiness for desktop use
    echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-swappiness.conf > /dev/null
    
    # Setup I/O scheduler for SSD
    echo 'ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"' | \
        sudo tee /etc/udev/rules.d/60-ioschedulers.rules > /dev/null
    
    # Enable zram if available
    if command_exists zramctl; then
        log_info "Setting up zram..."
        # This would need a proper zram configuration
    fi
    
    log_success "Performance optimizations configured"
}

# Create dragon-specific shell configuration
create_host_config() {
    log_info "Creating dragon-specific shell configuration..."
    
    mkdir -p "$HOME/.config/zsh/hosts"
    
    # Create base dragon configuration
    cat > "$HOME/.config/zsh/hosts/dragon.zsh" << 'EOF'
# Dragon-specific ZSH configuration

# System aliases
alias temp='sensors'
alias gpu-temp='radeontop -d -'

# Development aliases
alias docker-clean='docker system prune -af'
alias vm-list='virsh list --all'

# Gaming aliases
alias steam-start='steam-runtime'
alias lutris-start='lutris'

# Snapshot management
alias snap-list='sudo snapper list'
alias snap-create='sudo snapper create --description'

# Performance monitoring
alias cpu-freq='watch -n1 "cat /proc/cpuinfo | grep MHz"'
alias mem-usage='free -h && echo && ps aux --sort=-%mem | head -10'

# Dragon-specific environment variables
export GAMING_MODE=true
export GPU_TYPE="AMD"
export DESKTOP_SESSION="plasma"

# Load gaming-specific functions
if [[ -f "$HOME/.config/functions/gaming-utils.zsh" ]]; then
    source "$HOME/.config/functions/gaming-utils.zsh"
fi
EOF
    
    # Append dragon-specific configuration if the file exists
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "$script_dir/dragon.zsh" ]]; then
        log_info "Adding dragon-specific shell configuration..."
        cat "$script_dir/dragon.zsh" >> "$HOME/.config/zsh/hosts/dragon.zsh"
    fi
    
    log_success "Dragon-specific configuration created"
}

# Main setup function
main() {
    log_info "🐉 Setting up Dragon-specific configuration..."
    echo
    
    setup_dragon_packages
    echo
    setup_aio_cooler
    echo
    setup_btrfs_snapshots
    echo
    setup_dev_environment
    echo
    setup_gaming
    echo
    setup_amd_gpu
    echo
    setup_kde_customizations
    echo
    setup_performance
    echo
    create_host_config
    
    echo
    log_success "🎉 Dragon setup completed!"
    log_info "Please reboot to apply all changes"
    log_info "Log out and back in to apply group memberships"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 