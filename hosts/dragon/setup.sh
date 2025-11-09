#!/bin/bash
#
# Dragon Host-Specific Setup
#
# This script configures the Dragon AMD workstation.

set -e

# Get script directory and source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091  # Runtime-resolved path to logging library
source "${SCRIPT_DIR}/../../scripts/lib/logging.sh"

log_info "🐉 Running setup for Dragon workstation..."

# Setup AMD GPU configuration for desktop
setup_amd_gpu_desktop() {
    log_step "Configuring AMD GPU for desktop workstation..."
    
    sudo mkdir -p /etc/modprobe.d
    sudo tee /etc/modprobe.d/amdgpu.conf > /dev/null << 'EOF'
# AMD GPU Configuration - Dragon Desktop Workstation
# Optimized for professional workstation use with suspend/resume stability

# Enable all power management features
options amdgpu ppfeaturemask=0xffffffff
# Enable GPU recovery on crashes
options amdgpu gpu_recovery=1
# Enable Display Core (DC) for better display management
options amdgpu dc=1
# Desktop-specific: Keep GPU reset enabled for better recovery
options amdgpu gpu_reset=1
# Disable runtime PM for desktop performance
options amdgpu runpm=0
# Set power management policy
options amdgpu dpm=1
# Keep audio enabled
options amdgpu audio=1
EOF
    
    log_success "AMD GPU module parameters configured"
}

# Setup AMD GPU suspend/resume hooks
setup_amd_suspend_resume() {
    log_step "Setting up AMD GPU suspend/resume hooks..."
    
    sudo mkdir -p /etc/systemd/system
    
    # Create suspend service
    sudo tee /etc/systemd/system/amdgpu-suspend.service > /dev/null << 'EOF'
[Unit]
Description=AMD GPU Pre-Suspend Fix for Desktop
Before=sleep.target
StopWhenUnneeded=yes

[Service]
Type=oneshot
User=root
ExecStart=/bin/sh -c 'echo "Preparing AMD GPU for suspend..." > /tmp/amdgpu-suspend.log'
ExecStart=/bin/sh -c 'for card in /sys/class/drm/card*/device/power_dpm_force_performance_level; do echo "auto" > "$card" 2>/dev/null || true; done'
ExecStart=/bin/sh -c 'sync'
ExecStart=/usr/bin/sleep 0.5

[Install]
WantedBy=sleep.target
EOF
    
    # Create resume service
    sudo tee /etc/systemd/system/amdgpu-resume.service > /dev/null << 'EOF'
[Unit]
Description=AMD GPU Post-Resume Fix for Desktop
After=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
StopWhenUnneeded=yes

[Service]
Type=oneshot
User=root
ExecStart=/usr/bin/sleep 1
ExecStart=/bin/sh -c 'for card in /sys/class/drm/card*/device/power_dpm_force_performance_level; do echo "auto" > "$card" 2>/dev/null || true; done'
ExecStart=/bin/sh -c 'echo "AMD GPU resumed successfully" > /tmp/amdgpu-resume.log'

[Install]
WantedBy=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl enable amdgpu-suspend.service 2>/dev/null || true
    sudo systemctl enable amdgpu-resume.service 2>/dev/null || true
    
    log_success "AMD GPU suspend/resume hooks installed and enabled"
}

# Rebuild initramfs to apply module changes
rebuild_initramfs() {
    log_step "Rebuilding initramfs to apply AMD GPU module changes..."
    
    if sudo mkinitcpio -P; then
        log_success "Initramfs rebuilt successfully"
    else
        log_warning "Initramfs rebuild had warnings - usually okay"
    fi
}


# Install NetBird
log_step "Installing NetBird..."
bash "$HOME/dotfiles/scripts/utilities/netbird-install.sh"
echo

# Copy host-specific system configs
log_step "Copying host-specific system configs..."
sudo cp -rT "$HOME/dotfiles/hosts/dragon/etc/" /etc/
echo

# Apply DNS changes
log_step "Restarting systemd-resolved to apply DNS changes..."
sudo systemctl restart systemd-resolved
echo

# Setup AMD GPU configuration
setup_amd_gpu_desktop
echo

# Setup suspend/resume hooks
setup_amd_suspend_resume
echo

# Rebuild initramfs
rebuild_initramfs
echo

# Install and enable dynamic LED service
log_step "Installing dynamic_led service..."
sudo install -D -m 0755 "$HOME/dotfiles/hosts/dragon/dynamic_led.py" /usr/local/bin/dynamic_led.py
sudo cp "$HOME/dotfiles/hosts/dragon/dynamic_led.service" /etc/systemd/system/dynamic_led.service
sudo systemctl daemon-reload
sudo systemctl enable --now dynamic_led.service
echo

# Make liquidctl suspend hook executable
log_step "Configuring suspend hooks..."
sudo chmod +x /etc/systemd/system-sleep/liquidctl-suspend.sh || true

# Apply power management configuration (defer disruptive restarts)
log_step "Applying power management configuration..."
log_info "Power management configured: suspend on idle (30min), power button = suspend"
log_warning "A reboot is recommended to fully apply power management changes"

# Install liquidctl service
log_step "Installing liquidctl AIO cooler service..."
sudo cp "$HOME/dotfiles/hosts/dragon/liquidctl-dragon.service" /etc/systemd/system/liquidctl-dragon.service
sudo systemctl daemon-reload
sudo systemctl enable --now liquidctl-dragon.service
log_success "liquidctl service installed and started"

log_success "🐉 Dragon setup complete!"
log_info "Power configuration:"
log_info "  - Idle action: Suspend after 30 minutes"
log_info "  - Power button: Suspend (long press: poweroff)"
log_info "  - Sleep state: S3 (deep) with fallback to s2idle"
log_info "  - liquidctl: Auto-reinitialize on resume"
echo
log_warning "⚠️  REBOOT REQUIRED for AMD GPU changes to take effect"
echo
log_info "After reboot, test the following:"
echo "  1. Suspend/resume: systemctl suspend"
echo "  2. Lock screen: Super+L"
echo "  3. TTY access: Ctrl+Alt+F2"
echo "  4. Let hypridle timeout"
echo
log_info "Troubleshooting commands:"
echo "  • check-suspend     - Verify services installed"
echo "  • suspend-logs      - Check suspend/resume logs"
echo "  • check-inhibitors  - See what's preventing suspend"
echo "  • dragon-temps      - Monitor temperatures"
echo "  • aio-status        - Check AIO cooler"
echo
