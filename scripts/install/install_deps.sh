#!/usr/bin/env sh
#
# File: packages/zsh/.config/zsh/install_deps.zsh
#
# Consolidated package and font installation script.

set -euo pipefail

# Script directory for consistent script referencing
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd)"

# --- Header and Logging ---
# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Package Definitions ---
# Fonts
arch_fonts=("ttf-jetbrains-mono" "noto-fonts-emoji" "ttf-font-awesome" "noto-fonts-extra" "ttf-liberation" ttf-liberation-mono-nerd)
arch_aur_fonts=("ttf-cascadia-mono-nerd" "ttf-ia-writer")
macos_cask_fonts=("font-jetbrains-mono-nerd" "font-symbols-only-nerd-font" "font-caskaydia-mono-nerd-font" "font-iosevka" "font-ia-writer-mono")
debian_fonts=("fonts-jetbrains-mono" "fonts-noto-color-emoji" "fonts-font-awesome" "fonts-liberation2")

# Core CLI
core_cli_arch=("vim" "neovim" "btop" "coreutils" "dua-cli" "duf" "entr" "fastfetch" "fd" "fzf" "gdu" "lsd" "ripgrep" "stow" "unzip" "wget" "jq" "just" "yq" "iperf3" "wakeonlan" "ffmpeg" "bat" "zoxide" "eza" "direnv" "git-delta" "lazygit" "htop" "tmux" "tree" "curl" "rsync" "age" "sops" "zsh" "zsh-autosuggestions" "zsh-syntax-highlighting" "zsh-theme-powerlevel10k" "gum")
core_cli_macos=("vim" "neovim" "btop" "coreutils" "dua-cli" "duf" "entr" "fastfetch" "fd" "fzf" "lsd" "ripgrep" "stow" "wget" "jq" "just" "yq" "iperf3" "wakeonlan" "ffmpeg" "bat" "zoxide" "eza" "direnv" "git-delta" "lazygit" "htop" "tmux" "tree" "curl" "rsync" "age" "sops" "zsh" "zsh-autosuggestions" "zsh-syntax-highlighting" "powerlevel10k")
core_cli_debian=("vim" "neovim" "btop" "coreutils" "fd-find" "fzf" "ripgrep" "stow" "unzip" "wget" "curl" "jq" "iperf3" "wakeonlan" "ffmpeg" "bat-cat" "zsh" "htop" "tmux" "tree" "rsync" "git" "zsh-autosuggestions" "zsh-syntax-highlighting" "kitty")

# GUI Apps
gui_aur=("joplin-desktop" "difftastic" "visual-studio-code-bin" "visual-studio-code-insiders-bin")
gui_cask=("kitty" "vivaldi" "visual-studio-code" "visual-studio-code-insiders" "joplin" "aerospace")

# Development
dev_arch=("go" "git" "diff-so-fancy" "ansible" "github-cli" "terraform" "python-pipx")
dev_macos=("go" "git" "diff-so-fancy" "ansible" "gh" "terraform")
dev_debian=("golang-go" "git" "diff-so-fancy" "ansible" "gh" "terraform" "pipx")
pipx_packages=("poetry" "black" "flake8" "mypy")

# Hyprland specific
hyprland_arch=("bash-completion" "blueberry" "bluez" "bluez-utils" "brightnessctl" "rustup" "clang" "cups" "cups-filters" "cups-pdf" "docker" "docker-buildx" "docker-compose" "nemo" "nemo-emblems" "nemo-fileroller" "nemo-preview" "nemo-seahorse" "nemo-share" "egl-wayland" "evince" "fcitx5" "fcitx5-configtool" "fcitx5-gtk" "fcitx5-qt" "ffmpegthumbnailer" "flatpak" "gcc" "gnome-themes-extra" "hypridle" "hyprland" "hyprlock" "hyprpicker" "hyprshot" "imagemagick" "imv" "inetutils" "iwd" "kitty" "kvantum" "lazygit" "less" "libqalculate" "llvm" "luarocks" "man-db" "mise" "mpv" "pamixer" "pipewire" "plocate" "playerctl" "polkit-gnome" "power-profiles-daemon" "qt5-wayland" "qt6-wayland" "satty" "slurp" "sushi" "swaybg" "swaync" "swayosd" "system-config-printer" "tree-sitter-cli" "tzupdate" "ufw" "uwsm" "waybar" "wf-recorder" "whois" "wireplumber" "wl-clip-persist" "xdg-desktop-portal-gtk" "xdg-desktop-portal-hyprland")
hyprland_aur=("gnome-calculator" "gnome-keyring" "hyprland-qtutils" "impala" "joplin-desktop" "kdenlive" "lazydocker-bin" "libreoffice-fresh" "localsend-bin" "pinta" "spotify" "swaync-widgets-git" "tealdeer" "typora" "ufw-docker-git" "walker-bin" "wiremix" "wl-clipboard" "wl-screenrec-git" "xournalpp" "zoom" "bibata-cursor-theme")

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

# --- Platform and Helper Functions ---
detect_platform() {
    case "$(uname -s)" in
        Darwin*) echo "macos" ;;
        Linux*)
            [[ -f /etc/os-release ]] && source /etc/os-release
            echo "${ID:-linux}"
            ;;
        *) echo "unknown" ;;
    esac
}

# Detect current host
detect_host() {
    local hostname
    hostname=$(hostname | cut -d. -f1)
    
    case "$hostname" in
        dragon|spacedragon|dragonsmoon|goldendragon)
            echo "$hostname"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

command_exists() { 
    command -v "$1" >/dev/null 2>&1 
}

# --- Package Installation Helpers ---
install_pacman() {
    log_info "Installing with pacman: $*"
    local pkgs_to_install=()
    for pkg in "$@"; do
        pacman -Qi "$pkg" &>/dev/null || pkgs_to_install+=("$pkg")
    done
    if [[ ${#pkgs_to_install[@]} -gt 0 ]]; then
        sudo pacman -S --noconfirm --needed "${pkgs_to_install[@]}"
    else
        log_info "All pacman packages already installed."
    fi
}

install_paru() {
    command_exists paru || {
        log_info "AUR helper 'paru' not found, installing..."
        local tmp_dir
        tmp_dir=$(mktemp -d)
        sudo pacman -S --needed --noconfirm git base-devel
        git clone https://aur.archlinux.org/paru.git "$tmp_dir" && (cd "$tmp_dir" && makepkg -si --noconfirm)
        rm -rf "$tmp_dir"
        log_success "'paru' installed."
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

add_chaotic_aur() {
    grep -q "chaotic-aur" /etc/pacman.conf || {
        log_info "Adding Chaotic-AUR repository..."
        sudo pacman-key --recv-key 3056513887B78AEB
        sudo pacman-key --lsign-key 3056513887B78AEB
        sudo pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
        sudo pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
        echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" | sudo tee -a /etc/pacman.conf
        sudo pacman -Sy
        log_success "Chaotic-AUR repository added."
    }
}

install_brew() {
    command_exists brew || {
        log_info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    }
    log_info "Updating Homebrew..." && brew update
    log_info "Installing formulas: $*"
    brew install "$@"
}

install_brew_cask() {
    log_info "Installing casks: $*"
    brew install --cask "$@"
}

install_apt() {
    log_info "Updating apt repositories..." && sudo apt-get update
    log_info "Installing with apt: $*"
    local pkgs_to_install=()
    for pkg in "$@"; do
        dpkg -l | grep -q "^ii  $pkg " || pkgs_to_install+=("$pkg")
    done
    if [[ ${#pkgs_to_install[@]} -gt 0 ]]; then
        sudo apt-get install -y "${pkgs_to_install[@]}"
    else
        log_info "All apt packages already installed."
    fi
}

# --- Application-Specific Installers ---
install_cursor_app() {
    log_info "Installing Cursor..."
    if command -v cursor >/dev/null 2>&1; then
        log_info "Cursor is already installed."
    else
        curl -fsSL https://raw.githubusercontent.com/watzon/cursor-linux-installer/main/install.sh | bash -s -- latest
        log_success "Cursor installed successfully."
    fi
}

# --- Additional Tool Installation (for Debian/source) ---
install_additional_tools() {
    log_info "Installing additional tools from source or binary..."
    local install_dir="$HOME/.local/bin"
    mkdir -p "$install_dir"

    # Go tools
    command_exists go && {
        log_info "Installing Go tools..."
        go install github.com/jesseduffield/lazygit@latest
    }

    # Binaries
    command_exists age || {
        log_info "Installing age binary..."
        local tmp_dir=$(mktemp -d)
        curl -L "https://github.com/FiloSottile/age/releases/latest/download/age-v1.1.1-linux-amd64.tar.gz" | tar -xz -C "$tmp_dir" --strip-components=1
        sudo mv "$tmp_dir/age" /usr/local/bin/
        sudo mv "$tmp_dir/age-keygen" /usr/local/bin/
        rm -rf "$tmp_dir"
    }
    command_exists sops || {
        log_info "Installing sops binary..."
        curl -L "https://github.com/getsops/sops/releases/latest/download/sops-v3.8.1.linux.amd64" -o /tmp/sops
        sudo mv /tmp/sops /usr/local/bin/sops
        sudo chmod +x /usr/local/bin/sops
    }
}

install_rust_tools() {
    if command_exists rustup; then
        log_info "Installing Rust stable toolchain..."
        rustup toolchain install stable
        rustup default stable
    fi
    
    command_exists cargo && {
        log_info "Installing Rust tools..."
        cargo install lsd bat ripgrep zoxide eza dua-cli git-delta
    }
}

# --- OS-Specific Installation Functions ---
install_for_arch() {
    local host="$1"
    local hyprland_hosts=("dragon" "spacedragon" "goldendragon")
    log_info "Updating pacman repositories..." && sudo pacman -Sy
    
    install_pacman "${core_cli_arch[@]}" "${dev_arch[@]}" "${arch_fonts[@]}"
    
    # Install Rust tools before AUR packages
    if [[ " ${hyprland_hosts[@]} " =~ " ${host} " ]]; then
        install_rust_tools
    fi
    
    install_paru "${gui_aur[@]}" "${arch_aur_fonts[@]}"

    if [[ " ${hyprland_hosts[@]} " =~ " ${host} " ]]; then
        log_info "Installing Hyprland specific packages for Arch..."
        add_chaotic_aur
        install_pacman "${hyprland_arch[@]}"
        install_paru "${hyprland_aur[@]}"
        install_cursor_app
    fi
}

install_for_macos() {
    install_brew "${core_cli_macos[@]}" "${dev_macos[@]}"
    brew tap homebrew/cask-fonts
    install_brew_cask "${macos_cask_fonts[@]}" "${gui_cask[@]}"
}

install_for_debian() {
    install_apt "${core_cli_debian[@]}" "${dev_debian[@]}" "${debian_fonts[@]}"
    install_additional_tools
}

# --- Post-Install Setup ---
setup_development_environments() {
    log_info "Setting up development environments..."
    
    # Node.js via fnm
    command_exists node || {
        log_info "Installing Node.js via fnm..."
        command_exists fnm || curl -fsSL https://fnm.vercel.app/install | bash
        export PATH="$HOME/.local/share/fnm:$PATH"
        eval "$(fnm env)"
        fnm install --lts
        fnm use lts-latest
    }
    
    # Python tools via pipx
    if command_exists pipx; then
        log_info "Installing Python tools via pipx..."
        for pkg in "${pipx_packages[@]}"; do
            if pipx list --json | jq -e ".venvs.\"$pkg\"" >/dev/null; then
                # Check if the package is installed, and the current version is the latest
                if pipx list --json | jq -e ".venvs.\"$pkg\".metadata.version" | grep -q "$(pipx list --json | jq -e ".venvs.\"$pkg\".metadata.version")"; then
                    log_info "$pkg is already up to date."
                else
                    log_info "Upgrading $pkg..."
                    pipx upgrade "$pkg" || true
                fi
            else
                log_info "Installing $pkg..."
                pipx install "$pkg"
            fi
        done
    fi

    # Ruby tools
    if command_exists gem; then
        log_info "Installing Ruby bundler..."
        gem install bundler
    fi
}

finalize_setup() {
    local platform=$(detect_platform)
    log_info "Finalizing setup..."

    # Refresh font cache on Linux
    if [[ "$platform" != "macos" ]] && command_exists fc-cache; then
        log_info "Updating font cache..."
        fc-cache -fv
    fi

    # Change default shell to zsh
    if [[ "$SHELL" != */zsh ]] && command_exists zsh; then
        log_info "Changing default shell to zsh..."
        if sudo chsh -s "$(which zsh)" "$USER"; then
            log_success "Default shell changed to zsh. Please log out and back in."
        else
            log_error "Failed to change default shell."
        fi
    fi

    log_info "Running setup scripts..."
    bash "$SCRIPT_DIR/setup.sh"
}

# --- Main Function ---
main() {
    local platform
    platform=$(detect_platform)
    local host=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --host)
                if [[ -n "$2" ]]; then
                    host="$2"
                    shift 2
                else
                    log_error "Missing host argument for --host"
                    log_info "Available hosts: $(detect_host)"
                    log_info "Usage: $0 --host <host>"
                    exit 1
                fi
                ;;
            *)
                # Ignore unknown arguments
                shift
                ;;
        esac
    done

    log_info "Starting package installation on $platform (Host: ${host:-generic})..."

    case "$platform" in
        "arch"|"cachyos"|"manjaro") install_for_arch "$host" ;;
        "macos") install_for_macos ;;
        "ubuntu"|"debian") install_for_debian ;;
        *) log_error "Unsupported platform: $platform" && exit 1 ;;
    esac
    
    setup_development_environments
    finalize_setup

    log_success "Package and font installation completed!"
}

# Run main function
main "$@"
