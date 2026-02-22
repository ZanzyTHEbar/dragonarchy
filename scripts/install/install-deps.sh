#!/usr/bin/env bash

set -euo pipefail

# Get script directory and source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091  # Runtime-resolved path to logging library
source "${SCRIPT_DIR}/../lib/logging.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/install-state.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/platform.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/hosts.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/manifest-toml.sh"

# Script directory for consistent script referencing
# Repo root discovery (used for locating hosts/)
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
    REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

# Expected structure:
#   repo_root/
#     hosts/
#     scripts/install/install-deps.sh
HOSTS_DIR="$REPO_ROOT/hosts"

MANIFEST_FILE="${SCRIPT_DIR}/deps.manifest.toml"

# Feature toggles (defaults)
FORCE_CURSOR_INSTALL=false
SKIP_CURSOR_INSTALL=false
KEEP_GIT_HYPRLAND=false
RUN_SETUP_SCRIPTS=true
BUNDLE_NAME=""

# Internal state
APT_UPDATED=false

# Cached resolved bundle metadata for fast, central membership checks.
declare -A BUNDLE_GROUP_SET=()

# Package manager adapter registry.
declare -A PACKAGE_MANAGER_INSTALLER=(
    [pacman]="install_pacman"
    [paru]="install_paru"
    [apt]="install_apt"
)

declare -A PACKAGE_MANAGER_SELECTOR=(
    [pacman]="core_cli,dev,fonts,host_,hyprland_"
    [paru]="gui,fonts,host_,hyprland_"
    [apt]="*"
)

manifest_validate() {
    if [[ ! -f "$MANIFEST_FILE" ]]; then
        log_error "Deps manifest not found: $MANIFEST_FILE"
        return 1
    fi
    return 0
}

feature_csv_for_host() {
    local host="$1"
    local features=()

    if [[ -n "$host" ]] && is_hyprland_host "$HOSTS_DIR" "$host" 2>/dev/null; then
        features+=("hyprland")
    fi

    local joined=""
    local f
    for f in "${features[@]}"; do
        if [[ -z "$joined" ]]; then
            joined="$f"
        else
            joined+=",$f"
        fi
    done

    echo "$joined"
}

# Check if a group should be installed given the active bundle filter.
# Returns 0 (install) if no bundle is active OR the group is in the bundle.
_bundle_allows_group() {
    local group="$1"
    [[ -z "$BUNDLE_NAME" ]] && return 0
    if [[ ${#BUNDLE_GROUP_SET[@]} -eq 0 ]]; then
        load_bundle_group_set "$BUNDLE_NAME"
    fi
    [[ -n "${BUNDLE_GROUP_SET[$group]:-}" ]] && return 0
    return 1
}

# Build an in-memory set of groups for the active bundle.
# Empty bundle name => all groups are enabled (legacy default behavior).
load_bundle_group_set() {
    local bundle="$1"

    BUNDLE_GROUP_SET=()
    if [[ -z "$bundle" ]]; then
        return 0
    fi

    local groups=()
    mapfile -t groups < <(manifest_bundle_groups "$MANIFEST_FILE" "$bundle")
    local group
    for group in "${groups[@]}"; do
        [[ -z "$group" ]] && continue
        BUNDLE_GROUP_SET["$group"]=1
    done
}

install_manifest_group() {
    local platform="$1"
    local manager="$2"
    local group="$3"
    local installer_fn="$4"
    local host="${5:-}"
    local feature_csv="${6:-}"

    # Skip groups not in the active bundle (if one is specified)
    if ! _bundle_allows_group "$group"; then
        log_info "Bundle '${BUNDLE_NAME}' excludes group ${group} (skipping)"
        return 0
    fi

    local pkgs=()
    mapfile -t pkgs < <(manifest_group_packages "$MANIFEST_FILE" "$platform" "$manager" "$group" "$host" "$feature_csv")

    if [[ ${#pkgs[@]} -eq 0 ]]; then
        log_info "No packages for ${platform}/${manager}/${group} (skipping)"
        return 0
    fi

    # Backwards-compat / safety: a few entries are sometimes written as command names instead of package names.
    # (e.g. "powerprofilesctl" is provided by "power-profiles-daemon" on Arch/CachyOS)
    if [[ "$platform" == "arch" ]]; then
        local normalized=()
        local p
        for p in "${pkgs[@]}"; do
            case "$p" in
                powerprofilesctl) normalized+=("power-profiles-daemon") ;;
                *) normalized+=("$p") ;;
            esac
        done
        pkgs=("${normalized[@]}")
    fi

    # Group-specific policy hooks for deterministic composition behavior.
    case "$group" in
        hyprland_base)
            local filtered_pkgs=()
            local package_name
            for package_name in "${pkgs[@]}"; do
                if [[ "$package_name" == "power-profiles-daemon" ]] && command -v tlp &>/dev/null; then
                    log_info "Skipping power-profiles-daemon (TLP is installed)"
                    continue
                fi
                filtered_pkgs+=("$package_name")
            done
            pkgs=("${filtered_pkgs[@]}")
            ;;
    esac

    if [[ ${#pkgs[@]} -eq 0 ]]; then
        log_info "No packages after policy filtering for ${platform}/${manager}/${group} (skipping)"
        return 0
    fi

    "$installer_fn" "${pkgs[@]}"
    return 0
}

install_manifest_groups_by_prefix() {
    # Args: platform manager prefix installer_fn host feature_csv
    local platform="$1"
    local manager="$2"
    local prefix="$3"
    local installer_fn="$4"
    local host="${5:-}"
    local feature_csv="${6:-}"

    local groups=()
    mapfile -t groups < <(manifest_yq_query "$MANIFEST_FILE" ".platforms.${platform}.${manager} | keys | .[]" | sort)

    local group
    for group in "${groups[@]}"; do
        [[ -z "$group" || "$group" == "null" ]] && continue
        [[ "$group" != "${prefix}"* ]] && continue
        install_manifest_group "$platform" "$manager" "$group" "$installer_fn" "$host" "$feature_csv"
    done
}

install_manager_group_batches() {
    # Args: platform manager host feature_csv
    local platform="$1"
    local manager="$2"
    local host="${3:-}"
    local feature_csv="${4:-}"

    local installer_fn="${PACKAGE_MANAGER_INSTALLER[$manager]:-}"
    if [[ -z "$installer_fn" ]]; then
        log_warning "No package manager adapter configured for '$manager', skipping"
        return 0
    fi

    local selector="${PACKAGE_MANAGER_SELECTOR[$manager]:-*}"
    if [[ -n "$BUNDLE_NAME" ]]; then
        selector="*"
    fi
    if [[ -z "$selector" || "$selector" == "*" ]]; then
        local groups=()
        mapfile -t groups < <(manifest_yq_query "$MANIFEST_FILE" ".platforms.${platform}.${manager} | keys | .[]" | sort)

        local group
        for group in "${groups[@]}"; do
            [[ -z "$group" || "$group" == "null" ]] && continue
            install_manifest_group "$platform" "$manager" "$group" "$installer_fn" "$host" "$feature_csv"
        done
        return 0
    fi

    local selectors=()
    local IFS=','
    read -r -a selectors <<< "$selector"

    local selected_prefix
    for selected_prefix in "${selectors[@]}"; do
        [[ -z "$selected_prefix" ]] && continue
        install_manifest_groups_by_prefix "$platform" "$manager" "$selected_prefix" "$installer_fn" "$host" "$feature_csv"
    done
}

install_platform_manager_batches() {
    # Args: platform host feature_csv [manager...]
    # If manager list omitted, auto-discover manifest managers for platform and filter to configured adapters.
    local platform="$1"
    local host="${2:-}"
    local feature_csv="${3:-}"
    shift 3

    local manager_args=("$@")

    if [[ "${#manager_args[@]}" -eq 0 ]]; then
        local discovered_managers=()
        mapfile -t discovered_managers < <(manifest_yq_query "$MANIFEST_FILE" ".platforms.${platform} | keys | .[]" | sort)
        manager_args=()
        local discovered_manager
        for discovered_manager in "${discovered_managers[@]}"; do
            [[ -z "$discovered_manager" || "$discovered_manager" == "null" ]] && continue
            if [[ -n "${PACKAGE_MANAGER_INSTALLER[$discovered_manager]:-}" ]]; then
                manager_args+=("$discovered_manager")
            fi
        done

        if [[ "${#manager_args[@]}" -eq 0 ]]; then
            log_warning "No package manager adapters configured for platform '$platform'"
            return 0
        fi
    fi

    local manager
    for manager in "${manager_args[@]}"; do
        install_manager_group_batches "$platform" "$manager" "$host" "$feature_csv"
    done
}

validate_manifest_managers_for_platform() {
    # Args: platform
    local platform="$1"

    local manifest_managers=()
    mapfile -t manifest_managers < <(manifest_yq_query "$MANIFEST_FILE" ".platforms.${platform} | keys | .[]" | sort)

    local configured_count=0
    local missing_adapter=0
    local manager

    for manager in "${manifest_managers[@]}"; do
        [[ -z "$manager" || "$manager" == "null" ]] && continue

        if [[ -z "${PACKAGE_MANAGER_INSTALLER[$manager]:-}" ]]; then
            log_warning "No adapter registered for manager '$manager' on platform '$platform'; skipping."
            missing_adapter=1
            continue
        fi
        configured_count=$((configured_count + 1))
    done

    if [[ "$configured_count" -eq 0 ]]; then
        log_error "No supported package manager adapters found for platform '$platform'."
        return 1
    fi

    if [[ "$missing_adapter" -eq 1 ]]; then
        log_warning "One or more managers in '$platform' manifest do not have adapters yet."
    fi
    return 0
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

# --- Package Installation Helpers ---
install_pacman() {
    log_info "Installing with pacman: $*"
    local pkgs_to_install=()
    local pkgs_missing=()
    local pkg
    for pkg in "$@"; do
        # Skip empty entries defensively
        [[ -z "$pkg" ]] && continue

        # Skip if already installed
        if pacman -Qi "$pkg" &>/dev/null; then
            continue
        fi

        # If the package isn't found in sync DB, treat it as required-but-not-in-repos and
        # fall back to Chaotic-AUR/AUR via paru (still required; failure will abort).
        if ! pacman -Si "$pkg" &>/dev/null; then
            pkgs_missing+=("$pkg")
            continue
        fi

        pkgs_to_install+=("$pkg")
    done
    if [[ ${#pkgs_to_install[@]} -gt 0 ]]; then
        sudo pacman -S --noconfirm --needed "${pkgs_to_install[@]}"
    else
        log_info "All pacman packages already installed."
    fi

    # Required packages not in pacman repos:
    # 1) Ensure Chaotic-AUR is enabled and sync DB
    # 2) Retry pacman install (some packages exist only there)
    # 3) Fall back to paru (AUR build) and FAIL if still not installed
    if [[ ${#pkgs_missing[@]} -gt 0 ]]; then
        log_warning "Required packages not found in pacman repos; retrying via Chaotic-AUR then AUR: ${pkgs_missing[*]}"

        # Enable Chaotic-AUR if needed (no-op if already present), then refresh sync DB.
        add_chaotic_aur || true
        sudo pacman -Sy >/dev/null 2>&1 || true

        local now_available=()
        local still_missing=()
        for pkg in "${pkgs_missing[@]}"; do
            if pacman -Si "$pkg" &>/dev/null; then
                now_available+=("$pkg")
            else
                still_missing+=("$pkg")
            fi
        done

        if [[ ${#now_available[@]} -gt 0 ]]; then
            log_info "Installing from pacman repos after Chaotic-AUR refresh: ${now_available[*]}"
            sudo pacman -S --noconfirm --needed "${now_available[@]}"
        fi

        if [[ ${#still_missing[@]} -gt 0 ]]; then
            log_warning "Still missing from pacman repos; installing via paru (AUR build required): ${still_missing[*]}"
            install_paru "${still_missing[@]}"
        fi
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
        # Non-interactive install:
        # - --skipreview avoids the "Proceed to review?" prompt
        # - --batchinstall avoids per-package prompts where possible
        #
        # For certain legacy GNOME stack packages (e.g. cogl/clutter), LTO can trigger GCC warnings
        # that become errors under some build configs. Disable LTO and relax that specific warning
        # to improve build stability.
        local build_env=()
        local mflags=(--nocheck)
        local joined=" ${pkgs_to_install[*]} "
        # If we're building anything that drags in the legacy GNOME stack (cogl/clutter),
        # apply defensive flags. Note: nemo-preview-git should match here too.
        if [[ "$joined" == *" cogl "* || "$joined" == *" clutter "* || "$joined" == *" nemo-preview"* ]]; then
            # makepkg sources /etc/makepkg.conf; pass our own config via `makepkg --config`
            # (through paru's --mflags) so the overrides reliably apply.
            local makepkg_conf
            makepkg_conf="$(mktemp /tmp/makepkg.conf.gnome-stack.XXXXXX)"
            cat >"$makepkg_conf" <<'EOF'
# Auto-generated by dotfiles installer for GNOME stack AUR builds (cogl/clutter).
#
# Goal: avoid brittle failures on new GCC toolchains where upstream code triggers
# maybe-uninitialized warnings that some build configs treat as errors, often under LTO.

. /etc/makepkg.conf

# Disable LTO (both via flags and makepkg option)
CFLAGS+=" -fno-lto -Wno-error=maybe-uninitialized -Wno-error -Wno-maybe-uninitialized"
CXXFLAGS+=" -fno-lto -Wno-error=maybe-uninitialized -Wno-error -Wno-maybe-uninitialized"
LDFLAGS+=" -fno-lto"
OPTIONS+=(!lto)
EOF

            build_env+=(
                env
                # Ensure we clean up even if paru aborts
                MAKEPKG_GNOME_STACK_CONF="$makepkg_conf"
            )

            # Use the custom config for this makepkg invocation
            mflags=(--config "$makepkg_conf" --nocheck)
        fi

        # For some GNOME stack AUR packages (notably gnome-bluetooth), the test suite can fail
        # on certain Python/gi/GIRepository combinations. Since these packages are required
        # for the desktop experience, we skip `check()` to avoid false negatives.
        "${build_env[@]}" paru -S --noconfirm --needed --removemake --sudoloop --skipreview --batchinstall --mflags "${mflags[*]}" "${pkgs_to_install[@]}"

        # Clean up temporary makepkg config if created
        if [[ -n "${makepkg_conf:-}" && -f "${makepkg_conf:-}" ]]; then
            rm -f "${makepkg_conf}" 2>/dev/null || true
        fi

        # Hard-required: verify they installed.
        local missing_after=()
        for pkg in "${pkgs_to_install[@]}"; do
            paru -Qi "$pkg" &>/dev/null || missing_after+=("$pkg")
        done
        if [[ ${#missing_after[@]} -gt 0 ]]; then
            log_error "Required AUR packages failed to install: ${missing_after[*]}"
            return 1
        fi
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

install_apt() {
    if [[ "$APT_UPDATED" != "true" ]]; then
        log_info "Updating apt repositories..." && sudo apt-get update
        APT_UPDATED=true
    fi
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
        local age_tmp
        age_tmp=$(mktemp -d)
        local age_version
        age_version=$(curl -fsSL "https://api.github.com/repos/FiloSottile/age/releases/latest" | grep '"tag_name"' | head -1 | cut -d'"' -f4)
        age_version="${age_version:-v1.2.0}"
        if curl -fsSL "https://github.com/FiloSottile/age/releases/download/${age_version}/age-${age_version}-linux-amd64.tar.gz" | tar -xz -C "$age_tmp" --strip-components=1; then
            sudo mv "$age_tmp/age" /usr/local/bin/
            sudo mv "$age_tmp/age-keygen" /usr/local/bin/
        else
            log_warning "Failed to download age ${age_version}"
        fi
        rm -rf "$age_tmp"
    }
    command_exists sops || {
        log_info "Installing sops binary..."
        local sops_tmp
        sops_tmp=$(mktemp)
        local sops_version
        sops_version=$(curl -fsSL "https://api.github.com/repos/getsops/sops/releases/latest" | grep '"tag_name"' | head -1 | cut -d'"' -f4)
        sops_version="${sops_version:-v3.9.4}"
        if curl -fsSL "https://github.com/getsops/sops/releases/download/${sops_version}/sops-${sops_version}.linux.amd64" -o "$sops_tmp"; then
            sudo mv "$sops_tmp" /usr/local/bin/sops
            sudo chmod +x /usr/local/bin/sops
        else
            log_warning "Failed to download sops ${sops_version}"
            rm -f "$sops_tmp"
        fi
    }
}

install_rust_tools() {
    if command_exists rustup; then
        log_info "Installing Rust stable toolchain..."
        rustup toolchain install stable || log_warning "Failed to install Rust toolchain (continuing)"
        rustup default stable || log_warning "Failed to set default Rust toolchain (continuing)"
    fi
    
    if command_exists cargo; then
        log_info "Installing Rust tools..."
        cargo install lsd bat ripgrep zoxide eza dua-cli git-delta || log_warning "Some Rust tools failed to install (continuing)"
    fi
}

# --- OS-Specific Installation Functions ---
install_for_arch() {
    local host="$1"
    local platform_key="arch"

    manifest_validate
    manifest_ensure_yq "$platform_key"

    local feature_csv
    feature_csv=$(feature_csv_for_host "$host")
    
    log_info "Updating pacman repositories..." && sudo pacman -Sy

    # Run package manager adapters with platform policy for non-bundle installs.
    install_platform_manager_batches "$platform_key" "$host" "$feature_csv"
    
    # Install Go from source (latest version; function is idempotent)
    if ! install_go_from_source "arch"; then
        log_warning "Failed to install Go from source; continuing without Go"
    fi
    
    # Automatically detect if this host needs Hyprland packages
    if is_hyprland_host "$HOSTS_DIR" "$host"; then
        log_info "Installing Hyprland specific packages for host: $host"
        add_chaotic_aur

        local skip_hyprland_installs="false"
        
        # Check for -git packages and replace with stable versions
        if has_hyprland_git_packages; then
            if [[ "$KEEP_GIT_HYPRLAND" == "true" ]]; then
                log_warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                log_warning "Detected -git versions of Hyprland packages!"
                log_warning "Keeping -git versions as requested (--keep-git-hyprland flag)"
                log_warning ""
                log_warning "Installed -git packages:"
                for pkg in "hyprland-git" "hypridle-git" "hyprlock-git" "hyprutils-git" "hyprlang-git" "hyprcursor-git"; do
                    if is_package_installed "$pkg"; then
                        log_warning "  ✓ $pkg"
                    fi
                done
                log_warning ""
                log_warning "Note: -git versions may be unstable. To switch to stable:"
                log_warning "  Run install script without --keep-git-hyprland flag"
                log_warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                # Skip stable package installation, but continue with the rest of this script
                skip_hyprland_installs="true"
            else
                log_warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                log_warning "Detected -git versions of Hyprland packages!"
                log_warning "Replacing with stable versions for better compatibility..."
                log_warning ""
                
                # List detected -git packages
                local git_pkgs_found=()
                for pkg in "hyprland-git" "hypridle-git" "hyprlock-git" "hyprutils-git" "hyprlang-git" "hyprcursor-git"; do
                    if is_package_installed "$pkg"; then
                        git_pkgs_found+=("$pkg")
                        log_warning "  ✓ Found: $pkg"
                    fi
                done
                
                log_warning ""
                log_info "Removing -git packages: ${git_pkgs_found[*]}"
                
                # Remove all -git packages at once to avoid dependency issues
                if [[ ${#git_pkgs_found[@]} -gt 0 ]]; then
                    sudo pacman -Rdd --noconfirm "${git_pkgs_found[@]}" 2>/dev/null || {
                        log_error "Failed to remove -git packages, trying with paru..."
                        paru -Rdd --noconfirm "${git_pkgs_found[@]}" 2>/dev/null || {
                            log_error "Failed to remove -git packages. Manual intervention required."
                            log_error "Run: sudo pacman -Rdd ${git_pkgs_found[*]}"
                            exit 1
                        }
                    }
                    log_success "Removed -git packages successfully"
                fi
                
                log_warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            fi
        fi

        if [[ "$skip_hyprland_installs" != "true" ]]; then
            # Configure rustup BEFORE building AUR packages (some require Rust)
            if command_exists rustup; then
                log_info "Configuring Rust toolchain..."
                rustup toolchain install stable --profile minimal --no-self-update 2>/dev/null || true
                rustup default stable 2>/dev/null || true
                log_success "Rust toolchain configured"
            fi

            if command_exists paru && paru -Qi walker-bin &>/dev/null; then
                log_info "Removing legacy walker-bin package in favour of walker"
                paru -Rns --noconfirm walker-bin || true
            fi

            # Install Elephant (meta package bundles providers)
            log_info "Installing Elephant stack..."
            legacy_elephant_bin_pkgs=(
                "elephant-bin"
                "elephant-desktopapplications-bin"
                "elephant-files-bin"
                "elephant-runner-bin"
                "elephant-clipboard-bin"
                "elephant-providerlist-bin"
                "elephant-menus-bin"
                "elephant-calc-bin"
                "elephant-todo-bin"
                "elephant-bluetooth-bin"
                "elephant-websearch-bin"
                "elephant-archlinuxpkgs-bin"
                "elephant-bookmarks-bin"
                "elephant-symbols-bin"
                "elephant-unicode-bin"
            )
            local to_remove=()
            local legacy_pkg
            for legacy_pkg in "${legacy_elephant_bin_pkgs[@]}"; do
                if command_exists paru && paru -Qi "$legacy_pkg" &>/dev/null; then
                    to_remove+=("$legacy_pkg")
                fi
            done
            if [[ ${#to_remove[@]} -gt 0 ]]; then
                log_info "Removing legacy Elephant bin packages: ${to_remove[*]}"
                paru -Rns --noconfirm "${to_remove[@]}" || true
            fi

            log_info "Installing Rust tools..."
            install_rust_tools || log_warning "Rust tools installation had issues (continuing)"
        else
            log_warning "Skipping Hyprland stable installs due to --keep-git-hyprland"
        fi
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
        elif is_hyprland_host "$HOSTS_DIR" "$host"; then
        should_install_cursor="true"
    fi
    if [[ "$should_install_cursor" == "true" ]]; then
        install_cursor_app || log_warning "Cursor installation failed (continuing)"
    else
        log_info "Skipping Cursor installation"
    fi
    
    return 0
}

install_for_debian() {
    local host="${1:-}"
    local platform_key="debian"

    manifest_validate
    manifest_ensure_yq "$platform_key"

    local feature_csv
    feature_csv=$(feature_csv_for_host "$host")

    # Use the same bundle-aware adapter flow as other platforms.
    install_platform_manager_batches "$platform_key" "$host" "$feature_csv"

    # Install Go from source (latest version; function is idempotent)
    if ! install_go_from_source "debian"; then
        log_warning "Failed to install Go from source; continuing without Go"
    fi

    install_additional_tools
}

# --- Post-Install Setup ---
setup_development_environments() {
    log_info "Setting up development environments..."

    local platform
    platform=$(detect_platform)
    local platform_key
    platform_key=$(canonical_platform_key "$platform")
    
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
        local pipx_pkgs=()
        mapfile -t pipx_pkgs < <(manifest_tool_list "$MANIFEST_FILE" "tools.pipx.packages")

        local pkg
        for pkg in "${pipx_pkgs[@]}"; do
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
    
    if [[ "$RUN_SETUP_SCRIPTS" == "true" ]]; then
        log_info "Running setup scripts..."
        bash "$SCRIPT_DIR/setup.sh"
    else
        log_info "Skipping setup scripts (--no-setup)"
    fi
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
                    log_info "Available host configurations: $(get_available_hosts "$HOSTS_DIR" | tr '\n' ' ')"
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
            --keep-git-hyprland)
                KEEP_GIT_HYPRLAND=true
                shift
            ;;
            --no-setup)
                RUN_SETUP_SCRIPTS=false
                shift
            ;;
            --bundle)
                if [[ $# -gt 1 && -n "${2:-}" && ! "${2:-}" =~ ^-- ]]; then
                    BUNDLE_NAME="$2"
                    shift 2
                else
                    log_error "Missing bundle name for --bundle"
                    log_info "Available bundles (from manifest):"
                    manifest_validate && manifest_ensure_yq "$(canonical_platform_key "$(detect_platform)")" && \
                        manifest_list_bundles "$MANIFEST_FILE" | while read -r b; do echo "  $b"; done
                    exit 1
                fi
            ;;
            *)
                log_error "Unknown argument: $1"
                log_info "Usage: $0 [--host <host>] [--cursor|--no-cursor] [--keep-git-hyprland] [--no-setup] [--bundle NAME]"
                exit 1
            ;;
        esac
    done

    # Default to detected hostname if not specified
    if [[ -z "$host" ]]; then
        host=$(detect_host "$HOSTS_DIR")
    fi

    local platform_key
    platform_key=$(canonical_platform_key "$platform")

    manifest_validate
    manifest_ensure_yq "$platform_key"

    local yq_bin yq_version
    if ! yq_bin=$(manifest_yq_resolve_bin 2>/dev/null); then
        log_error "Manifest parser yq v4 not available after bootstrap"
        log_error "Expected: $HOME/.local/bin/yq (mikefarah/yq v4)"
        exit 1
    fi
    yq_version=$($yq_bin --version 2>/dev/null || true)
    log_info "Manifest parser: ${yq_bin} (${yq_version})"
    
    # Validate bundle if specified
    if [[ -n "$BUNDLE_NAME" ]]; then
        local bundle_exists
        bundle_exists=$(manifest_yq_query "$MANIFEST_FILE" ".bundles.${BUNDLE_NAME} | type")
        if [[ -z "$bundle_exists" || "$bundle_exists" == "null" ]]; then
            log_error "Unknown bundle: $BUNDLE_NAME"
            log_info "Available bundles:"
            manifest_list_bundles "$MANIFEST_FILE" | while read -r b; do echo "  $b"; done
            exit 1
        fi
        log_info "Bundle mode: installing groups from bundle '$BUNDLE_NAME'"
    fi
    load_bundle_group_set "$BUNDLE_NAME"

    validate_manifest_managers_for_platform "$platform_key" || {
        log_error "Manifest manager configuration invalid for platform '$platform_key'"
        exit 1
    }

    log_info "Starting package installation on $platform (Host: ${host:-generic})..."
    
    case "$platform" in
        "arch" | "cachyos" | "manjaro") 
            install_for_arch "$host" || {
                log_error "Failed to install packages for Arch platform"
                exit 1
            }
            ;;
        "ubuntu" | "debian") 
            install_for_debian "$host" || {
                log_error "Failed to install packages for Debian platform"
                exit 1
            }
            ;;
        *) log_error "Unsupported platform: $platform" && exit 1 ;;
    esac
    
    log_info "Setting up development environments..."
    setup_development_environments || log_warning "Development environment setup had issues (continuing)"
    
    log_info "Finalizing setup..."
    finalize_setup || log_warning "Finalization had issues (continuing)"
    
    log_success "Package and font installation completed!"
}

# Run main function
main "$@"
