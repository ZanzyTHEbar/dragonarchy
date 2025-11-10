#!/bin/bash
#
# GoldenDragon Host-Specific Setup
#
# This script configures the GoldenDragon workstation.

set -e

# Get script directory and source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091  # Runtime-resolved path to logging library
source "${SCRIPT_DIR}/../../scripts/lib/logging.sh"
source "${SCRIPT_DIR}/../../scripts/lib/install-state.sh"

log_info "Running setup for GoldenDragon workstation..."

# Handle --reset flag to force re-run all steps
if [[ "${1:-}" == "--reset" ]]; then
    reset_all_steps
    log_info "Installation state reset. All steps will be re-run."
    echo
fi

# Install NetBird
if ! is_step_completed "goldendragon-install-netbird"; then
    log_step "Installing NetBird..."
    if bash "$HOME/dotfiles/scripts/utilities/netbird-install.sh"; then
        mark_step_completed "goldendragon-install-netbird"
    fi
else
    log_info "✓ NetBird already installed (skipped)"
fi
echo

# Copy host-specific system configs
if ! is_step_completed "goldendragon-copy-system-configs"; then
    log_step "Copying host-specific system configs..."
    if copy_dir_if_changed "$HOME/dotfiles/hosts/goldendragon/etc/" /etc/; then
        log_success "System configs updated"
        mark_step_completed "goldendragon-copy-system-configs"
        # Reset DNS restart step since configs changed
        reset_step "goldendragon-restart-resolved"
    else
        log_info "System configs unchanged"
        mark_step_completed "goldendragon-copy-system-configs"
    fi
else
    # Check if configs need updating even if step was completed
    if copy_dir_if_changed "$HOME/dotfiles/hosts/goldendragon/etc/" /etc/; then
        log_info "✓ System configs updated (configs changed)"
        reset_step "goldendragon-restart-resolved"
    else
        log_info "✓ System configs already applied (skipped)"
    fi
fi
echo

# Apply DNS changes (only if configs changed or first time)
if ! is_step_completed "goldendragon-restart-resolved"; then
    log_step "Restarting systemd-resolved to apply DNS changes..."
    if restart_if_running systemd-resolved; then
        log_success "systemd-resolved restarted"
    fi
    mark_step_completed "goldendragon-restart-resolved"
else
    log_info "✓ DNS configuration already applied (skipped)"
fi
echo

log_success "GoldenDragon setup complete!"
