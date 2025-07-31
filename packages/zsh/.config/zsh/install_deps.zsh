# File: ~/.config/zsh/install_deps.zsh

# Ensure this script is only sourced, not executed directly
if [[ -z "$ZSH_VERSION" ]]; then
  echo "This script must be sourced in a Zsh shell."
  exit 1
fi

# Function to check and install dependencies
setup_dependencies() {
  # Associative array of dependencies: name => details
  typeset -A deps=(
    ["bat"]="package:bat|debian:batcat|version:latest|linux:debian:apt|linux:arch:pacman|macos:brew|fallback:download:https://github.com/sharkdp/bat/releases/latest/download/bat-v{version}-x86_64-unknown-linux-gnu.tar.gz"
    ["fzf"]="package:fzf|version:0.55.0|linux:arch:pacman|linux:debian:apt|macos:brew|linux:git:https://github.com/junegunn/fzf.git|fallback:download:https://github.com/junegunn/fzf/releases/download/{version}/fzf-{version}-linux_amd64.tar.gz"
    ["eza"]="package:eza|version:latest|linux:debian:apt:deb:https://deb.gierens.de|linux:arch:paru|macos:brew|fallback:download:https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-gnu.tar.gz"
    ["gh"]="package:github-cli|version:latest|linux:debian:apt|linux:arch:paru|macos:brew|fallback:download:https://github.com/cli/cli/releases/latest/download/gh_{version}_linux_amd64.tar.gz"
    ["nvim"]="package:neovim|version:latest|linux:arch:pacman|linux:debian:apt|macos:brew|fallback:download:https://github.com/neovim/neovim/releases/latest/download/nvim.appimage"
    ["nvm"]="package:nvm|version:lastest|linux:arch:paru|linux:debian:apt|macos:brew|postinstall:source /usr/share/nvm/init-nvm.sh && nvm install node && nvm use node"
    ["autojump"]="package:autojump|version:latest|linux:arch:paru|linux:debian:apt|macos:brew"
    ["lsd"]="package:lsd|version:latest|linux:arch:paru|linux:debian:apt|macos:brew"
  )

  local os_type=$(uname -s | tr '[:upper:]' '[:lower:]')
  local distro_id=""
  if [[ "$os_type" == "linux" && -f /etc/os-release ]]; then
    distro_id=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
  fi
 
  if [[ "$distro_id" == "cachyos" ]]; then
      package_distro="arch"
  else
      package_distro="$distro_id"
  fi
 
  local install_dir="$HOME/.local/bin"
  local cache_dir="$HOME/.cache/zsh_setup"
  local log_file="$cache_dir/setup_deps.log"
  local installed_flag="$cache_dir/deps_installed"

  # Create necessary directories
  mkdir -p "$install_dir" "$cache_dir"

  # Log function
  log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $@" >> "$log_file"; echo "$@"; }

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
    local package_name=""
    local package_default=""
    local package_map=()
    local version=""
    local postinstall=""

    # Parse dependency details
    for field in ${(s:|:)dep_details}; do
      if [[ "$field" == package:* ]]; then
        local package_str=${field#package:}
        for part in ${(s:|:)package_str}; do
          if [[ "$part" == *:* ]]; then
            local distro=${part%%:*}
            local name=${part#*:}
            package_map[$distro]=$name
          else
            package_default=$part
          fi
        done
      elif [[ "$field" == version:* ]]; then
        version=${field#version:}
      elif [[ "$field" == postinstall:* ]]; then
        postinstall=${field#postinstall:}
      fi
    done

    # Determine package_name
    if [[ -n "${package_map[$distro_id]}" ]]; then
      package_name="${package_map[$distro_id]}"
    elif [[ -n "$package_default" ]]; then
      package_name="$package_default"
    else
      log "No package name specified for $dep_name"
      continue
    fi

    # Collect possible installation methods
    local possible_methods=()
    
    for field in ${(s:|:)dep_details}; do
        if [[ "$field" =~ "${os_type}:" ]]; then
            if [[ "$os_type" == "linux" && -n "$package_distro" ]]; then
                if [[ "$field" =~ "linux:$package_distro:" ]]; then
                    possible_methods+=("$field")
                fi
            else
                possible_methods+=("$field")
            fi
        elif [[ "$field" =~ "fallback:" ]]; then
            possible_methods+=("$field")
        elif [[ "$field" =~ "install:" ]]; then
            possible_methods+=("$field")
        fi
    done 

    if [[ ${#possible_methods} -eq 0 ]]; then
      log "No installation method found for $dep_name on $os_type $distro_id"
      continue
    fi

    # Take the first possible method
    local install_method=$possible_methods[1]
    local method_parts=(${(s.:.)install_method})

    # Installation logic
    if [[ "${method_parts[1]}" == "linux" && "$os_type" == "linux" ]]; then
        local package_manager="${method_parts[3]}"
        case "$package_manager" in
            pacman)
                log "Installing $dep_name via pacman..."
                sudo pacman -S --noconfirm "$package_name" && log "$dep_name installed via pacman." || log "Failed to install $dep_name via pacman."
                ;;
            paru)
                log "Installing $dep_name via paru..."
                if paru -S --noconfirm --needed "$package_name"; then
                    log "$dep_name installed via paru."
                else
                    log "Failed to install $dep_name via paru."
                fi
                ;;
            apt)
                log "Installing $dep_name via apt..."
                if [[ "${method_parts[4]}" == "deb" ]]; then
                    local repo_url="${method_parts[5]}"
                    curl -fsSL "$repo_url" | sudo tee /etc/apt/sources.list.d/$dep_name.list
                    sudo apt-get update
                fi
                sudo apt-get install -y "$package_name" && log "$dep_name installed via apt." || log "Failed to install $dep_name via apt."
                ;;
            git)
                if [[ "$dep_name" == "fzf" ]]; then
                    local url="${method_parts[4]}"
                    log "Installing $dep_name via git..."
                    local clone_dir="$cache_dir/$dep_name"
                    git clone --depth 1 "$url" "$clone_dir" && (
                        cd "$clone_dir"
                        ./install --all --no-update-rc
                        mv "$clone_dir/bin/fzf" "$install_dir/"
                    ) && log "$dep_name installed via git." || log "Failed to install $dep_name via git."
                else
                    log "Git installation not supported for $dep_name"
                fi
                ;;
        esac
    elif [[ "${method_parts[1]}" == "macos" && "$os_type" == "darwin" ]]; then
        if command -v brew &>/dev/null; then
            log "Installing $dep_name via brew..."
            brew install "$package_name" && log "$dep_name installed via brew." || log "Failed to install $dep_name via brew."
        else
            log "Homebrew not found."
        fi
    elif [[ "${method_parts[1]}" == "install" ]]; then
        if [[ "${method_parts[2]}" == "script" ]]; then
            local url="${method_parts[3]}"
            log "Installing $dep_name via script..."
            curl -fsSL "$url" | bash && log "$dep_name installed via script." || log "Failed to install $dep_name via script."
        else
            log "Unsupported install method: ${method_parts[2]}"
        fi
    elif [[ "${method_parts[1]}" == "fallback" ]]; then
        if [[ "${method_parts[2]}" == "download" ]]; then
            local url="${method_parts[3]}"
            download_and_extract "$url" "$dep_name" "$version"
        else
            log "Unsupported fallback method: ${method_parts[2]}"
        fi
    else
        log "Unsupported installation method: $install_method"
    fi

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
