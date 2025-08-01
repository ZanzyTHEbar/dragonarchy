#!/usr/bin/env zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd)"

# --- Header and Logging ---
# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# --- Platform and Helper Functions ---
detect_platform() {
    case "$(uname -s)" in
        Linux*)
            [[ -f /etc/os-release ]] && source /etc/os-release
            echo "${ID:-linux}"
            ;;
        *) echo "unknown" ;;
    esac
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
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

# --- Package Definitions ---
cursor_packages_aur=("bibata-cursor-theme")

# --- OS-Specific Installation Functions ---
install_for_arch() {
    log_info "Installing cursor dependencies for Arch..."
    install_paru "${cursor_packages_aur[@]}"
}

# --- Main Function ---
main() {

    # Install dependencies
    log_info "Installing Bibata cursor theme dependencies..."
    
    local platform
    platform=$(detect_platform)

    case "$platform" in
        "arch"|"cachyos"|"manjaro") install_for_arch ;;
        *) log_error "Unsupported platform for cursor installation: $platform" && exit 1 ;;
    esac


    # Set cursor theme
    log_info "Setting Bibata as the default cursor theme..."
    bash "$SCRIPT_DIR/set-cursor.sh"

    log_info "Cursor dependencies installed successfully."
    log_info "Bibata cursor theme setup complete."
}

main "$@"
