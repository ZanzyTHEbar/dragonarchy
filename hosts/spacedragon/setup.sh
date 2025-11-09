#!/usr/bin/env bash

# Spacedragon Host-Specific Setup
# Portable/laptop development machine

set -euo pipefail

# Get script directory and source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091  # Runtime-resolved path to logging library
source "${SCRIPT_DIR}/../../scripts/lib/logging.sh"

# Setup Spacedragon-specific packages
setup_spacedragon_packages() {
    log_info "Installing Spacedragon-specific packages..."
    
    # Laptop/portable focused packages
    local spacedragon_packages=(
        # Power management
        "tlp"
        "powertop"
        "acpi"
        "acpi_call"
        
        # Wireless and networking
        "networkmanager"
        "network-manager-applet"
        "bluez"
        "bluez-utils"
        "wireless_tools"
        
        # Laptop hardware support
        "xf86-input-synaptics"
        "libinput"
        "brightnessctl"
        
        # Portable development
        "code"
        "insync"
        "signal-desktop"
        
        # Lightweight alternatives
        "alacritty"
        "ranger"
        "ncdu"
        
        # Battery monitoring
        "upower"
        "acpid"
    )
    
    for package in "${spacedragon_packages[@]}"; do
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

# Setup power management
setup_power_management() {
    log_info "Setting up power management..."
    
    # Install and configure TLP
    if command_exists tlp; then
        # Enable TLP service
        sudo systemctl enable tlp.service
        sudo systemctl enable tlp-sleep.service
        
        # Mask conflicting services
        sudo systemctl mask systemd-rfkill.service
        sudo systemctl mask systemd-rfkill.socket
        
        # Create TLP configuration
        sudo tee /etc/tlp.d/01-spacedragon.conf > /dev/null << 'EOF'
# Spacedragon TLP Configuration

# CPU Scaling Governor
CPU_SCALING_GOVERNOR_ON_AC=performance
CPU_SCALING_GOVERNOR_ON_BAT=schedutil

# CPU Energy Performance Policies
CPU_ENERGY_PERF_POLICY_ON_AC=performance
CPU_ENERGY_PERF_POLICY_ON_BAT=power

# CPU Min/Max Frequencies
CPU_MIN_PERF_ON_AC=0
CPU_MAX_PERF_ON_AC=100
CPU_MIN_PERF_ON_BAT=0
CPU_MAX_PERF_ON_BAT=30

# Turbo Boost
CPU_BOOST_ON_AC=1
CPU_BOOST_ON_BAT=0

# Graphics
RADEON_DPM_PERF_LEVEL_ON_AC=high
RADEON_DPM_PERF_LEVEL_ON_BAT=low

# WiFi Power Saving
WIFI_PWR_ON_AC=off
WIFI_PWR_ON_BAT=on

# USB Auto-suspend
USB_AUTOSUSPEND=1

# Runtime Power Management
RUNTIME_PM_ON_AC=on
RUNTIME_PM_ON_BAT=auto
EOF
        
        log_success "TLP configured for laptop use"
    fi
    
    # Setup acpid for power events
    if command_exists acpid; then
        sudo systemctl enable acpid.service
        log_success "ACPI daemon enabled"
    fi
}

# Setup wireless and networking
setup_networking() {
    log_info "Setting up wireless and networking..."
    
    # Enable NetworkManager
    if command_exists nmcli; then
        sudo systemctl enable NetworkManager.service
        log_success "NetworkManager enabled"
    fi
    
    # Enable Bluetooth
    if command_exists bluetoothctl; then
        sudo systemctl enable bluetooth.service
        log_success "Bluetooth enabled"
    fi
    
    # Add user to network group
    sudo usermod -aG network "$USER"
    log_info "Added user to network group"
}

# Setup display and input
setup_display_input() {
    log_info "Setting up display and input devices..."
    
    # Create libinput configuration for touchpad
    sudo tee /etc/X11/xorg.conf.d/30-touchpad.conf > /dev/null << 'EOF'
Section "InputClass"
    Identifier "touchpad"
    Driver "libinput"
    MatchIsTouchpad "on"
    Option "Tapping" "on"
    Option "TappingButtonMap" "lrm"
    Option "NaturalScrolling" "true"
    Option "ScrollMethod" "twofinger"
    Option "HorizontalScrolling" "true"
    Option "DisableWhileTyping" "true"
EndSection
EOF
    
    log_success "Touchpad configuration created"
}

# Setup development environment for portable use
setup_portable_dev() {
    log_info "Setting up portable development environment..."
    
    # Install portable development tools
    local dev_packages=(
        "code"
        "docker"
        "podman"
        "git-lfs"
        "rsync"
        "unison"
    )
    
    for package in "${dev_packages[@]}"; do
        if ! pacman -Qi "$package" &>/dev/null; then
            sudo pacman -S --noconfirm "$package" || log_warning "Failed to install $package"
        fi
    done
    
    # Add user to docker group
    if command_exists docker; then
        sudo usermod -aG docker "$USER"
        sudo systemctl enable docker.service
        log_info "Docker configured for portable use"
    fi
}

# Setup battery monitoring
setup_battery_monitoring() {
    log_info "Setting up battery monitoring..."
    
    # Create battery status script
    mkdir -p "$HOME/.local/bin"
    
    cat > "$HOME/.local/bin/battery-status" << 'EOF'
#!/bin/bash
# Battery status script for spacedragon

BAT_PATH="/sys/class/power_supply/BAT0"
AC_PATH="/sys/class/power_supply/ADP1"

if [[ -f "$BAT_PATH/capacity" ]]; then
    CAPACITY=$(cat "$BAT_PATH/capacity")
    STATUS=$(cat "$BAT_PATH/status")
    
    echo "Battery: $CAPACITY% ($STATUS)"
    
    if [[ -f "$AC_PATH/online" ]]; then
        AC_STATUS=$(cat "$AC_PATH/online")
        if [[ "$AC_STATUS" == "1" ]]; then
            echo "AC Adapter: Connected"
        else
            echo "AC Adapter: Disconnected"
        fi
    fi
    
    # Power consumption
    if [[ -f "$BAT_PATH/power_now" ]]; then
        POWER_NOW=$(cat "$BAT_PATH/power_now")
        POWER_WATTS=$((POWER_NOW / 1000000))
        echo "Power Draw: ${POWER_WATTS}W"
    fi
else
    echo "Battery information not available"
fi
EOF
    
    chmod +x "$HOME/.local/bin/battery-status"
    log_success "Battery monitoring script created"
}

# Setup backup and sync
setup_backup_sync() {
    log_info "Setting up backup and sync..."
    
    # Create backup script for important data
    mkdir -p "$HOME/.local/bin"
    
    cat > "$HOME/.local/bin/laptop-backup" << 'EOF'
#!/bin/bash
# Laptop backup script

BACKUP_DIR="$HOME/Backups/$(date +%Y-%m-%d)"
mkdir -p "$BACKUP_DIR"

echo "Starting backup to $BACKUP_DIR..."

# Backup important directories
rsync -av --progress "$HOME/.config/" "$BACKUP_DIR/config/"
rsync -av --progress "$HOME/Documents/" "$BACKUP_DIR/Documents/"
rsync -av --progress "$HOME/Projects/" "$BACKUP_DIR/Projects/" 2>/dev/null || true

# Backup SSH keys
if [[ -d "$HOME/.ssh" ]]; then
    rsync -av --progress "$HOME/.ssh/" "$BACKUP_DIR/ssh/"
fi

# Backup age keys
if [[ -d "$HOME/.config/sops" ]]; then
    rsync -av --progress "$HOME/.config/sops/" "$BACKUP_DIR/sops/"
fi

echo "Backup completed: $BACKUP_DIR"
EOF
    
    chmod +x "$HOME/.local/bin/laptop-backup"
    log_success "Backup script created"
}

# Create spacedragon-specific shell configuration
create_host_config() {
    log_info "Creating spacedragon-specific shell configuration..."
    
    mkdir -p "$HOME/.config/zsh/hosts"
    
    cat > "$HOME/.config/zsh/hosts/spacedragon.zsh" << 'EOF'
# Spacedragon-specific ZSH configuration

# Power management aliases
alias battery='battery-status'
alias powersave='sudo tlp bat'
alias powerperf='sudo tlp ac'
alias powertop-cal='sudo powertop --calibrate'

# Network aliases
alias wifi='nmcli device wifi'
alias wifi-connect='nmcli device wifi connect'
alias wifi-list='nmcli device wifi list'
alias bluetooth='bluetoothctl'

# Backup aliases
alias backup='laptop-backup'
alias sync-projects='rsync -av ~/Projects/ /media/backup/Projects/'

# System monitoring for laptop
alias temp='sensors | grep -E "(Package|Core|Tctl)"'
alias fans='sensors | grep fan'
alias power='upower -i $(upower -e | grep BAT)'

# Brightness control
alias bright='brightnessctl'
alias bright-up='brightnessctl set +10%'
alias bright-down='brightnessctl set 10%-'

# Development aliases optimized for laptop
alias dev-start='docker-compose up -d'
alias dev-stop='docker-compose down'
alias code-portable='code --disable-gpu'

# Quick system info
alias sysinfo='echo "Battery: $(cat /sys/class/power_supply/BAT0/capacity)% | Load: $(uptime | cut -d, -f3-)"'

# Spacedragon-specific environment variables
export LAPTOP_MODE=true
export POWER_PROFILE="balanced"
export DISPLAY_SCALING="1.25"

# Load laptop-specific functions
if [[ -f "$HOME/.config/functions/laptop-utils.zsh" ]]; then
    source "$HOME/.config/functions/laptop-utils.zsh"
fi

# Auto-set power profile based on AC status
if command -v tlp-stat >/dev/null 2>&1; then
    if [[ -f /sys/class/power_supply/ADP1/online ]]; then
        AC_STATUS=$(cat /sys/class/power_supply/ADP1/online)
        if [[ "$AC_STATUS" == "0" ]]; then
            export POWER_PROFILE="battery"
        else
            export POWER_PROFILE="ac"
        fi
    fi
fi
EOF
    
    # Create Hyprland host-specific configuration for laptops
    log_info "Creating Hyprland laptop-specific configuration..."
    mkdir -p "$HOME/.config/hypr/config"
    
    cat > "$HOME/.config/hypr/config/host-config.conf" << 'EOF'
# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ┃              Spacedragon Laptop-Specific Configuration      ┃
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
# This file is created by the Spacedragon host setup
# It sources laptop-specific configurations like touchpad gestures

# Enable touchpad gesture support
source = ~/.config/hypr/config/gestures.conf

# You can add other laptop-specific Hyprland settings here
# For example:
# - Laptop-specific monitor configurations
# - Battery-aware rules
# - Touch screen settings
EOF
    
    log_success "Spacedragon-specific configuration created"
}

# Setup laptop-specific optimizations
setup_laptop_optimizations() {
    log_info "Setting up laptop optimizations..."
    
    # Reduce swappiness for laptop use
    echo 'vm.swappiness=1' | sudo tee /etc/sysctl.d/99-laptop-swappiness.conf > /dev/null
    
    # Setup laptop mode for disk
    echo 'vm.laptop_mode=1' | sudo tee /etc/sysctl.d/99-laptop-mode.conf > /dev/null
    
    # Setup hibernation support
    if [[ -f /sys/power/state ]] && grep -q disk /sys/power/state; then
        log_info "Hibernation support detected"
        # Additional hibernation setup would go here
    fi
    
    log_success "Laptop optimizations configured"
}

# Main setup function
main() {
    log_info "🚀 Setting up Spacedragon-specific configuration..."
    echo
    
    setup_spacedragon_packages
    echo
    setup_power_management
    echo
    setup_networking
    echo
    setup_display_input
    echo
    setup_portable_dev
    echo
    setup_battery_monitoring
    echo
    setup_backup_sync
    echo
    setup_laptop_optimizations
    echo
    create_host_config
    
    echo
    log_success "🎉 Spacedragon setup completed!"
    log_info "Please reboot to apply all changes"
    log_info "Log out and back in to apply group memberships"
    log_info "Run 'tlp-stat' to check power management status"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
