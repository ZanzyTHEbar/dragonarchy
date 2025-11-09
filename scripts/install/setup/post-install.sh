#!/bin/bash
# Post-installation tasks to be run after the main installation completes.
# This script is called by install.sh as the final step in the setup process.
#
# Use this script for:
# - Installing additional tools not covered by the main installation
# - Running one-time configuration tasks
# - Setting up user-specific customizations
# - Performing cleanup tasks
# - Displaying post-installation instructions

set -e

# Get script directory and source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091  # Runtime-resolved path to logging library
source "${SCRIPT_DIR}/../../lib/logging.sh"

# =============================================================================
# Configuration
# =============================================================================

# Add any configuration variables here
# Example:
# INSTALL_OPTIONAL_TOOLS=${INSTALL_OPTIONAL_TOOLS:-true}

# =============================================================================
# Functions
# =============================================================================

# Install additional tools
install_additional_tools() {
    log_step "Installing additional tools..."
    
    # Add installation commands for tools not covered in the main installation
    # Example:
    # if command -v yay >/dev/null 2>&1; then
    #     log_info "Installing additional AUR packages..."
    #     yay -S --noconfirm --needed package-name
    # fi
    
    log_info "No additional tools to install (placeholder)"
}

# Configure user-specific settings
configure_user_settings() {
    log_step "Configuring user-specific settings..."
    
    # Add user-specific configuration tasks here
    # Example:
    # - Setting up development environments
    # - Configuring IDE settings
    # - Installing language-specific tools (npm packages, pip packages, etc.)

    log_info "Setting default theme to tokyo-night..."
    dbus-run-session -- bash "$SCRIPT_DIR/theme-manager/theme-set" "tokyo-night"
    
    log_info "No user settings to configure (placeholder)"
}

# Perform cleanup tasks
cleanup_tasks() {
    log_step "Running cleanup tasks..."
    
    # Add cleanup tasks here
    # Example:
    # - Removing temporary files
    # - Cleaning package cache
    # - Removing unnecessary backup files
    
    log_info "No cleanup tasks to run (placeholder)"
}

# Display post-installation instructions
show_post_install_info() {
    log_step "Post-installation information"
    
    # Display any important information, manual steps, or reminders
    # Example:
    # log_info "Remember to configure your SSH keys: ssh-keygen -t ed25519"
    # log_info "To enable Bluetooth: sudo systemctl enable --now bluetooth"
    
    log_info "No additional instructions (placeholder)"
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    log_info "Starting post-installation tasks..."
    echo
    
    # Uncomment and run the functions you need
    # install_additional_tools
    configure_user_settings
    # cleanup_tasks
    # show_post_install_info
    
    log_success "Post-installation tasks completed"
    echo
}

# Run main function
main "$@"

