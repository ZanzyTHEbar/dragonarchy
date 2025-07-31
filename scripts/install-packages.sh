#!/usr/bin/env bash

# Package Installation Script
# Replaces Nix package management with platform-specific package managers

set -euo pipefail

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

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
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

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install packages for CachyOS/Arch Linux
install_arch_packages() {
    log_info "Installing packages for Arch Linux/CachyOS..."
    
    # Core packages from common-packages.nix
    local packages=(
        # Text Editors & Development Tools
        "vim"
        "neovim"
        "nixpkgs-fmt"
        
        # CLI Utilities & System Tools
        "btop"
        "coreutils"
        "dua-cli"      # dua
        "duf"
        "entr"
        "fastfetch"
        "fd"
        "fzf"
        "gdu"
        "lsd"
        "ripgrep"
        "stow"
        "unzip"
        "wget"
        
        # Development & DevOps
        "ansible"
        "github-cli"   # gh
        "go"
        "jq"
        "just"
        "yq"
        "terraform"
        
        # Network & System Utilities
        "iperf3"
        "wakeonlan"
        
        # Media & Processing
        "ffmpeg"
        
        # GUI Applications
        "kitty"
        "vivaldi"
        
        # Additional CLI tools
        "bat"
        "zoxide"
        "eza"
        "direnv"
        "git-delta"     # Better git diff
        "lazygit"
        "htop"
        "tmux"
        "tree"
        "curl"
        "rsync"
        "age"
        "sops"
        
        # ZSH and plugins
        "zsh"
        "zsh-autosuggestions"
        "zsh-syntax-highlighting"
        "zsh-theme-powerlevel10k"
        
        # Fonts
        "ttf-jetbrains-mono"
        "ttf-nerd-fonts-symbols"
        "noto-fonts-emoji"
    )
    
    # Update package database
    log_info "Updating package database..."
    sudo pacman -Sy
    
    # Install packages
    for package in "${packages[@]}"; do
        if pacman -Qi "$package" &>/dev/null; then
            log_info "Package $package is already installed"
        else
            log_info "Installing $package..."
            if sudo pacman -S --noconfirm "$package"; then
                log_success "Installed $package"
            else
                log_warning "Failed to install $package (might not be available in official repos)"
            fi
        fi
    done
    
    # Install AUR packages with yay if available
    if command_exists yay; then
        log_info "Installing AUR packages..."
        local aur_packages=(
            "code-insiders"
            "visual-studio-code-bin"
            "aerospace"
            "joplin-desktop"
            "difftastic"    # Modern diff tool
        )
        
        for package in "${aur_packages[@]}"; do
            if yay -Qi "$package" &>/dev/null; then
                log_info "AUR package $package is already installed"
            else
                log_info "Installing AUR package $package..."
                if yay -S --noconfirm "$package"; then
                    log_success "Installed AUR package $package"
                else
                    log_warning "Failed to install AUR package $package"
                fi
            fi
        done
    else
        log_warning "yay not found, skipping AUR packages"
        log_info "Install yay manually: https://github.com/Jguer/yay"
    fi
}

# Install packages for Hyprland on Arch Linux
install_hyprland_packages() {
    log_info "Installing packages for Hyprland on Arch Linux..."
    
    # Ensure yay is installed
    if ! command_exists yay; then
        log_info "yay not found, installing..."
        sudo pacman -S --needed --noconfirm git base-devel
        git clone https://aur.archlinux.org/yay.git /tmp/yay
        (cd /tmp/yay && makepkg -si --noconfirm)
        rm -rf /tmp/yay
    fi
    
    # Add Chaotic-AUR if not already present
    if ! grep -q "chaotic-aur" /etc/pacman.conf; then
        log_info "Adding Chaotic-AUR repository..."
        sudo pacman-key --recv-key 3056513887B78AEB
        sudo pacman-key --lsign-key 3056513887B78AEB
        sudo pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
        sudo pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
        echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" | sudo tee -a /etc/pacman.conf
        sudo pacman -Sy
    fi
    
    # Hyprland specific packages
    local packages=(
        # Hyprland core
        "hyprland"
        "hyprshot"
        "hyprpicker"
        "hyprlock"
        "hypridle"
        "polkit-gnome"
        "hyprland-qtutils"
        "walker-bin"
        "libqalculate"
        "waybar"
        "mako"
        "swaybg"
        "swayosd"
        "xdg-desktop-portal-hyprland"
        "xdg-desktop-portal-gtk"
        "uwsm"
        "plymouth"
        
        # Display and audio
        "brightnessctl"
        "playerctl"
        "pamixer"
        "wiremix"
        "wireplumber"
        
        # Input and language
        "fcitx5"
        "fcitx5-gtk"
        "fcitx5-qt"
        "wl-clip-persist"
        
        # File management and media
        "nautilus"
        "sushi"
        "ffmpegthumbnailer"
        "slurp"
        "satty"
        "mpv"
        "evince"
        "imv"
        "chromium"
        
        # Fonts
        "ttf-font-awesome"
        "ttf-cascadia-mono-nerd"
        "ttf-ia-writer"
        "noto-fonts"
        "noto-fonts-emoji"
        "ttf-jetbrains-mono"
        "noto-fonts-cjk"
        "noto-fonts-extra"
        "gnome-themes-extra"
        "kvantum-qt5"
        
        # Development
        "cargo"
        "clang"
        "llvm"
        "mise"
        "imagemagick"
        "mariadb-libs"
        "postgresql-libs"
        "github-cli"
        "lazygit"
        "lazydocker-bin"
        "docker"
        "docker-compose"
        "docker-buildx"
        "luarocks"
        "tree-sitter-cli"
        "gcc14"
        
        # CLI tools
        "wget"
        "curl"
        "unzip"
        "inetutils"
        "impala"
        "fd"
        "eza"
        "fzf"
        "ripgrep"
        "zoxide"
        "bat"
        "jq"
        "wl-clipboard"
        "fastfetch"
        "btop"
        "man"
        "tealdear"
        "less"
        "whois"
        "plocate"
        "bash-completion"
        "kitty"
        "zsh"
        "lsd"
        "iwd"
        "power-profiles-daemon"
        "tzupdate"
        "bluez"
        "bluez-utils"
        "blueberry"
        "cups"
        "cups-pdf"
        "cups-filters"
        "system-config-printer"
        "ufw"
        "ufw-docker"
        "nvidia-dkms"
        "nvidia-utils"
        "lib32-nvidia-utils"
        "egl-wayland"
        "libva-nvidia-driver"
        "qt5-wayland"
        "qt6-wayland"
    )
    
    local aur_packages=(
        "gnome-calculator"
        "gnome-keyring"
        "signal-desktop"
        "obsidian-bin"
        "libreoffice"
        "obs-studio"
        "kdenlive"
        "xournalpp"
        "localsend-bin"
        "pinta"
        "typora"
        "spotify"
        "zoom"
        "1password-beta"
        "1password-cli"
    )
    
    log_info "Installing official packages for Hyprland..."
    for package in "${packages[@]}"; do
        if pacman -Qi "$package" &>/dev/null; then
            log_info "Package $package is already installed"
        else
            log_info "Installing $package..."
            if sudo pacman -S --noconfirm --needed "$package"; then
                log_success "Installed $package"
            else
                log_warning "Failed to install $package"
            fi
        fi
    done
    
    log_info "Installing AUR packages for Hyprland..."
    for package in "${aur_packages[@]}"; do
        if yay -Qi "$package" &>/dev/null; then
            log_info "AUR package $package is already installed"
        else
            log_info "Installing AUR package $package..."
            if yay -S --noconfirm --needed "$package"; then
                log_success "Installed AUR package $package"
            else
                log_warning "Failed to install AUR package $package"
            fi
        fi
    done
}


# Install packages for macOS
install_macos_packages() {
    log_info "Installing packages for macOS..."
    
    # Check if Homebrew is installed
    if ! command_exists brew; then
        log_info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Add Homebrew to PATH
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
    
    # Core packages
    local packages=(
        # Text Editors & Development Tools
        "vim"
        "neovim"
        
        # CLI Utilities & System Tools
        "btop"
        "coreutils"
        "dua-cli"
        "duf"
        "entr"
        "fastfetch"
        "fd"
        "fzf"
        "lsd"
        "ripgrep"
        "stow"
        "wget"
        
        # Development & DevOps
        "ansible"
        "gh"
        "go"
        "jq"
        "just"
        "yq"
        "terraform"
        
        # Network & System Utilities
        "iperf3"
        "wakeonlan"
        
        # Media & Processing
        "ffmpeg"
        
        # Additional CLI tools
        "bat"
        "zoxide"
        "eza"
        "direnv"
        "git-delta"
        "lazygit"
        "htop"
        "tmux"
        "tree"
        "curl"
        "rsync"
        "age"
        "sops"
        
        # ZSH and plugins
        "zsh"
        "zsh-autosuggestions"
        "zsh-syntax-highlighting"
        "powerlevel10k"
        
        # Fonts
        "font-jetbrains-mono"
        "font-symbols-only-nerd-font"
    )
    
    # Update Homebrew
    log_info "Updating Homebrew..."
    brew update
    
    # Install packages
    for package in "${packages[@]}"; do
        if brew list "$package" &>/dev/null; then
            log_info "Package $package is already installed"
        else
            log_info "Installing $package..."
            if brew install "$package"; then
                log_success "Installed $package"
            else
                log_warning "Failed to install $package"
            fi
        fi
    done
    
    # Install cask applications
    local casks=(
        "kitty"
        "vivaldi"
        "visual-studio-code-insiders"
        "joplin"
        "aerospace"
    )
    
    log_info "Installing GUI applications..."
    for cask in "${casks[@]}"; do
        if brew list --cask "$cask" &>/dev/null; then
            log_info "Cask $cask is already installed"
        else
            log_info "Installing cask $cask..."
            if brew install --cask "$cask"; then
                log_success "Installed cask $cask"
            else
                log_warning "Failed to install cask $cask"
            fi
        fi
    done
}

# Install packages for Ubuntu/Debian
install_debian_packages() {
    log_info "Installing packages for Ubuntu/Debian..."
    
    # Update package database
    sudo apt update
    
    # Install basic packages available in repositories
    local packages=(
        "vim"
        "neovim"
        "btop"
        "coreutils"
        "fd-find"
        "fzf"
        "ripgrep"
        "stow"
        "unzip"
        "wget"
        "curl"
        "ansible"
        "jq"
        "iperf3"
        "wakeonlan"
        "ffmpeg"
        "bat"
        "zsh"
        "htop"
        "tmux"
        "tree"
        "rsync"
        "git"
        "kitty"
        "zsh-autosuggestions"
        "zsh-syntax-highlighting"
        "fonts-jetbrains-mono"
    )
    
    for package in "${packages[@]}"; do
        if dpkg -l | grep -q "^ii  $package "; then
            log_info "Package $package is already installed"
        else
            log_info "Installing $package..."
            if sudo apt install -y "$package"; then
                log_success "Installed $package"
            else
                log_warning "Failed to install $package"
            fi
        fi
    done
    
    # Install additional tools not in repositories
    install_additional_tools
}

# Install additional tools not available in standard repositories
install_additional_tools() {
    log_info "Installing additional tools..."
    
    local install_dir="$HOME/.local/bin"
    mkdir -p "$install_dir"
    
    # Install Go tools
    if command_exists go; then
        log_info "Installing Go tools..."
        go install github.com/junegunn/fzf@latest
        go install github.com/jesseduffield/lazygit@latest
    fi
    
    # Install Rust tools if cargo is available
    if command_exists cargo; then
        log_info "Installing Rust tools..."
        cargo install lsd
        cargo install bat
        cargo install ripgrep
        cargo install zoxide
        cargo install eza
        cargo install dua-cli
        cargo install git-delta
    fi
    
    # Install age/sops for secrets management
    if ! command_exists age; then
        log_info "Installing age..."
        if [[ "$(uname -m)" == "x86_64" ]]; then
            curl -L "https://github.com/FiloSottile/age/releases/latest/download/age-$(uname -s | tr '[:upper:]' '[:lower:]')-amd64.tar.gz" | tar -xz -C /tmp
            sudo mv /tmp/age/age /usr/local/bin/
            sudo mv /tmp/age/age-keygen /usr/local/bin/
        fi
    fi
    
    if ! command_exists sops; then
        log_info "Installing sops..."
        if [[ "$(uname -m)" == "x86_64" ]]; then
            curl -L "https://github.com/mozilla/sops/releases/latest/download/sops-$(uname -s | tr '[:upper:]' '[:lower:]').amd64" -o /tmp/sops
            chmod +x /tmp/sops
            sudo mv /tmp/sops /usr/local/bin/
        fi
    fi
}

# Set up development environments
setup_development_environments() {
    log_info "Setting up development environments..."
    
    # Install Node.js via fnm if not present
    if ! command_exists node; then
        log_info "Installing Node.js via fnm..."
        if ! command_exists fnm; then
            curl -fsSL https://fnm.vercel.app/install | bash
            export PATH="$HOME/.fnm:$PATH"
            eval "$(fnm env)"
        fi
        fnm install --lts
        fnm use lts-latest
    fi
    
    # Install Python development tools
    if command_exists python3; then
        log_info "Installing Python development tools..."
        
        # Ensure pipx is installed
        if ! command_exists pipx; then
            log_info "Installing pipx..."
            
            sudo pacman -S python-pipx
            
            # Ensure pip is installed
            #if ! command_exists pip; then
            #    log_info "Installing pip..."
            #    python3 -m ensurepip --upgrade
            #fi
            
            export PATH="$HOME/.local/bin:$PATH"
            python3 -m pipx ensurepath
        fi
        
        # Upgrade pip and install pipx if not already installed
        #log_info "Upgrading pip and installing pipx..."
        #
        #python3 -m pip install --user --upgrade pip
        #python3 -m pip install --user pipx
        
        # Install Python tools via pipx
        if command_exists pipx; then
            pipx install ansible
            pipx install poetry
            pipx install black
            pipx install flake8
            pipx install mypy
        fi
    fi
    
    # Install Ruby development tools
    if command_exists ruby && command_exists gem; then
        log_info "Installing Ruby development tools..."
        gem install bundler
    fi
}

# Main installation function
main() {
    log_info "Starting package installation..."
    
    local platform
    platform=$(detect_platform)
    local host="$1"
    
    log_info "Detected platform: $platform"
    
    if [[ "$host" == "hyprland" && "$platform" == "arch" ]]; then
        install_hyprland_packages
    else
        case "$platform" in
            "macos")
                install_macos_packages
            ;;
            "arch"|"cachyos"|"manjaro")
                install_arch_packages
            ;;
            "ubuntu"|"debian")
                install_debian_packages
            ;;
            *)
                log_error "Unsupported platform: $platform"
                log_info "Trying to install additional tools..."
                install_additional_tools
            ;;
        esac
    fi
    
    # Set up development environments
    setup_development_environments
    
    # Change default shell to zsh if not already
    if [[ "$SHELL" != */zsh ]]; then
        log_info "Changing default shell to zsh..."
        if command_exists zsh; then
            sudo chsh -s "$(which zsh)" "$USER"
            log_success "Default shell changed to zsh"
        else
            log_warning "zsh not found, cannot change default shell"
        fi
    fi
    
    log_success "Package installation completed!"
    log_info "You may need to log out and back in for all changes to take effect"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi