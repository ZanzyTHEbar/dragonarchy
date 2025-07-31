#!/usr/bin/env bash

# System Update Script
# Updates packages, dotfiles, and maintains the system

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")"

# Options
UPDATE_PACKAGES=true
UPDATE_DOTFILES=true
CLEAN_SYSTEM=false
VERBOSE=false

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
    cat << EOF
Usage: $0 [OPTIONS]

System Update and Maintenance Script

OPTIONS:
    -h, --help              Show this help message
    -v, --verbose           Enable verbose output
    --packages-only         Only update packages
    --dotfiles-only         Only update dotfiles
    --clean                 Perform system cleanup
    --no-packages           Skip package updates
    --no-dotfiles           Skip dotfiles updates

EXAMPLES:
    $0                      # Update everything
    $0 --packages-only      # Only update packages
    $0 --clean              # Update and clean system
    $0 --no-packages        # Update dotfiles only

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
            --packages-only)
                UPDATE_DOTFILES=false
                shift
                ;;
            --dotfiles-only)
                UPDATE_PACKAGES=false
                shift
                ;;
            --clean)
                CLEAN_SYSTEM=true
                shift
                ;;
            --no-packages)
                UPDATE_PACKAGES=false
                shift
                ;;
            --no-dotfiles)
                UPDATE_DOTFILES=false
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

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Detect platform
detect_platform() {
    case "$(uname -s)" in
        Darwin*)
            echo "macos"
            ;;
        Linux*)
            if [[ -f /etc/os-release ]]; then
                source /etc/os-release
                echo "$ID"
            else
                echo "linux"
            fi
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Update packages for different platforms
update_packages() {
    if [[ "$UPDATE_PACKAGES" != "true" ]]; then
        return 0
    fi
    
    log_info "Updating system packages..."
    
    local platform
    platform=$(detect_platform)
    
    case "$platform" in
        "macos")
            if command_exists brew; then
                log_info "Updating Homebrew packages..."
                brew update
                brew upgrade
                brew upgrade --cask
                log_success "Homebrew packages updated"
            else
                log_warning "Homebrew not found"
            fi
            ;;
        "arch"|"cachyos"|"manjaro")
            log_info "Updating Arch packages..."
            sudo pacman -Syu --noconfirm
            
            if command_exists yay; then
                log_info "Updating AUR packages..."
                yay -Syu --noconfirm
            fi
            log_success "Arch packages updated"
            ;;
        "ubuntu"|"debian")
            log_info "Updating Debian/Ubuntu packages..."
            sudo apt update
            sudo apt upgrade -y
            sudo apt autoremove -y
            log_success "Debian/Ubuntu packages updated"
            ;;
        *)
            log_warning "Unknown platform, skipping package updates"
            ;;
    esac
    
    # Update language-specific packages
    update_language_packages
}

# Update language-specific packages
update_language_packages() {
    log_info "Updating language-specific packages..."
    
    # Update Node.js packages
    if command_exists npm; then
        log_info "Updating global npm packages..."
        npm update -g || log_warning "Failed to update npm packages"
    fi
    
    # Update Python packages
    if command_exists pip3; then
        log_info "Updating Python packages..."
        pip3 list --outdated --format=freeze | grep -v '^\-e' | cut -d = -f 1 | xargs -n1 pip3 install -U || log_warning "Failed to update Python packages"
    fi
    
    # Update Rust packages
    if command_exists cargo; then
        log_info "Updating Rust packages..."
        if command_exists cargo-install-update; then
            cargo install-update -a || log_warning "Failed to update Rust packages"
        else
            log_warning "cargo-install-update not found, install with: cargo install cargo-update"
        fi
    fi
    
    # Update Go packages
    if command_exists go; then
        log_info "Updating Go packages..."
        # Update specific tools we use
        local go_tools=(
            "github.com/junegunn/fzf@latest"
            "github.com/jesseduffield/lazygit@latest"
        )
        
        for tool in "${go_tools[@]}"; do
            go install "$tool" || log_warning "Failed to update $tool"
        done
    fi
    
    # Update Ruby gems
    if command_exists gem; then
        log_info "Updating Ruby gems..."
        gem update || log_warning "Failed to update Ruby gems"
    fi
}

# Update dotfiles
update_dotfiles() {
    if [[ "$UPDATE_DOTFILES" != "true" ]]; then
        return 0
    fi
    
    log_info "Updating dotfiles..."
    
    # Pull latest changes from git if in a git repository
    if [[ -d "$CONFIG_DIR/.git" ]]; then
        cd "$CONFIG_DIR"
        
        # Check if there are uncommitted changes
        if ! git diff-index --quiet HEAD --; then
            log_warning "Uncommitted changes detected, stashing..."
            git stash push -m "Auto-stash before update $(date)"
        fi
        
        # Pull latest changes
        log_info "Pulling latest dotfiles changes..."
        git pull origin main || git pull origin master || log_warning "Failed to pull changes"
        
        # Reinstall dotfiles with stow
        log_info "Reinstalling dotfiles..."
        cd "$CONFIG_DIR/packages"
        
        local packages=(
            "zsh"
            "git"
            "kitty"
            "ssh"
            "nvim"
        )
        
        for package in "${packages[@]}"; do
            if [[ -d "$package" ]]; then
                log_info "Updating $package dotfiles..."
                stow -R -t "$HOME" "$package" || log_warning "Failed to update $package"
            fi
        done
        
        cd "$CONFIG_DIR"
        log_success "Dotfiles updated"
    else
        log_warning "Not in a git repository, skipping dotfiles update"
    fi
}

# Clean system
clean_system() {
    if [[ "$CLEAN_SYSTEM" != "true" ]]; then
        return 0
    fi
    
    log_info "Performing system cleanup..."
    
    local platform
    platform=$(detect_platform)
    
    case "$platform" in
        "macos")
            if command_exists brew; then
                log_info "Cleaning Homebrew cache..."
                brew cleanup
                brew autoremove || true
            fi
            ;;
        "arch"|"cachyos"|"manjaro")
            log_info "Cleaning package cache..."
            sudo pacman -Sc --noconfirm
            
            if command_exists yay; then
                yay -Sc --noconfirm
            fi
            ;;
        "ubuntu"|"debian")
            log_info "Cleaning package cache..."
            sudo apt autoremove -y
            sudo apt autoclean
            ;;
    esac
    
    # Clean common directories
    log_info "Cleaning temporary files..."
    
    # Clean shell history if it's too large
    if [[ -f "$HOME/.zsh_history" ]]; then
        local history_size
        history_size=$(wc -l < "$HOME/.zsh_history")
        if [[ "$history_size" -gt 10000 ]]; then
            log_info "Trimming shell history..."
            tail -5000 "$HOME/.zsh_history" > "$HOME/.zsh_history.tmp"
            mv "$HOME/.zsh_history.tmp" "$HOME/.zsh_history"
        fi
    fi
    
    # Clean old log files
    if [[ -d "$HOME/.local/share/logs" ]]; then
        find "$HOME/.local/share/logs" -type f -mtime +30 -delete 2>/dev/null || true
    fi
    
    # Clean old backup files
    find "$HOME" -name "*.backup" -mtime +7 -type f -delete 2>/dev/null || true
    
    log_success "System cleanup completed"
}

# Update development tools
update_dev_tools() {
    log_info "Updating development tools..."
    
    # Update Neovim plugins if using lazy.nvim or packer
    if [[ -d "$HOME/.config/nvim" ]]; then
        log_info "Updating Neovim configuration..."
        # Copy any new changes to nvim config
        if [[ -d "$CONFIG_DIR/packages/nvim" ]]; then
            cd "$CONFIG_DIR/packages"
            stow -R -t "$HOME" nvim || log_warning "Failed to update nvim config"
        fi
    fi
    
    # Update shell plugins
    log_info "Updating shell configuration..."
    
    # Reload shell configuration
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        source "$HOME/.zshrc" 2>/dev/null || log_warning "Failed to reload zsh config"
    fi
}

# Check for security updates
check_security() {
    log_info "Checking for security considerations..."
    
    # Check SSH key permissions
    if [[ -d "$HOME/.ssh" ]]; then
        find "$HOME/.ssh" -type f -name "id_*" -not -name "*.pub" -exec chmod 600 {} \; 2>/dev/null || true
        find "$HOME/.ssh" -type f -name "*.pub" -exec chmod 644 {} \; 2>/dev/null || true
        chmod 700 "$HOME/.ssh" 2>/dev/null || true
    fi
    
    # Check age keys permissions
    if [[ -f "$HOME/.config/sops/age/keys.txt" ]]; then
        chmod 600 "$HOME/.config/sops/age/keys.txt"
    fi
    
    # Update age and sops if available
    if command_exists age && command_exists sops; then
        log_info "Secrets management tools are up to date"
    else
        log_warning "Consider updating age/sops for security"
    fi
    
    log_success "Security check completed"
}

# Show update summary
show_summary() {
    echo
    log_success "🎉 System update completed!"
    echo
    log_info "What was updated:"
    
    if [[ "$UPDATE_PACKAGES" == "true" ]]; then
        echo "  ✓ System packages"
        echo "  ✓ Language-specific packages"
    fi
    
    if [[ "$UPDATE_DOTFILES" == "true" ]]; then
        echo "  ✓ Dotfiles configuration"
        echo "  ✓ Development tools"
    fi
    
    if [[ "$CLEAN_SYSTEM" == "true" ]]; then
        echo "  ✓ System cleanup"
    fi
    
    echo "  ✓ Security check"
    echo
    
    log_info "Next steps:"
    echo "  • Restart your terminal to apply all changes"
    echo "  • Run './scripts/validate.sh' to verify everything is working"
    echo "  • Review any warnings above"
    echo
}

# Main function
main() {
    echo
    log_info "🔄 Starting system update..."
    echo
    
    update_packages
    echo
    update_dotfiles
    echo
    update_dev_tools
    echo
    clean_system
    echo
    check_security
    
    show_summary
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_args "$@"
    
    if [[ "$VERBOSE" == "true" ]]; then
        set -x
    fi
    
    main "$@"
fi 