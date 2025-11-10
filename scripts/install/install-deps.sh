#!/usr/bin/env bash

set -euo pipefail

# Get script directory and source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091  # Runtime-resolved path to logging library
source "${SCRIPT_DIR}/../lib/logging.sh"

# Script directory for consistent script referencing
# CONFIG_DIR is two levels above SCRIPT_DIR.
# Expected structure:
#   repo_root/
#     config/         <-- CONFIG_DIR
#       hosts/        <-- HOSTS_DIR
#     scripts/
#       install/
#         install-deps.sh  <-- SCRIPT_DIR
CONFIG_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
HOSTS_DIR="$CONFIG_DIR/hosts"

# Feature toggles (defaults)
FORCE_CURSOR_INSTALL=false
SKIP_CURSOR_INSTALL=false

# --- Header and Logging ---
# Colors for output

# --- Package Definitions ---
# Fonts
arch_fonts=("ttf-jetbrains-mono" "noto-fonts-emoji" "ttf-font-awesome" "noto-fonts-extra" "ttf-liberation" ttf-liberation-mono-nerd)
arch_aur_fonts=("ttf-cascadia-mono-nerd" "ttf-ia-writer")
debian_fonts=("fonts-jetbrains-mono" "fonts-noto-color-emoji" "fonts-font-awesome" "fonts-liberation2")

# Core CLI
core_cli_arch=("vim" "kitty" "neovim" "btop" "coreutils" "dua-cli" "duf" "entr" "fastfetch" "fd" "fzf" "gdu" "lsd" "ripgrep" "stow" "unzip" "wget" "jq" "just" "yq" "iperf3" "wakeonlan" "ffmpeg" "bat" "zoxide" "eza" "direnv" "git-delta" "lazygit" "htop" "tmux" "tree" "curl" "rsync" "age" "sops" "zsh" "zsh-autosuggestions" "zsh-syntax-highlighting" "zsh-theme-powerlevel10k" "gum")
core_cli_debian=("vim" "neovim" "btop" "coreutils" "fd-find" "fzf" "ripgrep" "stow" "unzip" "wget" "curl" "jq" "iperf3" "wakeonlan" "ffmpeg" "bat-cat" "zsh" "htop" "tmux" "tree" "rsync" "git" "zsh-autosuggestions" "zsh-syntax-highlighting" "kitty")

# GUI
gui_aur=("joplin-desktop" "vivaldi" "difftastic" "visual-studio-code-bin" "visual-studio-code-insiders-bin")
gui_cask=("kitty" "vivaldi" "visual-studio-code" "visual-studio-code-insiders" "joplin" "aerospace")

# Development
dev_arch=("git" "diff-so-fancy" "ansible" "github-cli" "terraform" "python-pipx")
dev_debian=("git" "diff-so-fancy" "ansible" "gh" "terraform" "pipx")
pipx_packages=("poetry" "black" "flake8" "mypy")

# Hyprland specific
# NOTE: Core Hyprland packages (hyprland, hypridle, hyprlock) are handled separately
# to avoid conflicts with -git versions on CachyOS
hyprland_arch_base=("bash-completion" "blueberry" "bluez" "bluez-utils" "brightnessctl" "rustup" "clang" "cups" "cups-filters" "cups-pdf" "docker" "docker-buildx" "docker-compose" "nemo" "nemo-emblems" "nemo-fileroller" "nemo-preview" "nemo-seahorse" "nemo-share" "egl-wayland" "evince" "fcitx5" "fcitx5-configtool" "fcitx5-gtk" "fcitx5-qt" "ffmpegthumbnailer" "flatpak" "gcc" "gnome-themes-extra" "imagemagick" "imv" "inetutils" "iwd" "kvantum" "lazygit" "less" "libqalculate" "libsecret" "llvm" "luarocks" "man-db" "mise" "mpv" "pamixer" "pipewire" "plocate" "playerctl" "polkit-gnome" "power-profiles-daemon" "qt6-svg" "qt6-declarative" "qt5-quickcontrols2" "qt5-graphicaleffects" "qt6-5compat" "qt6-wayland" "qt5-wayland" "satty" "slurp" "sushi" "swaybg" "swaync" "swayosd" "system-config-printer" "tree-sitter-cli" "ufw" "uwsm" "waybar" "wf-recorder" "whois" "wireplumber" "wl-clip-persist" "xdg-desktop-portal-gtk" "xdg-desktop-portal-hyprland")
# Core Hyprland packages that may conflict with -git versions
hyprland_arch_core=("hypridle" "hyprland" "hyprlock" "hyprpicker" "hyprshot")
hyprland_aur=("gnome-calculator" "gnome-keyring" "hyprland-qtutils" "impala" "joplin-desktop" "kdenlive" "lazydocker-bin" "libreoffice-fresh" "localsend-bin" "pinta" "spotify" "swaync-widgets-git" "tealdeer" "typora" "ufw-docker-git" "walker-bin" "wiremix" "wl-clipboard" "wl-screenrec-git" "xournalpp" "zoom" "bibata-cursor-theme" "tzupdate" "clipse")
# Elephant packages - base must be installed first to satisfy plugin dependencies
hyprland_aur_elephant=("elephant-bin" "elephant-desktopapplications-bin" "elephant-files-bin" "elephant-runner-bin" "elephant-clipboard-bin" "elephant-providerlist-bin")

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

# Detect if a host needs Hyprland packages
# Checks for multiple indicators in the host directory:
# 1. Presence of .hyprland marker file
# 2. Presence of HYPRLAND marker file
# 3. Hyprland mentioned in setup.sh
# 4. Hyprland config directories
is_hyprland_host() {
    local hostname="$1"
    local host_dir="$HOSTS_DIR/$hostname"
    
    # Host directory must exist
    [[ ! -d "$host_dir" ]] && return 1
    
    # Method 1: Check for explicit marker files
    if [[ -f "$host_dir/.hyprland" ]] || [[ -f "$host_dir/HYPRLAND" ]]; then
        log_info "Host '$hostname' detected as Hyprland (marker file found)"
        return 0
    fi
    
    # Method 2: Check if setup.sh mentions Hyprland
    if [[ -f "$host_dir/setup.sh" ]]; then
        if grep -qi "hyprland\|hyprlock\|hypridle\|waybar" "$host_dir/setup.sh"; then
            log_info "Host '$hostname' detected as Hyprland (setup.sh mentions Hyprland)"
            return 0
        fi
    fi
    
    # Method 3: Check for Hyprland config directories in docs
    if [[ -d "$host_dir/docs" ]]; then
        if find "$host_dir/docs" -type f -name "*.md" -exec grep -qi "hyprland" {} \; 2>/dev/null; then
            log_info "Host '$hostname' detected as Hyprland (documentation mentions Hyprland)"
            return 0
        fi
    fi
    
    # Not a Hyprland host
    return 1
}

# Detect if system has -git versions of Hyprland packages installed
# Returns 0 if -git versions are found, 1 otherwise
has_hyprland_git_packages() {
    local git_packages=("hyprland-git" "hypridle-git" "hyprlock-git" "hyprutils-git" "hyprlang-git" "hyprcursor-git")
    
    for pkg in "${git_packages[@]}"; do
        if pacman -Qi "$pkg" &>/dev/null; then
            log_info "Detected -git package: $pkg"
            return 0
        fi
    done
    
    return 1
}

# Check if specific package (stable or -git) is installed
is_package_installed() {
    local pkg="$1"
    pacman -Qi "$pkg" &>/dev/null || paru -Qi "$pkg" &>/dev/null
}

# Get list of all Hyprland hosts by scanning host directories
get_hyprland_hosts() {
    local hyprland_hosts=()
    
    if [[ ! -d "$HOSTS_DIR" ]]; then
        echo "${hyprland_hosts[@]}"
        return
    fi
    
    # Scan all host directories
    while IFS= read -r host; do
        if is_hyprland_host "$host"; then
            hyprland_hosts+=("$host")
        fi
    done < <(get_available_hosts)
    
    echo "${hyprland_hosts[@]}"
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
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>~/.zprofile
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

# --- Go Installation ---
get_latest_go_version() {
    log_info "Checking latest Go version from go.dev..." >&2
    local latest_version
    latest_version=$(curl -s https://go.dev/VERSION?m=text | head -n1)
    
    if [[ -z "$latest_version" ]]; then
        log_error "Failed to fetch latest Go version" >&2
        return 1
    fi
    
    # Remove 'go' prefix if present
    latest_version=${latest_version#go}
    echo "$latest_version"
}

# Compare two version strings (e.g., "1.25.3" vs "1.24.5")
# Returns 0 if version1 < version2, 1 if version1 >= version2
version_less_than() {
    local version1="$1"
    local version2="$2"
    
    # Use sort -V for version comparison
    # If version1 < version2, version1 will be first in sorted order
    if [[ "$(printf '%s\n' "$version1" "$version2" | sort -V | head -n1)" == "$version1" ]] && [[ "$version1" != "$version2" ]]; then
        return 0  # version1 < version2
    else
        return 1  # version1 >= version2
    fi
}

install_go_from_source() {
    local platform="$1"
    local latest_version
    
    # Get latest Go version
    local version_output
    if ! version_output=$(get_latest_go_version 2>/dev/null) || [[ -z "$version_output" ]]; then
        log_error "Failed to get latest Go version, falling back to package manager installation"
        return 1
    fi
    latest_version="$version_output"
    
    log_info "Latest Go version available: $latest_version"
    
    # Check if Go is already installed and compare versions
    if command_exists go; then
        local current_version
        current_version=$(go version | grep -oP 'go\d+\.\d+(?:\.\d+)?' | sed 's/go//')
        log_info "Found existing Go installation (version: $current_version)"
        
        # Compare versions - only upgrade if current version is less than latest
        if version_less_than "$current_version" "$latest_version"; then
            log_info "Current version ($current_version) is older than latest ($latest_version). Upgrading..."
        else
            log_info "Go is already at the latest version ($current_version). Skipping installation."
            return 0
        fi
        
        # Remove existing installation
        if [[ -d "/usr/local/go" ]]; then
            log_info "Removing existing Go installation from /usr/local/go..."
            sudo rm -rf /usr/local/go
        fi
        
        # Also remove package manager installed Go if it exists
        case "$platform" in
            "arch" | "cachyos" | "manjaro")
                if pacman -Qi go &>/dev/null; then
                    log_info "Removing Go from pacman..."
                    sudo pacman -Rns --noconfirm go
                fi
            ;;
            "ubuntu" | "debian")
                if dpkg -l | grep -q "^ii.*golang-go"; then
                    log_info "Removing golang-go from apt..."
                    sudo apt-get remove --purge -y golang-go
                fi
            ;;
        esac
    fi
    
    # Determine OS and architecture
    local os_type arch filename download_url
    case "$(uname -s)" in
        Linux*) os_type="linux" ;;
        Darwin*) os_type="darwin" ;;
        *)
            log_error "Unsupported OS: $(uname -s)"
            return 1
        ;;
    esac
    
    case "$(uname -m)" in
        x86_64) arch="amd64" ;;
        aarch64) arch="arm64" ;;
        arm64) arch="arm64" ;;
        *)
            log_error "Unsupported architecture: $(uname -m)"
            return 1
        ;;
    esac
    
    filename="go${latest_version}.${os_type}-${arch}.tar.gz"
    download_url="https://go.dev/dl/${filename}"
    
    log_info "Downloading Go $latest_version for ${os_type}-${arch}..."
    
    # Try wget first, fallback to curl
    if command_exists wget; then
        if ! wget -q "$download_url" -O "/tmp/${filename}"; then
            log_error "Failed to download Go from $download_url using wget"
            return 1
        fi
        elif command_exists curl; then
        if ! curl -sL "$download_url" -o "/tmp/${filename}"; then
            log_error "Failed to download Go from $download_url using curl"
            return 1
        fi
    else
        log_error "Neither wget nor curl is available for downloading"
        return 1
    fi
    
    log_info "Extracting Go to /usr/local..."
    if ! sudo tar -C /usr/local -xzf "/tmp/${filename}"; then
        log_error "Failed to extract Go archive"
        rm -f "/tmp/${filename}"
        return 1
    fi
    
    # Clean up
    rm -f "/tmp/${filename}"
    
    # Verify installation
    if command_exists /usr/local/go/bin/go; then
        local installed_version
        installed_version=$(/usr/local/go/bin/go version | grep -oP 'go\d+\.\d+(?:\.\d+)?' | sed 's/go//')
        log_success "Go $installed_version installed successfully!"
        log_info "Go binary location: /usr/local/go/bin/go"
        return 0
    else
        log_error "Go installation verification failed"
        return 1
    fi
}

# --- Application-Specific Installers ---
install_cursor_app() {
    log_info "Installing Cursor..."
    command_exists cursor && {
        log_info "Cursor is already installed."
        return 0
    }
    
    log_info "Installing Cursor..."
    local tmp_dir
    tmp_dir=$(mktemp -d)
    git clone https://github.com/ZanzyTHEBar/cursor-linux-installer.git "$tmp_dir"
    (cd "$tmp_dir" && ./install.sh)
    rm -rf "$tmp_dir"
    log_success "Cursor installed successfully."
    return 0
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
        local tmp_dir
        tmp_dir=$(mktemp -d)
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
    
    log_info "Updating pacman repositories..." && sudo pacman -Sy
    
    install_pacman "${core_cli_arch[@]}" "${dev_arch[@]}" "${arch_fonts[@]}"
    install_paru "${gui_aur[@]}" "${arch_aur_fonts[@]}"
    
    # Install Go from source (latest version)
    if ! install_go_from_source "arch"; then
        log_error "Failed to install Go from source, skipping Go installation"
        return 1
    fi
    
    # Automatically detect if this host needs Hyprland packages
    if is_hyprland_host "$host"; then
        log_info "Installing Hyprland specific packages for host: $host"
        add_chaotic_aur
        
        # Filter out power-profiles-daemon if TLP is installed (they conflict)
        local filtered_hyprland_base=()
        for pkg in "${hyprland_arch_base[@]}"; do
            if [[ "$pkg" == "power-profiles-daemon" ]] && command -v tlp &>/dev/null; then
                log_info "Skipping power-profiles-daemon (TLP is installed)"
                continue
            fi
            filtered_hyprland_base+=("$pkg")
        done
        
        # Install base Hyprland packages (non-conflicting)
        install_pacman "${filtered_hyprland_base[@]}"
        
        # Handle core Hyprland packages - check for -git conflicts
        if has_hyprland_git_packages; then
            log_warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            log_warning "Detected -git versions of Hyprland packages installed!"
            log_warning "Skipping installation of stable Hyprland core packages to avoid conflicts."
            log_warning ""
            log_warning "Installed -git packages will be kept:"
            for pkg in "hyprland-git" "hypridle-git" "hyprlock-git" "hyprutils-git" "hyprlang-git" "hyprcursor-git"; do
                if is_package_installed "$pkg"; then
                    log_warning "  ✓ $pkg"
                fi
            done
            log_warning ""
            log_warning "If you want to switch to stable versions, run:"
            log_warning "  paru -Rns hyprland-git hypridle-git hyprlock-git hyprutils-git hyprlang-git hyprcursor-git"
            log_warning "  paru -S hyprland hypridle hyprlock"
            log_warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        else
            log_info "No -git Hyprland packages detected, installing stable core packages..."
            install_pacman "${hyprland_arch_core[@]}"
        fi
        
        # Configure rustup BEFORE building AUR packages (some require Rust)
        if command_exists rustup; then
            log_info "Configuring Rust toolchain..."
            rustup toolchain install stable --profile minimal --no-self-update 2>/dev/null || true
            rustup default stable 2>/dev/null || true
            log_success "Rust toolchain configured"
        fi
        
        install_paru "${hyprland_aur[@]}"
        
        # Install elephant packages separately - base first, then plugins
        log_info "Installing Elephant and plugins..."
        
        # Handle elephant-bin conflict with elephant (non-bin version)
        if paru -Qi elephant &>/dev/null && ! paru -Qi elephant-bin &>/dev/null; then
            log_warning "Removing conflicting 'elephant' package to install 'elephant-bin'"
            paru -Rdd --noconfirm elephant 2>/dev/null || true
        fi
        
        install_paru "${hyprland_aur_elephant[@]}"
        install_rust_tools
    else
        log_info "Host '$host' is not configured for Hyprland, skipping Hyprland packages"
    fi

    # Cursor installation policy:
    # - --no-cursor        => skip
    # - --cursor           => force install
    # - default (auto)     => install on Hyprland hosts only
    local should_install_cursor="false"
    if [[ "$SKIP_CURSOR_INSTALL" == "true" ]]; then
        should_install_cursor="false"
    elif [[ "$FORCE_CURSOR_INSTALL" == "true" ]]; then
        should_install_cursor="true"
    elif is_hyprland_host "$host"; then
        should_install_cursor="true"
    fi
    if [[ "$should_install_cursor" == "true" ]]; then
        install_cursor_app
    else
        log_info "Skipping Cursor installation"
    fi
}

install_for_debian() {
    install_apt "${core_cli_debian[@]}" "${dev_debian[@]}" "${debian_fonts[@]}"
    
    # Install Go from source (latest version)
    if ! install_go_from_source "debian"; then
        log_error "Failed to install Go from source, skipping Go installation"
        return 1
    fi
    
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
        log_info "Installing or upgrading Python tools via pipx..."
        for pkg in "${pipx_packages[@]}"; do
            if pipx list --json | jq -e ".venvs.\"$pkg\"" >/dev/null; then
                log_info "Upgrading $pkg..."
                pipx upgrade "$pkg"
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
    local platform
    platform=$(detect_platform)
    log_info "Finalizing setup..."
    
    # Refresh font cache on Linux
    if command_exists fc-cache; then
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
                if [[ $# -gt 1 && -n "${2:-}" && ! "${2:-}" =~ ^-- ]]; then
                    host="$2"
                    shift 2
                else
                    log_error "Missing host argument for --host"
                    log_info "Available host configurations: $(get_available_hosts | tr '\n' ' ')"
                    log_info "Usage: $0 --host <host>"
                    exit 1
                fi
            ;;
            --cursor)
                FORCE_CURSOR_INSTALL=true
                shift
            ;;
            --no-cursor)
                SKIP_CURSOR_INSTALL=true
                shift
            ;;
            *)
                log_error "Unknown argument: $1"
                log_info "Usage: $0 [--host <host>] [--cursor|--no-cursor]"
                exit 1
            ;;
        esac
    done
    
    log_info "Starting package installation on $platform (Host: ${host:-generic})..."
    
    case "$platform" in
        "arch" | "cachyos" | "manjaro") install_for_arch "$host" ;;
        "ubuntu" | "debian") install_for_debian ;;
        *) log_error "Unsupported platform: $platform" && exit 1 ;;
    esac
    
    setup_development_environments
    finalize_setup
    
    log_success "Package and font installation completed!"
}

# Run main function
main "$@"
