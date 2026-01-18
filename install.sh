#!/usr/bin/env bash

# Main Setup Script for Traditional Dotfiles Management

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source centralized logging utilities
# shellcheck disable=SC1091  # Runtime-resolved path to logging library
source "${SCRIPT_DIR}/scripts/lib/logging.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/scripts/lib/install-state.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/scripts/lib/hosts.sh"

CONFIG_DIR="$SCRIPT_DIR"
PACKAGES_DIR="$CONFIG_DIR/packages"
SCRIPTS_DIR="$CONFIG_DIR/scripts"
HOSTS_DIR="$CONFIG_DIR/hosts"

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
RUN_THEME=true
RUN_SHELL_CONFIG=true
RUN_POST_SETUP=true
SETUP_UTILITIES=false
RESET_STATE=false
# Force re-run of package installation step (clears cached package markers for this host)
RESET_PACKAGES=false
# Fresh-machine mode: purge conflicting dotfile targets before stowing
FRESH_MODE=false
# Pass-through flags for install-deps.sh (e.g., --cursor/--no-cursor)
INSTALL_DEPS_FLAGS=()

# Show usage information
usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Traditional Dotfiles Management Setup Script

OPTIONS:
    -h, --help              Show this help message
    -v, --verbose           Enable verbose output
    --reset                 Clear installation state and force full re-run of all steps
    --reset-packages        Force re-run of package installation step (for this host)
    --fresh, -f             Fresh machine mode: backup+remove existing dotfile targets that would block stow
    --host HOST             Setup for specific host (any hostname supported)
    --packages-only         Only install packages
    --dotfiles-only         Only setup dotfiles
    --secrets-only          Only setup secrets
    --no-packages           Skip package installation
    --no-dotfiles           Skip dotfiles setup
    --no-secrets            Skip secrets setup
    --no-system-config      Skip system-level configuration (PAM, services, etc.)
    --no-theme              Skip theme refresh (plymouth)
    --no-shell              Skip shell configuration
    --no-post-setup         Skip post-setup tasks
    --utilities             Symlink selected utilities to ~/.local/bin
    --no-utilities          Do not symlink utilities
    --cursor                Force install Cursor editor (pass-through to deps installer)
    --no-cursor             Skip installing Cursor editor (pass-through to deps installer)

EXAMPLES:
    $0                      # Complete setup for current machine
    $0 --fresh              # Fresh machine setup (purge conflicting dotfiles before stow)
    $0 --host dragon        # Setup for specific host
    $0 --packages-only      # Only install packages
    $0 --dotfiles-only      # Only setup dotfiles
    $0 --no-secrets         # Skip secrets setup
    $0 --reset              # Clear state and force full re-run

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h | --help)
                usage
                exit 0
            ;;
            -v | --verbose)
                VERBOSE=true
                shift
            ;;
            --reset)
                RESET_STATE=true
                shift
            ;;
            --reset-packages)
                RESET_PACKAGES=true
                shift
            ;;
            -f | --fresh)
                FRESH_MODE=true
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
            --no-system-config)
                NO_SYSTEM_CONFIG=true
                shift
            ;;
            --no-theme)
                RUN_THEME=false
                shift
            ;;
            --no-shell)
                RUN_SHELL_CONFIG=false
                shift
            ;;
            --no-post-setup)
                RUN_POST_SETUP=false
                shift
            ;;
            --utilities)
                SETUP_UTILITIES=true
                shift
            ;;
            --no-utilities)
                SETUP_UTILITIES=false
                shift
            ;;
            --cursor)
                INSTALL_DEPS_FLAGS+=("--cursor")
                shift
            ;;
            --no-cursor)
                INSTALL_DEPS_FLAGS+=("--no-cursor")
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

reset_host_package_steps() {
    local host="$1"
    [[ -z "${host:-}" ]] && return 0
    # scripts/lib/install-state.sh defines STATE_DIR
    if [[ -n "${STATE_DIR:-}" && -d "${STATE_DIR:-}" ]]; then
        rm -f "${STATE_DIR}/install:${host}:packages:"* 2>/dev/null || true
    fi
}

packages_sanity_ok() {
    local host="$1"
    # On Hyprland hosts, waybar is a hard requirement for this setup.
    if [[ -n "${host:-}" ]] && is_hyprland_host "$HOSTS_DIR" "$host" >/dev/null 2>&1; then
        command -v waybar >/dev/null 2>&1 || return 1
        command -v hyprland >/dev/null 2>&1 || return 1
    fi
    return 0
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

# Detect whether this appears to be a "fresh machine" for dotfiles:
# i.e. we don't see any existing stow-managed symlinks pointing into our `packages/`.
is_fresh_machine() {
    local packages_real
    packages_real=$(readlink -f "$PACKAGES_DIR" 2>/dev/null || true)
    [[ -z "$packages_real" ]] && packages_real="$PACKAGES_DIR"

    # If we can find ANY symlink in common dotfile locations that resolves into our packages dir,
    # we consider this machine already managed (not fresh).
    local search_roots=(
        "$HOME"
        "$HOME/.config"
        "$HOME/.local"
        "$HOME/.ssh"
        "$HOME/.gnupg"
    )

    local root maxdepth
    for root in "${search_roots[@]}"; do
        if [[ ! -e "$root" ]]; then
            continue
        fi

        maxdepth=1
        if [[ "$root" == "$HOME/.config" || "$root" == "$HOME/.local" || "$root" == "$HOME/.ssh" || "$root" == "$HOME/.gnupg" ]]; then
            maxdepth=5
        fi

        local link
        while IFS= read -r -d '' link; do
            local resolved=""
            resolved=$(readlink -f "$link" 2>/dev/null || true)
            if [[ -n "$resolved" && "$resolved" == "$packages_real/"* ]]; then
                return 1  # Not fresh
            fi
        done < <(find "$root" -maxdepth "$maxdepth" -type l -print0 2>/dev/null)
    done

    return 0  # Fresh
}

maybe_enable_fresh_mode() {
    # Explicit --fresh/-f always wins
    if [[ "$FRESH_MODE" == "true" ]]; then
        return 0
    fi

    # Only relevant when we're going to stow dotfiles
    if [[ "$INSTALL_DOTFILES" != "true" ]]; then
        return 0
    fi

    if is_fresh_machine; then
        FRESH_MODE=true
        log_warning "Fresh machine detected (no existing stow-managed dotfile symlinks found). Enabling fresh mode automatically."
    fi
}

# Purge stow conflicts based on a captured stow output log (from a real stow/restow run).
# This is more reliable than parsing LINK lines because stow can abort before applying anything.
purge_stow_conflicts_from_output() {
    local package="$1"
    local backup_root="$2"
    local output_file="$3"

    if [[ -z "${package:-}" || -z "${backup_root:-}" || -z "${output_file:-}" ]]; then
        log_error "purge_stow_conflicts_from_output: missing args"
        return 1
    fi
    if [[ ! -f "$output_file" ]]; then
        log_error "purge_stow_conflicts_from_output: output file not found: $output_file"
        return 1
    fi

    declare -A targets=()
    local line
    local re_cannot='\\*[[:space:]]+cannot[[:space:]]+stow[[:space:]]+.+[[:space:]]+over[[:space:]]+existing[[:space:]]+target[[:space:]]+([^[:space:]]+)[[:space:]]+since[[:space:]]+'
    local re_not_owned='\\*[[:space:]]+existing[[:space:]]+target[[:space:]]+is[[:space:]]+not[[:space:]]+owned[[:space:]]+by[[:space:]]+stow:[[:space:]]+(.+)$'
    local re_diff_pkg='\\*[[:space:]]+existing[[:space:]]+target[[:space:]]+is[[:space:]]+stowed[[:space:]]+to[[:space:]]+a[[:space:]]+different[[:space:]]+package:[[:space:]]+([^[:space:]]+)[[:space:]]+=>[[:space:]]+'

    while IFS= read -r line; do
        # Example:
        # * cannot stow ... over existing target .config/foo/bar since ...
        if [[ "$line" =~ $re_cannot ]]; then
            targets["${BASH_REMATCH[1]}"]=1
            continue
        fi

        # Example:
        # * existing target is not owned by stow: .config/foo
        if [[ "$line" =~ $re_not_owned ]]; then
            local t="${BASH_REMATCH[1]}"
            t=$(printf '%s' "$t" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
            [[ -n "$t" ]] && targets["$t"]=1
            continue
        fi

        # Example:
        # * existing target is stowed to a different package: .package => dotfiles/packages/hyprland/.package
        if [[ "$line" =~ $re_diff_pkg ]]; then
            targets["${BASH_REMATCH[1]}"]=1
            continue
        fi
    done < "$output_file"

    local removed_count=0
    local t
    for t in "${!targets[@]}"; do
        # Basic safety: stow targets are relative to $HOME
        if [[ "$t" == /* || "$t" == *".."* ]]; then
            log_warning "Conflict purge skipping unsafe target: $t"
            continue
        fi

        local dst="$HOME/$t"
        if [[ -e "$dst" || -L "$dst" ]]; then
            fresh_backup_and_remove "$dst" "$backup_root" "$package" || return 1
            removed_count=$((removed_count + 1))
        fi
    done

    if [[ $removed_count -gt 0 ]]; then
        log_warning "Purged $removed_count conflict target(s) for package '$package' (backups: ${backup_root}/${package})"
    fi
}

# Fresh-machine helper: backup and remove a path under $HOME (files, symlinks, or directories)
fresh_backup_and_remove() {
    local abs_path="$1"
    local backup_root="$2"
    local package="$3"

    if [[ -z "${abs_path:-}" || -z "${backup_root:-}" || -z "${package:-}" ]]; then
        log_error "fresh_backup_and_remove: missing args"
        return 1
    fi

    # Safety checks (never operate outside of $HOME)
    if [[ "$abs_path" == "$HOME" || "$abs_path" == "/" || "$abs_path" != "$HOME/"* ]]; then
        log_error "Fresh mode refusing to remove unsafe path: $abs_path"
        return 1
    fi

    # Determine backup destination path relative to $HOME
    local rel_from_home="${abs_path#${HOME}/}"
    if [[ -z "$rel_from_home" || "$rel_from_home" == "$abs_path" ]]; then
        log_error "Fresh mode refusing to remove (could not derive rel path): $abs_path"
        return 1
    fi

    local backup_path="${backup_root}/${package}/${rel_from_home}"
    mkdir -p "$(dirname "$backup_path")"

    # Backup first, then remove
    if cp -a "$abs_path" "$backup_path" 2>/dev/null; then
        :
    elif cp -aL "$abs_path" "$backup_path" 2>/dev/null; then
        :
    else
        log_error "Fresh mode backup failed; refusing to delete: $abs_path"
        log_error "Intended backup destination: $backup_path"
        return 1
    fi

    rm -rf "$abs_path"
}

# Fresh-machine purge: remove conflicting targets that would block stow for a given package.
# Uses `stow -n -v` to discover intended links (respects stow ignore rules).
fresh_purge_stow_conflicts_for_package() {
    local package="$1"
    local backup_root="$2"

    if [[ -z "${package:-}" || -z "${backup_root:-}" ]]; then
        log_error "fresh_purge_stow_conflicts_for_package: missing args"
        return 1
    fi

    if ! command -v stow >/dev/null 2>&1; then
        log_error "Fresh mode requires GNU Stow to be installed"
        return 1
    fi

    local dry_run
    dry_run=$(stow -n -v -t "$HOME" "$package" 2>&1 || true)

    # Track removed paths to avoid double-work (esp. parent dirs)
    declare -A removed_paths=()
    local removed_count=0

    # Prefer parsing LINK lines: `LINK: <target> => <source>`
    local link_re='^[[:space:]]*LINK:[[:space:]]+([^[:space:]]+)[[:space:]]+=>[[:space:]]+(.+)$'
    local had_link_lines=false
    local line
    while IFS= read -r line; do
        if [[ "$line" =~ $link_re ]]; then
            had_link_lines=true

            local target_rel="${BASH_REMATCH[1]}"
            local source_rel="${BASH_REMATCH[2]}"

            # Trim whitespace (stow output can sometimes include trailing spaces)
            target_rel=$(printf '%s' "$target_rel" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
            source_rel=$(printf '%s' "$source_rel" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

            # Guard against weird targets
            if [[ "$target_rel" == /* || "$target_rel" == *".."* ]]; then
                log_warning "Fresh mode skipping unexpected stow target: $target_rel"
                continue
            fi

            local dst="$HOME/$target_rel"
            local src_abs=""
            # stow prints the link source as it will appear at the destination (usually relative to $HOME)
            if [[ "$source_rel" == /* ]]; then
                src_abs=$(readlink -f "$source_rel" 2>/dev/null || true)
            else
                src_abs=$(readlink -f "$HOME/$source_rel" 2>/dev/null || true)
            fi

            # Ensure directory prefixes exist as directories (remove any file/symlink that blocks mkdir)
            local target_dir
            target_dir=$(dirname "$target_rel")
            if [[ "$target_dir" != "." && -n "$target_dir" ]]; then
                local cur="$HOME"
                local IFS='/'
                read -ra parts <<< "$target_dir"
                unset IFS
                local part
                for part in "${parts[@]}"; do
                    [[ -z "$part" ]] && continue
                    cur="$cur/$part"
                    if [[ -n "${removed_paths[$cur]:-}" ]]; then
                        continue
                    fi
                    if [[ ( -e "$cur" || -L "$cur" ) && ! -d "$cur" ]]; then
                        fresh_backup_and_remove "$cur" "$backup_root" "$package"
                        removed_paths["$cur"]=1
                        removed_count=$((removed_count + 1))
                    fi
                done
            fi

            # If destination exists but isn't already the exact intended link, back it up and remove it
            if [[ -n "${removed_paths[$dst]:-}" ]]; then
                continue
            fi

            if [[ -L "$dst" ]]; then
                local dst_abs=""
                dst_abs=$(readlink -f "$dst" 2>/dev/null || true)
                if [[ -n "$src_abs" && -n "$dst_abs" && "$src_abs" == "$dst_abs" ]]; then
                    continue
                fi
            fi

            if [[ -e "$dst" || -L "$dst" ]]; then
                fresh_backup_and_remove "$dst" "$backup_root" "$package"
                removed_paths["$dst"]=1
                removed_count=$((removed_count + 1))
            fi
        fi
    done < <(printf '%s\n' "$dry_run")

    # Fallback: if no LINK lines were found (older stow / different output), purge based on package tree
    if [[ "$had_link_lines" != "true" ]]; then
        while IFS= read -r -d '' src; do
            local rel="${src#${package}/}"
            [[ -z "$rel" || "$rel" == "$src" ]] && continue

            # Mirror stow global ignores for marker/docs files
            case "$(basename "$rel")" in
                .package|README|README.md|README.txt)
                    continue
                ;;
            esac

            # Guard against weird rel paths
            if [[ "$rel" == /* || "$rel" == *".."* ]]; then
                log_warning "Fresh mode skipping unexpected package entry: $rel"
                continue
            fi

            local dst="$HOME/$rel"

            # Ensure parent directories are directories
            local rel_dir
            rel_dir=$(dirname "$rel")
            if [[ "$rel_dir" != "." && -n "$rel_dir" ]]; then
                local cur="$HOME"
                local IFS='/'
                read -ra parts <<< "$rel_dir"
                unset IFS
                local part
                for part in "${parts[@]}"; do
                    [[ -z "$part" ]] && continue
                    cur="$cur/$part"
                    if [[ -n "${removed_paths[$cur]:-}" ]]; then
                        continue
                    fi
                    if [[ ( -e "$cur" || -L "$cur" ) && ! -d "$cur" ]]; then
                        fresh_backup_and_remove "$cur" "$backup_root" "$package"
                        removed_paths["$cur"]=1
                        removed_count=$((removed_count + 1))
                    fi
                done
            fi

            if [[ -n "${removed_paths[$dst]:-}" ]]; then
                continue
            fi

            # If destination exists but isn't already linked to this exact source, purge it
            if [[ -L "$dst" ]]; then
                local dst_abs src_abs
                dst_abs=$(readlink -f "$dst" 2>/dev/null || true)
                src_abs=$(readlink -f "$src" 2>/dev/null || true)
                if [[ -n "$dst_abs" && -n "$src_abs" && "$dst_abs" == "$src_abs" ]]; then
                    continue
                fi
            fi

            if [[ -e "$dst" || -L "$dst" ]]; then
                fresh_backup_and_remove "$dst" "$backup_root" "$package"
                removed_paths["$dst"]=1
                removed_count=$((removed_count + 1))
            fi
        done < <(find "$package" -mindepth 1 \( -type f -o -type l \) -print0 2>/dev/null)
    fi

    if [[ $removed_count -gt 0 ]]; then
        log_warning "Fresh mode purged $removed_count existing target(s) for package '$package' (backups: ${backup_root}/${package})"
    fi
}

# Install packages
install_packages() {
    if [[ "$INSTALL_PACKAGES" != "true" ]]; then
        return 0
    fi
    
    log_step "Installing packages..."

    local deps_manifest="$SCRIPT_DIR/scripts/install/deps.manifest.toml"
    local manifest_fingerprint="no-manifest"
    if [[ -f "$deps_manifest" ]]; then
        if command -v sha256sum >/dev/null 2>&1; then
            manifest_fingerprint=$(sha256sum "$deps_manifest" | awk '{print substr($1,1,12)}')
        elif command -v shasum >/dev/null 2>&1; then
            manifest_fingerprint=$(shasum -a 256 "$deps_manifest" | awk '{print substr($1,1,12)}')
        fi
    fi

    # Include installer logic fingerprint so changes to install-deps.sh invalidate cached "packages installed"
    # (prevents stale state from hiding missing packages like waybar).
    local install_script="$SCRIPTS_DIR/install/install-deps.sh"
    local installer_fingerprint="no-installer"
    if [[ -f "$install_script" ]]; then
        if command -v sha256sum >/dev/null 2>&1; then
            installer_fingerprint=$(sha256sum "$install_script" | awk '{print substr($1,1,12)}')
        elif command -v shasum >/dev/null 2>&1; then
            installer_fingerprint=$(shasum -a 256 "$install_script" | awk '{print substr($1,1,12)}')
        fi
    fi

    local feature_fingerprint=""
    if [[ -n "${HOST:-}" ]] && is_hyprland_host "$HOSTS_DIR" "$HOST"; then
        feature_fingerprint="hyprland"
    else
        feature_fingerprint="nohypr"
    fi

    local step_id="install:${HOST:-generic}:packages:${feature_fingerprint}:${manifest_fingerprint}:${installer_fingerprint}"
    if [[ "$RESET_PACKAGES" == "true" ]]; then
        reset_host_package_steps "${HOST:-generic}"
        reset_step "$step_id" 2>/dev/null || true
    fi

    if is_step_completed "$step_id"; then
        if packages_sanity_ok "${HOST:-}"; then
            log_info "Skipping $step_id (already completed)"
            return 0
        fi
        log_warning "Package step marked completed, but required commands are missing; re-running package install."
        reset_step "$step_id" 2>/dev/null || true
    fi
    
    if [[ -f "$install_script" ]]; then
        # Ensure the script is executable
        chmod +x "$install_script"

        # IMPORTANT: `install-deps.sh` runs setup scripts which may create dotfiles under ~/.config.
        # When we intend to stow dotfiles in this run, we skip that phase and run it *after* stow
        # so stow-managed files don't conflict with pre-created regular files.
        local deps_flags=("${INSTALL_DEPS_FLAGS[@]}")
        if [[ "$INSTALL_DOTFILES" == "true" ]]; then
            deps_flags+=("--no-setup")
        fi
        
        # Pass the host argument if it's set
        if [[ -n "$HOST" ]]; then
            "$install_script" "${deps_flags[@]}" --host "$HOST"
        else
            "$install_script" "${deps_flags[@]}"
        fi
    else
        log_error "Package installation script not found: $install_script"
        exit 1
    fi
    
    mark_step_completed "$step_id"
    log_success "Package installation completed"
}

# Optional Utilities setup (symlink selected utilities into ~/.local/bin)
setup_utilities() {
    if [[ "$SETUP_UTILITIES" != "true" ]]; then
        return 0
    fi
    
    log_step "Setting up utilities (symlinking into ~/.local/bin)..."
    mkdir -p "$HOME/.local/bin"
    
    declare -A util_map=(
        ["launch-clipse.sh"]="launch-clipse"
        ["netbird-install.sh"]="netbird-install"
        ["web-apps.sh"]="web-apps"
        ["docker-dbs.sh"]="docker-dbs"
        ["nfs.sh"]="nfs-utils"
    )
    
    for src in "${!util_map[@]}"; do
        if [[ -f "$SCRIPTS_DIR/utilities/$src" ]]; then
            ln -sf "$SCRIPTS_DIR/utilities/$src" "$HOME/.local/bin/${util_map[$src]}"
            chmod +x "$SCRIPTS_DIR/utilities/$src" || true
            log_success "Symlinked ${util_map[$src]}"
        else
            log_warning "Utility not found: $SCRIPTS_DIR/utilities/$src"
        fi
    done
    
    log_success "Utilities setup completed"
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

    # Ensure package-local bin links are up to date before stow
    local sync_script="$SCRIPTS_DIR/tools/sync-bin-links"
    if [[ -x "$sync_script" ]]; then
        log_step "Syncing package bin links..."
        if "$sync_script"; then
            log_success "Package bin links synced"
        else
            log_warning "sync-bin-links failed (continuing with stow)"
        fi
    else
        log_warning "sync-bin-links not found or not executable: $sync_script"
    fi
    
    # Change to packages directory
    cd "$PACKAGES_DIR"

    local fresh_backup_root=""
    local conflict_backup_root=""
    if [[ "$FRESH_MODE" == "true" ]]; then
        local ts
        ts=$(date +%Y%m%d-%H%M%S)
        fresh_backup_root="$HOME/.local/state/dotfiles/backups/${ts}/fresh-mode"
        log_warning "Fresh machine mode enabled: conflicting dotfile targets will be backed up+removed before stow"
        log_warning "Fresh mode backups will be stored under: $fresh_backup_root"
    fi
    
    # Auto-discover packages with .package marker file
    # This allows seamless addition/removal of packages without editing this script
    local packages=()
    while IFS= read -r -d '' package_file; do
        local package_dir
        local package_name
        
        package_dir=$(dirname "$package_file")
        package_name=$(basename "$package_dir")
        packages+=("$package_name")
        
    done < <(find "$PACKAGES_DIR" -maxdepth 2 -type f -name ".package" -printf "%p\0" 2>/dev/null | sort -z)
    
    # If no packages found with marker files, log warning
    if [[ ${#packages[@]} -eq 0 ]]; then
        log_warning "No packages found with .package marker files"
        log_info "To enable a package, create a .package file in its directory:"
        log_info "  touch packages/PACKAGE_NAME/.package"
        return 0
    fi
    
    log_info "Found ${#packages[@]} package(s) to install"
    
    # Install each package
    for package in "${packages[@]}"; do
        if [[ -d "$package" ]]; then
            log_info "Installing dotfiles package: $package"

            # Safety: never stow system-scoped packages into $HOME.
            # Packages are enabled by `.package`; system packages declare `scope=system` inside that file.
            if [[ -f "$PACKAGES_DIR/$package/.package" ]] && grep -Eq '^[[:space:]]*scope[[:space:]]*[:=][[:space:]]*system[[:space:]]*$' "$PACKAGES_DIR/$package/.package"; then
                log_info "Skipping '$package' for user-level stow (scope=system; handled by stow-system.sh)"
                continue
            fi

            if [[ "$FRESH_MODE" == "true" ]]; then
                fresh_purge_stow_conflicts_for_package "$package" "$fresh_backup_root"
            fi
            
            # Handle absolute symlinks in package source (stow can't handle them)
            # Temporarily remove symlinks that point outside the package directory (these are runtime-managed)
            # Store them for restoration after stowing
            declare -A removed_symlinks=()
            while IFS= read -r -d '' symlink_path; do
                if [[ -L "$symlink_path" ]]; then
                    local link_target
                    link_target=$(readlink "$symlink_path")
                    # If it's an absolute symlink pointing outside the package, temporarily remove it
                    if [[ "$link_target" == /* ]]; then
                        local pkg_abs="$(readlink -f "$package")"
                        local link_target_abs
                        link_target_abs=$(readlink -f "$link_target" 2>/dev/null || echo "$link_target")
                        
                        # Check if target is outside the package directory
                        if [[ "$link_target_abs" != "$pkg_abs"/* ]]; then
                            # Store the symlink target for restoration
                            removed_symlinks["$symlink_path"]="$link_target"
                            log_info "Temporarily removing absolute symlink pointing outside package: $(basename "$symlink_path") -> $link_target"
                            rm "$symlink_path"
                            continue
                        fi
                        
                        # Target is inside package - try to make it relative
                        local symlink_abs="$(readlink -f "$symlink_path")"
                        local symlink_dir="$(dirname "$symlink_abs")"
                        local rel_target
                        if rel_target=$(realpath --relative-to="$symlink_dir" "$link_target" 2>/dev/null); then
                            log_info "Resolving absolute symlink in $package: $(basename "$symlink_path") -> $rel_target"
                            rm "$symlink_path"
                            ln -s "$rel_target" "$symlink_path"
                        else
                            log_warning "Cannot resolve absolute symlink in $package: $symlink_path -> $link_target"
                        fi
                    fi
                fi
            done < <(find "$package" -type l -print0 2>/dev/null)
            
            # Try stowing with restow (handles existing symlinks)
            #
            # Important: some packages (notably `zsh`) are meant to be *extended* by host-specific dotfiles
            # under the same directory tree (e.g. hosts/<host>/dotfiles/.config/zsh/**). If the base package
            # is "folded" into a single directory symlink (e.g. ~/.config/zsh -> dotfiles/packages/zsh/.config/zsh),
            # then host-specific stow cannot place files under it.
            #
            # So we stow `zsh` with --no-folding (file-by-file) and do a one-time clean unstow/restow
            # to migrate away from an existing folded directory link.
            local stow_args=(--restow -t "$HOME")
            if [[ "$package" == "zsh" ]]; then
                stow_args=(--no-folding --restow -t "$HOME")
                # Best-effort remove any previous folded layout so we can recreate file-by-file links.
                stow -D -t "$HOME" "$package" >/dev/null 2>&1 || true
            fi
            local stow_ec=0
            set +e
            stow "${stow_args[@]}" "$package" 2>&1 | tee /tmp/stow_output.txt
            stow_ec=${PIPESTATUS[0]}
            set -e

            local has_conflict="false"
            if grep -qi "conflict\\|would cause conflicts" /tmp/stow_output.txt; then
                has_conflict="true"
            fi

            if [[ "$has_conflict" == "true" ]]; then
                log_warning "$package has conflicts:"
                grep -i "conflict\\|would cause" /tmp/stow_output.txt | sed 's/^/  /' || true

                if [[ "$FRESH_MODE" == "true" ]]; then
                    log_info "Fresh mode: backing up+removing conflicting targets and retrying stow..."
                    purge_stow_conflicts_from_output "$package" "$fresh_backup_root" /tmp/stow_output.txt
                else
                    # Even on non-fresh machines, resolve stow conflicts by backing up and removing only the
                    # targets that this package would manage. This makes installs idempotent and avoids
                    # requiring a second run / manual deletions.
                    if [[ -z "$conflict_backup_root" ]]; then
                        local ts
                        ts=$(date +%Y%m%d-%H%M%S)
                        conflict_backup_root="$HOME/.local/state/dotfiles/backups/${ts}/stow-conflicts"
                    fi
                    log_warning "Auto-resolving stow conflicts for '$package' (backup+remove conflicting targets, then retry)"
                    log_warning "Conflict backups will be stored under: $conflict_backup_root"
                    purge_stow_conflicts_from_output "$package" "$conflict_backup_root" /tmp/stow_output.txt
                fi

                set +e
                stow "${stow_args[@]}" "$package" 2>&1 | tee /tmp/stow_output_retry.txt
                stow_ec=${PIPESTATUS[0]}
                set -e

                has_conflict="false"
                if grep -qi "conflict\\|would cause conflicts" /tmp/stow_output_retry.txt; then
                    has_conflict="true"
                fi

                if [[ $stow_ec -eq 0 && "$has_conflict" != "true" ]]; then
                    if [[ "$FRESH_MODE" == "true" ]]; then
                        log_success "Installed $package dotfiles (fresh mode)"
                    else
                        log_success "Installed $package dotfiles (after conflict auto-resolve)"
                    fi
                else
                    # Check if it's an absolute symlink issue that we can't resolve
                    if grep -qi "absolute symlink" /tmp/stow_output_retry.txt; then
                        log_warning "Package '$package' has absolute symlinks that cannot be resolved automatically"
                        log_info "You may need to manually fix symlinks in packages/$package/"
                        log_info "Backups (if any): ${fresh_backup_root:-${conflict_backup_root}}/${package}"
                    else
                        log_error "Failed to install $package even after conflict auto-resolve"
                        grep -i "conflict\\|would cause" /tmp/stow_output_retry.txt | sed 's/^/  /' || true
                        if [[ "$FRESH_MODE" == "true" ]]; then
                            log_info "Backups (if any): ${fresh_backup_root}/${package}"
                        else
                            log_info "Backups (if any): ${conflict_backup_root}/${package}"
                        fi
                    fi
                fi

                rm -f /tmp/stow_output_retry.txt
            elif [[ $stow_ec -ne 0 ]]; then
                log_error "Stow failed for package '$package' (exit $stow_ec)"
                sed 's/^/  /' /tmp/stow_output.txt || true
            else
                log_success "Installed $package dotfiles"
            fi
            
            # Restore temporarily removed absolute symlinks that point outside the package
            for symlink_path in "${!removed_symlinks[@]}"; do
                if [[ ! -e "$symlink_path" ]]; then
                    local link_target="${removed_symlinks[$symlink_path]}"
                    log_info "Restoring absolute symlink: $(basename "$symlink_path") -> $link_target"
                    ln -s "$link_target" "$symlink_path"
                fi
            done
            
            # Cleanup temp file
            rm -f /tmp/stow_output.txt
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
    local stow_script="$SCRIPTS_DIR/install/stow-system.sh"
    if [[ -f "$stow_script" ]]; then
        chmod +x "$stow_script"
        if [[ $EUID -eq 0 ]]; then
            "$stow_script"
        else
            sudo "$stow_script"
        fi
    else
        log_warning "stow-system.sh not found, skipping system package stowing."
    fi
}

stow_host_dotfiles() {
    local dotfiles_dir="$1"
    local host="$2"

    if ! command -v stow >/dev/null 2>&1; then
        log_warning "Stow not available for host-specific dotfiles"
        return 0
    fi

    if [[ ! -d "$dotfiles_dir" ]]; then
        return 0
    fi

    local ts
    ts=$(date +%Y%m%d-%H%M%S)
    local backup_root="$HOME/.local/state/dotfiles/backups/${ts}/host-dotfiles/${host}"
    local had_backups="false"

    # Pre-flight: back up and remove any existing targets that would block stow.
    # We only touch non-directories (files/symlinks). If a directory/file type mismatch exists,
    # we fail fast so the user can resolve it intentionally.
    local src rel dst
    while IFS= read -r -d '' src; do
        rel="${src#${dotfiles_dir}/}"
        [[ -z "$rel" || "$rel" == "$src" ]] && continue

        dst="$HOME/$rel"

        # If the source is a file/symlink but destination is a directory, that's a structural conflict.
        if [[ -d "$dst" && ! -L "$dst" ]]; then
            log_warning "Host dotfiles stow conflict: destination is a directory but source is a file: $dst"
            log_info "Backing up directory and removing it..."
            had_backups="true"
            mkdir -p "$backup_root/$(dirname "$rel")"
            cp -a "$dst" "$backup_root/$rel" 2>/dev/null || cp -aL "$dst" "$backup_root/$rel" 2>/dev/null || true
            rm -rf "$dst"
            continue
        fi

        # If destination doesn't exist (including broken symlink), nothing to do.
        if [[ ! -e "$dst" && ! -L "$dst" ]]; then
            continue
        fi

        # If destination already points to this exact source, keep it.
        if [[ -L "$dst" ]]; then
            local dst_target
            dst_target=$(readlink "$dst" 2>/dev/null || true)
            if [[ "$dst_target" == /* ]]; then
                # Absolute symlinks are rejected by stow; convert them by removing now.
                had_backups="true"
                mkdir -p "$backup_root/$(dirname "$rel")"
                cp -a "$dst" "$backup_root/$rel" 2>/dev/null || cp -aL "$dst" "$backup_root/$rel" 2>/dev/null || true
                rm -f "$dst"
                continue
            fi

            local dst_resolved src_resolved
            dst_resolved=$(readlink -f "$dst" 2>/dev/null || true)
            src_resolved=$(readlink -f "$src" 2>/dev/null || true)
            if [[ -n "$dst_resolved" && -n "$src_resolved" && "$dst_resolved" == "$src_resolved" ]]; then
                continue
            fi
        fi

        had_backups="true"
        mkdir -p "$backup_root/$(dirname "$rel")"
        cp -a "$dst" "$backup_root/$rel" 2>/dev/null || cp -aL "$dst" "$backup_root/$rel" 2>/dev/null || true
        rm -f "$dst"
    done < <(find "$dotfiles_dir" -mindepth 1 \( -type f -o -type l \) -print0 2>/dev/null)

    if [[ "$had_backups" == "true" ]]; then
        log_warning "Backed up conflicting host-dotfile targets to: $backup_root"
    fi

    log_info "Installing host-specific dotfiles (stow) from: $dotfiles_dir"
    # Use --no-folding to avoid attempting to replace existing directories (e.g. ~/.config/zsh)
    # with a single directory symlink; instead, stow will link individual files under the dir.
    set +e
    (cd "$dotfiles_dir" && stow --no-folding -t "$HOME" -R . 2>&1 | tee /tmp/stow_host_output.txt)
    local stow_ec=${PIPESTATUS[0]}
    set -e
    
    if [[ $stow_ec -ne 0 ]]; then
        if grep -qi "conflict\\|would cause conflicts" /tmp/stow_host_output.txt; then
            log_warning "Host dotfiles stow had conflicts (see above). Some files may not be installed."
        else
            log_error "Host dotfiles stow failed with exit code $stow_ec"
        fi
        rm -f /tmp/stow_host_output.txt
        return 1
    fi
    rm -f /tmp/stow_host_output.txt
}

# Setup host-specific configuration
setup_host_config() {
    if [[ -z "$HOST" ]]; then
        HOST=$(detect_host "$HOSTS_DIR")
    fi
    
    log_step "Setting up host-specific configuration for: $HOST"
    
    local host_config_dir="$HOSTS_DIR/$HOST"
    
    if [[ -d "$host_config_dir" ]]; then
        log_info "Loading host-specific configuration from $host_config_dir"
        
        # Stow host-specific system files first
        stow_system_packages
        
        # Source host-specific setup script if it exists
        if [[ -f "$host_config_dir/setup.sh" ]]; then
            log_info "Running host-specific setup script..."
            if [[ "$RESET_STATE" == "true" ]]; then
                bash "$host_config_dir/setup.sh" --reset
            else
                bash "$host_config_dir/setup.sh"
            fi
        fi
        
        # Install host-specific dotfiles if they exist
        if [[ -d "$host_config_dir/dotfiles" ]]; then
            stow_host_dotfiles "$host_config_dir/dotfiles" "$HOST"
        fi
        
        log_success "Host-specific configuration completed"
    else
        log_warning "No host-specific configuration found for $HOST"
    fi
}

refresh_icon_cache() {
    local cache_root="/usr/share/icons/hicolor"

    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
        log_info "Refreshing GTK icon cache..."
        local cmd=(gtk-update-icon-cache -f "$cache_root")
        if [[ $EUID -eq 0 ]]; then
            "${cmd[@]}"
        else
            sudo "${cmd[@]}"
        fi
        return 0
    fi

    if command -v xdg-icon-resource >/dev/null 2>&1; then
        log_info "Refreshing icon resources via xdg-icon-resource..."
        local cmd=(xdg-icon-resource forceupdate --theme hicolor)
        if [[ $EUID -eq 0 ]]; then
            "${cmd[@]}"
        else
            sudo "${cmd[@]}"
        fi
        return 0
    fi

    log_warning "No icon cache refresh command available (gtk-update-icon-cache or xdg-icon-resource)"
    return 0
}

deploy_dragon_icons() {
    log_step "Deploying Dragon Control icons..."

    local generator="$SCRIPTS_DIR/theme-manager/dragon-icons.sh"
    if [[ ! -x "$generator" ]]; then
        log_error "Dragon icon generator not found at $generator"
        return 1
    fi

    # Asset generation is intentionally idempotent:
    # - We only (re)generate icon variants if any are missing from the repo assets folder.
    # - We track completion in install-state so subsequent installer runs don't redo work.
    local assets_step_id="assets:dragon-icons"
    local assets_root="$CONFIG_DIR/assets/dragon/icons/hicolor"
    local expected_sizes=(16 24 32 48 64 96 128 192 256 512)

    local missing_any="false"
    local size icon_path
    for size in "${expected_sizes[@]}"; do
        icon_path="${assets_root}/${size}x${size}/apps/dragon-control.png"
        if [[ ! -f "$icon_path" ]]; then
            missing_any="true"
            break
        fi
    done

    if [[ "$missing_any" != "true" ]]; then
        if is_step_completed "$assets_step_id"; then
            log_info "Dragon icon assets already generated; skipping generation ($assets_step_id)"
        else
            log_info "Dragon icon assets already present; marking generation step completed ($assets_step_id)"
            mark_step_completed "$assets_step_id"
        fi
    else
        # If assets are missing, re-run generation even if a previous run marked the step complete.
        log_info "Dragon icon assets missing; generating icon variants..."
        "$generator"

        # Verify generation succeeded (fail fast if the generator didn't actually produce outputs)
        for size in "${expected_sizes[@]}"; do
            icon_path="${assets_root}/${size}x${size}/apps/dragon-control.png"
            if [[ ! -f "$icon_path" ]]; then
                log_error "Dragon icon generation incomplete; missing expected asset: $icon_path"
                return 1
            fi
        done
        mark_step_completed "$assets_step_id"
    fi

    local src_root="$CONFIG_DIR/assets/dragon/icons/hicolor"
    local dst_root="/usr/share/icons/hicolor"

    if [[ ! -d "$src_root" ]]; then
        log_error "Icon assets directory missing at $src_root"
        return 1
    fi

    local copied=false
    while IFS= read -r -d '' src; do
        local rel="${src#$src_root/}"
        if [[ -z "$rel" || "$rel" == "$src" ]]; then
            continue
        fi
        local dst="$dst_root/$rel"
        if [[ $EUID -eq 0 ]]; then
            install -Dm644 "$src" "$dst"
        else
            sudo install -Dm644 "$src" "$dst"
        fi
        copied=true
    done < <(find "$src_root" -type f -name "dragon-control.png" -print0)

    if [[ "$copied" != "true" ]]; then
        log_error "No Dragon icon variants were staged for installation"
        return 1
    fi

    refresh_icon_cache
    log_success "Dragon Control icons deployed"
}

deploy_icon_aliases() {
    # Some apps (notably on CachyOS) ship .desktop files referencing icon names that may not exist
    # in the active icon theme. When the icon name doesn't exist, Waybar tray + Walker show a blank square.
    #
    # We create safe aliases in hicolor so any icon theme can resolve them.
    log_step "Deploying icon aliases..."

    local dst_dir="/usr/share/icons/hicolor/scalable/apps"
    local aliases=(
        # cachy-update ships color-variant icons, but some tray clients request the base name
        "cachy-update.svg:cachy-update-blue.svg"
        "cachy-update_updates-available.svg:cachy-update_updates-available-blue.svg"

        # arch-update references these names but does not ship the icons; alias to cachy-update equivalents
        "arch-update-blue.svg:cachy-update-blue.svg"
        "arch-update_updates-available-blue.svg:cachy-update_updates-available-blue.svg"
    )

    local did_any=false
    local pair dst_name src_name src_path dst_path
    for pair in "${aliases[@]}"; do
        dst_name="${pair%%:*}"
        src_name="${pair##*:}"
        src_path="$dst_dir/$src_name"
        dst_path="$dst_dir/$dst_name"

        # Only create alias if destination is missing and source exists
        if [[ ! -e "$dst_path" && -e "$src_path" ]]; then
            if [[ $EUID -eq 0 ]]; then
                ln -s "$src_name" "$dst_path"
            else
                sudo ln -s "$src_name" "$dst_path"
            fi
            did_any=true
            log_success "Aliased icon: $dst_name -> $src_name"
        fi
    done

    if [[ "$did_any" == "true" ]]; then
        refresh_icon_cache
        log_success "Icon aliases deployed"
    else
        log_info "No icon aliases needed"
    fi
}

deploy_icon_png_fallbacks() {
    # Some environments still fail to render SVG icons in certain tray clients.
    # Generate small PNG fallbacks for the common update icons so Waybar's tray can always display them.
    log_step "Deploying icon PNG fallbacks..."

    if ! command -v rsvg-convert >/dev/null 2>&1; then
        log_warning "rsvg-convert not available; skipping PNG fallback generation"
        return 0
    fi

    local src_dir="/usr/share/icons/hicolor/scalable/apps"
    local dst_root="/usr/share/icons/hicolor"

    # name:source_svg
    local icons=(
        "cachy-update:${src_dir}/cachy-update-blue.svg"
        "cachy-update_updates-available:${src_dir}/cachy-update_updates-available-blue.svg"
    )
    local sizes=(16 22 24 32)

    local did_any=false
    local entry name src size outdir outfile tmp
    for entry in "${icons[@]}"; do
        name="${entry%%:*}"
        src="${entry##*:}"
        [[ -f "$src" ]] || continue

        for size in "${sizes[@]}"; do
            outdir="${dst_root}/${size}x${size}/apps"
            outfile="${outdir}/${name}.png"
            if [[ -e "$outfile" ]]; then
                continue
            fi

            tmp="$(mktemp --suffix=.png /tmp/${name}-${size}.XXXXXX 2>/dev/null || mktemp /tmp/${name}-${size}.XXXXXX)"
            if rsvg-convert -w "$size" -h "$size" "$src" -o "$tmp" >/dev/null 2>&1; then
                if [[ $EUID -eq 0 ]]; then
                    install -Dm644 "$tmp" "$outfile"
                else
                    sudo install -Dm644 "$tmp" "$outfile"
                fi
                did_any=true
                log_success "Generated PNG: ${size}x${size} ${name}.png"
            fi
            rm -f "$tmp" 2>/dev/null || true
        done
    done

    if [[ "$did_any" == "true" ]]; then
        refresh_icon_cache
        log_success "Icon PNG fallbacks deployed"
    else
        log_info "No icon PNG fallbacks needed"
    fi
}

# Setup secrets management
setup_secrets() {
    if [[ "$SETUP_SECRETS" != "true" || "$SKIP_SECRETS" == "true" ]]; then
        return 0
    fi
    
    log_step "Setting up secrets management..."
    
    if [[ -x "$SCRIPTS_DIR/utilities/secrets.sh" ]]; then
        "$SCRIPTS_DIR/utilities/secrets.sh" setup
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
        # shellcheck disable=SC1091
        source "$HOME/.zshrc" 2>/dev/null || true
    fi
    
    # Install additional tools
    if [[ -x "$SCRIPTS_DIR/install/setup/post-install.sh" ]]; then
        log_info "Running post-installation script..."
        "$SCRIPTS_DIR/install/setup/post-install.sh"
    fi
    
    
    #bash "$SCRIPTS_DIR/theme-manager/theme-set" "tokyo-night"
    bash "$SCRIPTS_DIR/install/setup/keyboard.sh"
    
    log_success "Post-setup tasks completed"
}

# Validate installation
validate_installation() {
    log_step "Validating installation..."
    
    # Quick validation for host-specific setup
    log_info "Running quick validation..."
    
    local essential_files=("$HOME/.zshrc")
    local essential_commands=("zsh" "git" "stow")
    
    for file in "${essential_files[@]}"; do
        if [[ -f "$file" || -L "$file" ]]; then
            log_success "✓ $file exists"
        else
            log_warning "✗ $file missing"
        fi
    done
    
    for cmd in "${essential_commands[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            log_success "✓ $cmd is available"
        else
            log_warning "✗ $cmd not found"
        fi
    done
    
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
        echo "  • Use './scripts/utilities/secrets.sh --help' for secrets management"
        echo "  • Configure age keys if not already done"
        echo
    fi
    
    log_info "For updates and maintenance:"
    echo "  • Use './scripts/install/update.sh' to update packages and configs"
    echo "  • Use './scripts/install/validate.sh' to check system health"
    echo "  • Use 'stow -D <package>' to remove specific dotfiles"
    echo
}

# Main execution function
main() {
    echo
    log_info "🚀 Starting Dotfiles Management Setup"
    log_info "Configuration directory: $CONFIG_DIR"
    echo
    
    # Handle --reset flag to clear installation state
    if [[ "$RESET_STATE" == "true" ]]; then
        log_warning "⚠️  Resetting installation state..."
        reset_all_steps
        log_success "Installation state cleared. All steps will run fresh."
        echo
    fi
    
    # Detect host if not specified via arguments
    if [[ -z "$HOST" ]]; then
        HOST=$(detect_host "$HOSTS_DIR")
        log_info "No host specified, detected host: $HOST"
    fi
    
    # Run setup steps
    check_prerequisites
    maybe_enable_fresh_mode
    install_packages
    setup_dotfiles

    # Run setup orchestration after dotfiles are stowed so setup scripts don't create conflicting files
    # which would block stow on first run.
    if [[ "$PACKAGES_ONLY" != "true" && "$DOTFILES_ONLY" != "true" && "$SECRETS_ONLY" != "true" ]]; then
        if [[ -x "$SCRIPTS_DIR/install/setup.sh" ]]; then
            log_info "Running setup orchestration (post-stow)..."
            bash "$SCRIPTS_DIR/install/setup.sh" || log_warning "Setup orchestration failed"
        else
            log_warning "Setup orchestration script not found at: $SCRIPTS_DIR/install/setup.sh"
        fi
    fi

    setup_host_config
    
    if [[ "$RUN_THEME" == "true" ]]; then
        log_info "Setting plymouth theme..."
        bash "$SCRIPTS_DIR/theme-manager/refresh-plymouth" -y
        
        # Setup SDDM themes if SDDM is installed
        if command -v sddm >/dev/null 2>&1; then
            log_info "Setting up SDDM themes..."
            if [[ -x "$SCRIPTS_DIR/theme-manager/refresh-sddm" ]]; then
                bash "$SCRIPTS_DIR/theme-manager/refresh-sddm" -y
                
                # Set a default theme if not already configured
                if [[ -x "$SCRIPTS_DIR/theme-manager/sddm-set" ]]; then
                    # Check if SDDM theme is already configured
                    if [[ ! -f /etc/sddm.conf.d/10-theme.conf ]]; then
                        log_info "Setting default SDDM theme to catppuccin-mocha-sky-sddm..."
                        bash "$SCRIPTS_DIR/theme-manager/sddm-set" "catppuccin-mocha-sky-sddm"
                    else
                        log_info "SDDM theme already configured, skipping..."
                    fi
                fi
            else
                log_warning "refresh-sddm script not found, skipping SDDM theme setup"
            fi
        else
            log_info "SDDM not installed, skipping SDDM theme setup"
        fi
    else
        log_info "Skipping theme refresh (--no-theme)"
    fi

    deploy_dragon_icons
    deploy_icon_aliases
    deploy_icon_png_fallbacks
    
    if [[ "$RUN_SHELL_CONFIG" == "true" ]]; then
        configure_shell
    else
        log_info "Skipping shell configuration (--no-shell)"
    fi
    
    if [[ "$RUN_POST_SETUP" == "true" ]]; then
        post_setup
    else
        log_info "Skipping post-setup tasks (--no-post-setup)"
    fi
    
    setup_utilities
    setup_secrets
    validate_installation
    
    # System configuration (requires root)
    if [[ "$NO_SYSTEM_CONFIG" != "true" && "$PACKAGES_ONLY" != "true" && "$DOTFILES_ONLY" != "true" && "$SECRETS_ONLY" != "true" ]]; then
        log_info "Setting up system-level configuration..."
        if [[ $EUID -eq 0 ]]; then
            log_info "Running system configuration as root..."
            "$SCRIPTS_DIR/install/system-config.sh" || log_warning "System configuration failed"
        else
            log_info "System configuration requires root privileges. You will be prompted for your password..."
            if sudo -v 2>/dev/null; then
                log_info "Running system configuration with sudo..."
                sudo bash "$SCRIPTS_DIR/install/system-config.sh" || log_warning "System configuration failed"
            else
                log_error "Failed to authenticate with sudo. System configuration will be skipped."
                log_info "To install system configurations later, run:"
                log_info "  sudo bash $SCRIPTS_DIR/install/system-config.sh"
                log_info ""
                log_info "Or install PAM configuration separately:"
                log_info "  sudo bash $SCRIPTS_DIR/install/setup/install-pam-hyprlock.sh"
            fi
        fi
        echo
    else
        if [[ "$PACKAGES_ONLY" != "true" && "$DOTFILES_ONLY" != "true" && "$SECRETS_ONLY" != "true" ]]; then
            log_warning "System configuration skipped due to --no-system-config flag"
            log_info "To install PAM configuration for hyprlock manually, run:"
            log_info "  sudo $SCRIPTS_DIR/install/setup/install-pam-hyprlock.sh"
        fi
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

