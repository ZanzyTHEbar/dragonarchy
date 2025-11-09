#!/usr/bin/env bash

set -euo pipefail

# Get script directory and source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091  # Runtime-resolved path to logging library
source "${SCRIPT_DIR}/../../../lib/logging.sh"

# Logging functions
detect_platform() {
    case "$(uname -s)" in
        Linux*)
            [[ -f /etc/os-release ]] && source /etc/os-release
            echo "${ID:-linux}"
            ;;
        *) echo "unknown" ;;
    esac
}

install_paru() {
    command_exists paru || {
        log_info "AUR helper 'paru' not found, installing..."
        local tmp_dir
        tmp_dir=$(mktemp -d)
        sudo pacman -S --needed --noconfirm git base-devel
        git clone https://aur.archlinux.org/paru.git "$tmp_dir" && (cd "$tmp_dir" && makepkg -si --noconfirm)
        rm -rf "$tmp_dir"
    }
    log_info "Installing with paru: $*"
    local pkgs_to_install=()
    for pkg in "$@"; do
        paru -Qi "$pkg" &>/dev/null || pkgs_to_install+=("$pkg")
    done
    if [[ ${#pkgs_to_install[@]} -gt 0 ]]; then
        paru -S --noconfirm --needed --removemake --sudoloop "${pkgs_to_install[@]}"
    else
        log_info "All AUR packages already installed."
    fi
}

# --- Symlink Creation ---
create_user_symlinks() {
    log_info "Creating symlinks to user icons directory..."
    
    local user_icons_dir="$HOME/.local/share/icons"
    local system_icons_dir="/usr/share/icons"
    
    mkdir -p "$user_icons_dir"
    
    # Symlink all Bibata variants from system to user directory
    for bibata_theme in "$system_icons_dir"/Bibata-*; do
        if [[ -d "$bibata_theme" ]]; then
            local theme_name=$(basename "$bibata_theme")
            local target="$user_icons_dir/$theme_name"
            
            if [[ -L "$target" ]]; then
                log_info "Symlink already exists: $theme_name"
            elif [[ -d "$target" ]]; then
                log_info "Directory exists (not a symlink): $theme_name - removing..."
                rm -rf "$target"
                ln -sf "$bibata_theme" "$target"
                log_success "Replaced directory with symlink: $theme_name"
            else
                ln -sf "$bibata_theme" "$target"
                log_success "Created symlink: $theme_name"
            fi
        fi
    done
}

# --- Package Definitions ---
cursor_packages_aur=("bibata-cursor-theme")

# --- OS-Specific Installation Functions ---
install_for_arch() {
    log_info "Installing cursor dependencies for Arch..."
    install_paru "${cursor_packages_aur[@]}"
}

# --- Main Function ---
main() {
    log_info "Installing Bibata cursor theme (all 12 variants)..."
    
    local platform
    platform=$(detect_platform)

    case "$platform" in
        "arch"|"cachyos"|"manjaro") install_for_arch ;;
        *) log_error "Unsupported platform for cursor installation: $platform" && exit 1 ;;
    esac

    # Create symlinks so theme manager can access the themes
    create_user_symlinks

    log_success "Bibata cursor theme installation complete!"
    log_info "Available variants:"
    log_info "  • Bibata-Modern-Classic (default)"
    log_info "  • Bibata-Modern-Ice (blue accent)"
    log_info "  • Bibata-Modern-Amber (orange accent)"
    log_info "  • Bibata-Original-Classic/Ice/Amber (sharper style)"
    log_info "  • All variants available in Right-handed versions"
    log_info ""
    log_info "Use the cursor-menu to select your preferred variant."
}

main "$@"
