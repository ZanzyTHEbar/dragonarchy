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

THEMES_DIR="$SCRIPT_DIR/../../theme-manager"

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
    
    local missing=()
    local optional_tools=(
        "fzf"
        "bat"
        "eza"
        "btop"
        "fd"
        "ripgrep"
        "zoxide"
    )

    for tool in "${optional_tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            log_info "Optional tool present: $tool"
        else
            missing+=("$tool")
        fi
    done
    
    if ((${#missing[@]} == 0)); then
        log_success "All optional tools are already available"
    else
        log_warning "Optional tools missing: ${missing[*]}"
        log_info "Install them manually for the full workflow: ${missing[*]}"
    fi
}

# Configure user-specific settings
configure_user_settings() {
    log_step "Configuring user-specific settings..."
    
    # Add user-specific configuration tasks here
    # Example:
    # - Setting up development environments
    # - Configuring IDE settings
    # - Installing language-specific tools (npm packages, pip packages, etc.)
    
    log_info "Setting default theme to tokyo-night (non-interactive mode)..."
    bash "$THEMES_DIR/theme-set" --no-gui "tokyo-night"
    
    log_info "Theme symlinks configured. Background will be set on first login."
}

# Perform cleanup tasks
cleanup_tasks() {
    log_step "Running cleanup tasks..."

    local cleanup_targets=(
        "$HOME/.cache/dotfiles"
        "$HOME/.cache/dotfiles-install"
        "$HOME/.local/share/dotfiles"
    )

    for target in "${cleanup_targets[@]}"; do
        if [[ -d "$target" ]]; then
            local before after
            before=$(find "$target" -type f 2>/dev/null | wc -l)
            find "$target" -type f -name "*.tmp" -delete 2>/dev/null || true
            find "$target" -type d -empty -delete 2>/dev/null || true
            after=$(find "$target" -type f 2>/dev/null | wc -l)
            log_info "Cleanup '$target': removed $((before - after)) temporary files"
        else
            log_info "Cleanup target not present, skipping: $target"
        fi
    done
}

# Display post-installation instructions
show_post_install_info() {
    log_step "Post-installation information"
    
    log_info "✓ Theme symlinks have been configured (tokyo-night)"
    log_info "→ The theme background will be automatically set on first login"
    log_info "→ To manually change themes, use: dragon-cli theme"
    log_info "→ To manually set a background, use: dragon-cli background"
    echo
    log_info "If you encounter any issues with the theme not loading:"
    log_info "  1. Log out and log back in"
    log_info "  2. Or run: theme-set tokyo-night"
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    log_info "Starting post-installation tasks..."
    echo
    
    install_additional_tools
    configure_user_settings
    cleanup_tasks
    show_post_install_info
    
    log_success "Post-installation tasks completed"
    echo
}

# Run main function
main "$@"

