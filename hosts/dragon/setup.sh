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
source "${SCRIPT_DIR}/../../scripts/lib/install-state.sh"

log_info "🐉 Running setup for Dragon workstation..."

# Handle --reset flag to force re-run all steps
if [[ "${1:-}" == "--reset" ]]; then
    reset_all_steps
    log_info "Installation state reset. All steps will be re-run."
    echo
fi

# Install liquidctl for AIO cooler management
if ! is_step_completed "dragon-install-liquidctl"; then
    log_step "Installing liquidctl..."
    if install_package_if_needed liquidctl; then
        log_success "liquidctl installed"
        mark_step_completed "dragon-install-liquidctl"
    elif [[ $? -eq 1 ]]; then
        log_info "liquidctl already installed"
        mark_step_completed "dragon-install-liquidctl"
    else
        log_error "Could not install liquidctl - no package manager found"
        exit 1
    fi
else
    log_info "✓ liquidctl already installed (skipped)"
fi
echo

# Install NetBird
if ! is_step_completed "dragon-install-netbird"; then
    log_step "Installing NetBird..."
    if bash "$HOME/dotfiles/scripts/utilities/netbird-install.sh"; then
        mark_step_completed "dragon-install-netbird"
    fi
else
    log_info "✓ NetBird already installed (skipped)"
fi
echo

# Copy host-specific system configs
if ! is_step_completed "dragon-copy-system-configs"; then
    log_step "Copying host-specific system configs..."
    if copy_dir_if_changed "$HOME/dotfiles/hosts/dragon/etc/" /etc/; then
        log_success "System configs updated"
        mark_step_completed "dragon-copy-system-configs"
        # Reset DNS restart step since configs changed
        reset_step "dragon-restart-resolved"
    else
        log_info "System configs unchanged"
        mark_step_completed "dragon-copy-system-configs"
    fi
else
    # Check if configs need updating even if step was completed
    if copy_dir_if_changed "$HOME/dotfiles/hosts/dragon/etc/" /etc/; then
        log_info "✓ System configs updated (configs changed)"
        reset_step "dragon-restart-resolved"
    else
        log_info "✓ System configs already applied (skipped)"
    fi
fi
echo

# Apply DNS changes (only if configs changed or first time)
if ! is_step_completed "dragon-restart-resolved"; then
    log_step "Restarting systemd-resolved to apply DNS changes..."
    if restart_if_running systemd-resolved; then
        log_success "systemd-resolved restarted"
    fi
    mark_step_completed "dragon-restart-resolved"
else
    log_info "✓ DNS configuration already applied (skipped)"
fi
echo

# Install and enable dynamic LED service
if ! is_step_completed "dragon-install-dynamic-led"; then
    log_step "Installing dynamic_led service..."
    # Install Python script if changed
    if copy_if_changed "$HOME/dotfiles/hosts/dragon/dynamic_led.py" /usr/local/bin/dynamic_led.py; then
        sudo chmod +x /usr/local/bin/dynamic_led.py
    fi
    # Install and enable service
    install_service "$HOME/dotfiles/hosts/dragon/dynamic_led.service" "dynamic_led.service"
    log_success "dynamic_led service installed and started"
    mark_step_completed "dragon-install-dynamic-led"
else
    log_info "✓ dynamic_led service already installed (skipped)"
    # Still check if files need updating
    if copy_if_changed "$HOME/dotfiles/hosts/dragon/dynamic_led.py" /usr/local/bin/dynamic_led.py; then
        sudo chmod +x /usr/local/bin/dynamic_led.py
        log_info "  dynamic_led.py updated, restarting service..."
        sudo systemctl restart dynamic_led.service
    fi
    if copy_if_changed "$HOME/dotfiles/hosts/dragon/dynamic_led.service" /etc/systemd/system/dynamic_led.service; then
        log_info "  dynamic_led.service updated, restarting service..."
        sudo systemctl daemon-reload
        sudo systemctl restart dynamic_led.service
    fi
fi
echo

# Make liquidctl suspend hook executable
if ! is_step_completed "dragon-configure-suspend-hooks"; then
    log_step "Configuring suspend hooks..."
    sudo chmod +x /etc/systemd/system-sleep/liquidctl-suspend.sh 2>/dev/null || true
    mark_step_completed "dragon-configure-suspend-hooks"
else
    log_info "✓ Suspend hooks already configured (skipped)"
fi

# Apply power management configuration (defer disruptive restarts)
if ! is_step_completed "dragon-power-management"; then
    log_step "Applying power management configuration..."
    log_info "Power management configured: suspend on idle (30min), power button = suspend"
    log_warning "A reboot is recommended to fully apply power management changes"
    mark_step_completed "dragon-power-management"
else
    log_info "✓ Power management already configured (skipped)"
fi

# Install liquidctl service
if ! is_step_completed "dragon-install-liquidctl-service"; then
    log_step "Installing liquidctl AIO cooler service..."
    install_service "$HOME/dotfiles/hosts/dragon/liquidctl-dragon.service" "liquidctl-dragon.service"
    log_success "liquidctl service installed and started"
    mark_step_completed "dragon-install-liquidctl-service"
else
    log_info "✓ liquidctl service already installed (skipped)"
    # Still check if service file needs updating
    if copy_if_changed "$HOME/dotfiles/hosts/dragon/liquidctl-dragon.service" /etc/systemd/system/liquidctl-dragon.service; then
        log_info "  liquidctl-dragon.service updated, restarting..."
        sudo systemctl daemon-reload
        sudo systemctl restart liquidctl-dragon.service
    fi
fi

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
