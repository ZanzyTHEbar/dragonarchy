#!/usr/bin/env bash

# Main Setup Script for Traditional Dotfiles Management
# Replaces the functionality of the Nix flake and justfile

set -euo pipefail

# Get script directory and source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091  # Runtime-resolved path to logging library
source "${SCRIPT_DIR}/../../../../../scripts/lib/logging.sh"

# Colors for output

# Configuration
CONFIG_DIR="$SCRIPT_DIR"
PACKAGES_DIR="$CONFIG_DIR/packages"
SCRIPTS_DIR="$CONFIG_DIR/scripts"
HOSTS_DIR="$CONFIG_DIR/hosts"
SECRETS_DIR="$CONFIG_DIR/secrets"

# Default options
INSTALL_PACKAGES=true
INSTALL_DOTFILES=true
SETUP_SECRETS=true
HOST=""
VERBOSE=false
PACKAGES_ONLY=false
DOTFILES_ONLY=false
SECRETS_ONLY=false
SKIP_SECRETS=false
NO_SYSTEM_CONFIG=false

# Logging functions
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Traditional Dotfiles Management Setup Script

OPTIONS:
    -h, --help              Show this help message
    -v, --verbose           Enable verbose output
    --host HOST             Setup for specific host (dragon, spacedragon, microdragon, goldendragon)
    --packages-only         Only install packages
    --dotfiles-only         Only setup dotfiles
    --secrets-only          Only setup secrets
    --no-packages           Skip package installation
    --no-dotfiles           Skip dotfiles setup
    --no-secrets            Skip secrets setup

EXAMPLES:
    $0                      # Complete setup for current machine
    $0 --host dragon        # Setup for specific host
    $0 --packages-only      # Only install packages
    $0 --dotfiles-only      # Only setup dotfiles
    $0 --no-secrets         # Skip secrets setup

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --host)
                HOST="$2"
                shift 2
                ;;
            --packages-only)
                PACKAGES_ONLY=true
                INSTALL_DOTFILES=false
                SETUP_SECRETS=false
                shift
                ;;
            --dotfiles-only)
                DOTFILES_ONLY=true
                INSTALL_PACKAGES=false
                SETUP_SECRETS=false
                shift
                ;;
            --secrets-only)
                SECRETS_ONLY=true
                INSTALL_PACKAGES=false
                INSTALL_DOTFILES=false
                shift
                ;;
            --no-packages)
                INSTALL_PACKAGES=false
                shift
                ;;
            --no-dotfiles)
                INSTALL_DOTFILES=false
                shift
                ;;
            --no-secrets)
                SKIP_SECRETS=true
                SETUP_SECRETS=false
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

# Get list of available hosts from hosts directory
get_available_hosts() {
    if [[ -d "$HOSTS_DIR" ]]; then
        find "$HOSTS_DIR" -maxdepth 1 -type d ! -path "$HOSTS_DIR" -exec basename {} \; | sort
    fi
}

# Detect current host
detect_host() {
    local hostname
    hostname=$(hostname | cut -d. -f1)
    
    # Check if a host-specific configuration directory exists
    if [[ -d "$HOSTS_DIR/$hostname" ]]; then
        echo "$hostname"
    else
        # Return the actual hostname even if no specific config exists
        # This allows for dynamic hostname support
        echo "$hostname"
    fi
}

# Check prerequisites
check_prerequisites() {
    log_step "Checking prerequisites..."
    
    # Check if git is available
    if ! command -v git >/dev/null 2>&1; then
        log_error "Git is required but not installed"
        exit 1
    fi
    
    # Check if stow is available or can be installed
    if ! command -v stow >/dev/null 2>&1; then
        log_warning "GNU Stow not found, will be installed during package installation"
    fi
    
    # Check if we're in the right directory
    if [[ ! -d "$PACKAGES_DIR" ]]; then
        log_error "Packages directory not found. Are you running this from the correct location?"
        exit 1
    fi
    
    log_success "Prerequisites check completed"
}

# Install packages
install_packages() {
    if [[ "$INSTALL_PACKAGES" != "true" ]]; then
        return 0
    fi
    
    log_step "Installing packages..."
    
    local install_script="$SCRIPTS_DIR/install_deps.sh"
    
    if [[ -f "$install_script" ]]; then
        # Ensure the script is executable
        chmod +x "$install_script"
        
        # Pass the host argument if it's set
        if [[ -n "$HOST" ]]; then
            "$install_script" --host "$HOST"
        else
            "$install_script"
        fi
    else
        log_error "Package installation script not found: $install_script"
        exit 1
    fi
    
    log_success "Package installation completed"
}

# Setup dotfiles with stow
setup_dotfiles() {
    if [[ "$INSTALL_DOTFILES" != "true" ]]; then
        return 0
    fi
    
    log_step "Setting up dotfiles with GNU Stow..."
    
    # Ensure stow is available
    if ! command -v stow >/dev/null 2>&1; then
        log_error "GNU Stow is required but not available"
        exit 1
    fi
    
    # Change to packages directory
    cd "$PACKAGES_DIR"
    
    # List of stow packages to install
    local packages=(
        "zsh"
        "git"
        "kitty"
        "ssh"
        "nvim"
        "hyprland"
        "lazygit"
        "alacritty"
        "fastfetch"
        "fonts"
        "xournalpp"
        "typora"
        "themes"
        "theme-manager"
        "gpg"
        "applications"
        "icons-in-terminal"
        "tmux"
        "zed"
    )
    
    # Install each package
    for package in "${packages[@]}"; do
        if [[ -d "$package" ]]; then
            log_info "Installing dotfiles package: $package"
            if stow -t "$HOME" "$package"; then
                log_success "Installed $package dotfiles"
            else
                log_warning "Failed to install $package dotfiles (might already exist)"
            fi
        else
            log_warning "Package directory $package not found, skipping"
        fi
    done
    
    # Return to original directory
    cd "$CONFIG_DIR"
    
    log_success "Dotfiles setup completed"
}

# Stow system packages
stow_system_packages() {
    log_step "Stowing system packages..."
    if [[ -x "$SCRIPTS_DIR/stow-system.sh" ]]; then
        if [[ $EUID -eq 0 ]]; then
            "$SCRIPTS_DIR/stow-system.sh"
        else
            sudo "$SCRIPTS_DIR/stow-system.sh"
        fi
    else
        log_warning "stow-system.sh not found, skipping system package stowing."
    fi
}


# Setup host-specific configuration
setup_host_config() {
    if [[ -z "$HOST" ]]; then
        HOST=$(detect_host)
    fi
    
    log_step "Setting up host-specific configuration for: $HOST"
    
    local host_config_dir="$HOSTS_DIR/$HOST"
    
    if [[ -d "$host_config_dir" ]]; then
        log_info "Loading host-specific configuration from $host_config_dir"
        
        # Source host-specific setup script if it exists
        if [[ -f "$host_config_dir/setup.sh" ]]; then
            log_info "Running host-specific setup script..."
            bash "$host_config_dir/setup.sh"
        fi
        
        # Install host-specific dotfiles if they exist
        if [[ -d "$host_config_dir/dotfiles" ]]; then
            log_info "Installing host-specific dotfiles..."
            cd "$host_config_dir/dotfiles"
            if command -v stow >/dev/null 2>&1; then
                stow -t "$HOME" .
            else
                log_warning "Stow not available for host-specific dotfiles"
            fi
            cd "$CONFIG_DIR"
        fi
        
        log_success "Host-specific configuration completed"
    else
        log_warning "No host-specific configuration found for $HOST"
    fi
}

# Setup secrets management
setup_secrets() {
    if [[ "$SETUP_SECRETS" != "true" || "$SKIP_SECRETS" == "true" ]]; then
        return 0
    fi
    
    log_step "Setting up secrets management..."
    
    if [[ -x "$SCRIPTS_DIR/secrets.sh" ]]; then
        "$SCRIPTS_DIR/secrets.sh" setup
    else
        log_warning "Secrets management script not found, skipping"
    fi
    
    log_success "Secrets setup completed"
}

# Configure shell
configure_shell() {
    log_step "Configuring shell..."
    
    # Set zsh as default shell if not already
    if [[ "$SHELL" != */zsh ]]; then
        if command -v zsh >/dev/null 2>&1; then
            log_info "Setting zsh as default shell..."
            sudo chsh -s "$(which zsh)" "$USER"
            log_success "Default shell changed to zsh"
        else
            log_warning "zsh not found, cannot change default shell"
        fi
    else
        log_info "zsh is already the default shell"
    fi
    
    # Create necessary directories
    mkdir -p "$HOME/.config/zsh/hosts"
    mkdir -p "$HOME/.config/functions"
    mkdir -p "$HOME/.local/bin"
    
    log_success "Shell configuration completed"
}

# Post-setup tasks
post_setup() {
    log_step "Running post-setup tasks..."
    
    # Create symlinks for compatibility
    if [[ ! -L "$HOME/.zshrc" && -f "$HOME/.zshrc" ]]; then
        log_info "Backing up existing .zshrc"
        mv "$HOME/.zshrc" "$HOME/.zshrc.backup"
    fi
    
    # Reload shell configuration if possible
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        log_info "Reloading zsh configuration..."
        source "$HOME/.zshrc" 2>/dev/null || true
    fi
    
    # Install additional tools
    if [[ -x "$SCRIPTS_DIR/install/setup/post-install.sh" ]]; then
        log_info "Running post-installation script..."
        "$SCRIPTS_DIR/install/setup/post-install.sh"
    fi
    
    log_info "Running plymouth setup scripts..."
    bash "$SCRIPTS_DIR/install/setup/plymouth.sh"

    log_success "Post-setup tasks completed"
}

# Validate installation
validate_installation() {
    log_step "Validating installation..."
    
    if [[ -x "$SCRIPTS_DIR/validate.sh" ]]; then
        "$SCRIPTS_DIR/validate.sh"
    else
        log_info "Running basic validation..."
        
        # Check if key files exist
        local key_files=(
            "$HOME/.zshrc"
            "$HOME/.gitconfig"
            "$HOME/.config/kitty/kitty.conf"
        )
        
        for file in "${key_files[@]}"; do
            if [[ -f "$file" ]]; then
                log_success "✓ $file exists"
            else
                log_warning "✗ $file missing"
            fi
        done
        
        # Check if key commands are available
        local key_commands=(
            "zsh"
            "git"
            "nvim"
            "stow"
            "jq"
        )
        
        for cmd in "${key_commands[@]}"; do
            if command -v "$cmd" >/dev/null 2>&1; then
                log_success "✓ $cmd is available"
            else
                log_warning "✗ $cmd not found"
            fi
        done
    fi
    
    log_success "Validation completed"
}

# Show completion message
show_completion() {
    echo
    log_success "🎉 Dotfiles setup completed successfully!"
    echo
    log_info "Next steps:"
    echo "  1. Restart your terminal or run: source ~/.zshrc"
    echo "  2. Review configuration files in ~/.config/"
    echo "  3. Customize settings as needed"
    echo
    
    if [[ "$SETUP_SECRETS" == "true" ]]; then
        log_info "Secrets management:"
        echo "  • Use './scripts/secrets.sh --help' for secrets management"
        echo "  • Configure age keys if not already done"
        echo
    fi
    
    log_info "For updates and maintenance:"
    echo "  • Use './scripts/update.sh' to update packages and configs"
    echo "  • Use './scripts/validate.sh' to check system health"
    echo "  • Use 'stow -D <package>' to remove specific dotfiles"
    echo
}

# Main execution function
main() {
    echo
    log_info "🚀 Starting Dotfiles Management Setup"
    log_info "Configuration directory: $CONFIG_DIR"
    echo

    # Detect host if not specified via arguments
    if [[ -z "$HOST" ]]; then
        HOST=$(detect_host)
        log_info "No host specified, detected host: $HOST"
    fi
    
    # Run setup steps
    check_prerequisites
    install_packages
    setup_dotfiles
    stow_system_packages
    setup_host_config
    configure_shell
    post_setup
    validate_installation
    
    # Lets make this secrets optional for now
    #setup_secrets
    
    # System configuration (requires root)
    if [[ "$NO_SYSTEM_CONFIG" != "true" && "$PACKAGES_ONLY" != "true" && "$DOTFILES_ONLY" != "true" && "$SECRETS_ONLY" != "true" ]]; then
        log_info "Setting up system-level configuration..."
        if [[ $EUID -eq 0 ]]; then
            "$SCRIPTS_DIR/system-config.sh" || log_warning "System configuration failed"
        else
            log_info "System configuration requires root privileges"
            log_info "Run: sudo $SCRIPTS_DIR/system_config.sh"
        fi
        echo
    fi
    
    show_completion
}

# Handle script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Parse arguments
    parse_args "$@"
    
    # Enable verbose mode if requested
    if [[ "$VERBOSE" == "true" ]]; then
        set -x
    fi
    
    # Run main function
    main "$@"
fi
