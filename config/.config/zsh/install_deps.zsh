# File: ~/.config/zsh/setup_deps.zsh

# Ensure this script is only sourced, not executed directly
if [[ -z "$ZSH_VERSION" ]]; then
  echo "This script must be sourced in a Zsh shell."
  exit 1
fi

# TODO: Add lsd

# Function to check and install dependencies
setup_dependencies() {
  # Associative array of dependencies: name => details
  typeset -A deps=(
    ["batcat"]="package:batcat|version:latest|linux:apt:deb|macos:brew|fallback:download:https://github.com/sharkdp/bat/releases/latest/download/bat-v{version}-x86_64-unknown-linux-gnu.tar.gz"
    ["fzf"]="package:fzf|version:0.55.0|linux:git:https://github.com/junegunn/fzf.git|macos:brew|fallback:download:https://github.com/junegunn/fzf/releases/download/{version}/fzf-{version}-linux_amd64.tar.gz"
    ["eza"]="package:eza|version:latest|linux:apt:deb:https://deb.gierens.de|macos:brew|fallback:download:https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-gnu.tar.gz"
    ["gh"]="package:gh|version:latest|linux:apt:deb:https://cli.github.com/packages|macos:brew|fallback:download:https://github.com/cli/cli/releases/latest/download/gh_{version}_linux_amd64.tar.gz"
    ["nvim"]="package:neovim|version:latest|linux:apt:deb|macos:brew|fallback:download:https://github.com/neovim/neovim/releases/latest/download/nvim.appimage"
    ["node"]="package:nvm|version:0.40.1|install:script:https://raw.githubusercontent.com/nvm-sh/nvm/v{version}/install.sh|postinstall:nvm install node"
  )

  local os_type=$(uname -s | tr '[:upper:]' '[:lower:]')
  local install_dir="$HOME/.local/bin"
  local cache_dir="$HOME/.cache/zsh_setup"
  local log_file="$cache_dir/setup_deps.log"
  local installed_flag="$cache_dir/deps_installed"

  # Create necessary directories
  mkdir -p "$install_dir" "$cache_dir"

  # Log function
  log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $@" >> "$log_file"; }

  # Helper to check if a binary exists
  check_binary() { command -v "$1" &>/dev/null && return 0 || return 1; }

  # Helper to download and extract a tarball
  download_and_extract() {
    local url="$1" bin_name="$2" version="$3"
    local tmp_file="$cache_dir/$bin_name.tar.gz"
    url=${url//\{version\}/$version}
    log "Downloading $bin_name from $url"
    if curl -fsSL "$url" -o "$tmp_file"; then
      tar -xzf "$tmp_file" -C "$cache_dir"
      find "$cache_dir" -type f -executable -name "$bin_name" -exec mv {} "$install_dir/" \;
      rm -f "$tmp_file"
      log "$bin_name installed successfully."
      return 0
    else
      log "Failed to download $bin_name from $url."
      return 1
    fi
  }

  # Main installation logic
  for dep_name dep_details in ${(kv)deps}; do
    if check_binary "$dep_name"; then
      log "$dep_name is already installed."
      continue
    fi

    log "Processing $dep_name..."
    local package_name version install_method url postinstall
    # Parse dependency details
    for field in ${(s:|:)dep_details}; do
      case "$field" in
        package:*) package_name=${field#package:} ;;
        version:*) version=${field#version:} ;;
        "${os_type}:apt:deb"|"${os_type}:brew") install_method=$field ;;
        "${os_type}:apt:deb:"*) install_method="apt" url=${field#${os_type}:apt:deb:} ;;
        "${os_type}:git:"*) install_method="git" url=${field#${os_type}:git:} ;;
        "${os_type}:script:"*) install_method="script" url=${field#${os_type}:script:} ;;
        fallback:download:*) install_method="download" url=${field#fallback:download:} ;;
        postinstall:*) postinstall=${field#postinstall:} ;;
      esac
    done

    # Installation logic
    case "$install_method" in
      "${os_type}:apt")
        if [[ -f /etc/debian_version ]]; then
          log "Installing $dep_name via apt..."
          if [[ -n "$url" ]]; then
            curl -fsSL "${url}/$(dpkg --print-architecture)" | sudo tee /etc/apt/sources.list.d/$dep_name.list
            sudo apt-get update
          fi
          sudo apt-get install -y "$package_name" && log "$dep_name installed via apt." || log "Failed to install $dep_name via apt."
        else
          log "Apt not available on this system."
          install_method="download"
        fi
        ;;
      "${os_type}:brew")
        if command -v brew &>/dev/null; then
          log "Installing $dep_name via brew..."
          brew install "$package_name" && log "$dep_name installed via brew." || log "Failed to install $dep_name via brew."
        else
          log "Homebrew not found."
          install_method="download"
        fi
        ;;
      "git")
        log "Installing $dep_name via git..."
        local clone_dir="$cache_dir/$dep_name"
        git clone --depth 1 "$url" "$clone_dir" && (
          cd "$clone_dir"
          if [[ "$dep_name" == "fzf" ]]; then
            ./install --all --no-update-rc
            mv "$clone_dir/bin/fzf" "$install_dir/"
          fi
        ) && log "$dep_name installed via git." || log "Failed to install $dep_name via git."
        ;;
      "script")
        log "Installing $dep_name via script..."
        curl -fsSL "$url" | bash && log "$dep_name installed via script." || log "Failed to install $dep_name via script."
        ;;
      "download")
        download_and_extract "$url" "$dep_name" "$version"
        ;;
      *)
        log "No installation method defined for $dep_name on $os_type."
        continue
        ;;
    esac

    # Run post-installation commands if defined
    if [[ -n "$postinstall" && -n "$(command -v $dep_name)" ]]; then
      log "Running postinstall for $dep_name: $postinstall"
      eval "$postinstall" && log "Postinstall for $dep_name completed." || log "Postinstall for $dep_name failed."
    fi
  done

  # Mark dependencies as installed
  touch "$installed_flag"
}

# Function to check if setup is needed
needs_setup() {
  [[ ! -f "$HOME/.cache/zsh_setup/deps_installed" ]] && return 0
  return 1
}

# Interactive prompt to run setup
if needs_setup; then
  echo "Dependencies not yet installed. Run setup now? [y/N]"
  read -r response
  if [[ "$response" =~ ^[Yy]$ ]]; then
    setup_dependencies
  else
    echo "Skipping dependency setup. Run 'setup_dependencies' manually to install."
  fi
fi
