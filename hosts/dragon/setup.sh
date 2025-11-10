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
