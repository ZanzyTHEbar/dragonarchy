#!/usr/bin/env bash
#
# Installation State Tracking Library
#
# Provides idempotency for installation steps by tracking completed tasks.
# Steps are tracked using marker files in the state directory.
#
# Usage:
#   source "${SCRIPT_DIR}/scripts/lib/install-state.sh"
#
#   if ! is_step_completed "install-liquidctl"; then
#       # Install liquidctl...
#       mark_step_completed "install-liquidctl"
#   else
#       log_info "liquidctl already installed, skipping..."
#   fi

# State directory for tracking completed steps
STATE_DIR="${HOME}/.local/state/dotfiles/install"
mkdir -p "$STATE_DIR"

# Check if a step has been completed
# Args: step_name
# Returns: 0 if completed, 1 if not completed
is_step_completed() {
    local step_name="$1"
    [[ -f "${STATE_DIR}/${step_name}" ]]
}

# Mark a step as completed
# Args: step_name
mark_step_completed() {
    local step_name="$1"
    touch "${STATE_DIR}/${step_name}"
}

# Force re-run a step by removing its completion marker
# Args: step_name
reset_step() {
    local step_name="$1"
    rm -f "${STATE_DIR}/${step_name}"
}

# Reset all installation steps
reset_all_steps() {
    log_warning "Resetting all installation state..."
    rm -rf "${STATE_DIR}"
    mkdir -p "${STATE_DIR}"
    log_success "All installation state reset"
}

# Check if files have changed (using checksums)
# Args: source_file destination_file
# Returns: 0 if files differ, 1 if files are the same
files_differ() {
    local src="$1"
    local dest="$2"
    
    # If destination doesn't exist, files differ
    [[ ! -f "$dest" ]] && return 0
    
    # Compare checksums
    local src_sum dest_sum
    src_sum=$(sha256sum "$src" 2>/dev/null | cut -d' ' -f1)
    dest_sum=$(sha256sum "$dest" 2>/dev/null | cut -d' ' -f1)
    
    [[ "$src_sum" != "$dest_sum" ]]
}

# Check if directory contents have changed
# Args: source_dir destination_dir
# Returns: 0 if directories differ, 1 if they are the same
dirs_differ() {
    local src="$1"
    local dest="$2"
    
    # If destination doesn't exist, dirs differ
    [[ ! -d "$dest" ]] && return 0
    
    # Use rsync dry-run to check for differences
    if rsync -rcn --out-format="%n" "$src/" "$dest/" 2>/dev/null | grep -q .; then
        return 0  # Differences found
    else
        return 1  # No differences
    fi
}

# DEPRECATED: Use sysmod_install_file from system-mods.sh instead.
# Kept for backward compatibility; will be removed in a future release.
copy_if_changed() {
    log_warning "DEPRECATED: copy_if_changed() — use sysmod_install_file() instead"
    local src="$1"
    local dest="$2"
    local owner="${3:-}"
    
    if files_differ "$src" "$dest"; then
        mkdir -p "$(dirname "$dest")"
        sudo cp "$src" "$dest"
        [[ -n "$owner" ]] && sudo chown "$owner" "$dest"
        return 0
    else
        return 1
    fi
}

# DEPRECATED: Use sysmod_install_dir from system-mods.sh instead.
# Kept for backward compatibility; will be removed in a future release.
copy_dir_if_changed() {
    log_warning "DEPRECATED: copy_dir_if_changed() — use sysmod_install_dir() instead"
    local src="$1"
    local dest="$2"
    local owner="${3:-}"
    
    if dirs_differ "$src" "$dest"; then
        sudo cp -rT "$src" "$dest"
        [[ -n "$owner" ]] && sudo chown -R "$owner" "$dest"
        return 0
    else
        return 1
    fi
}

# Check if a systemd service is installed and enabled
# Args: service_name
# Returns: 0 if installed and enabled, 1 otherwise
is_service_installed() {
    local service="$1"
    
    # Check if service unit file exists
    [[ -f "/etc/systemd/system/${service}" || -f "/usr/lib/systemd/system/${service}" ]] || return 1
    
    # Check if service is enabled
    systemctl is-enabled "$service" &>/dev/null
}

# DEPRECATED: Use sysmod_ensure_service from system-mods.sh instead.
# Kept for backward compatibility; will be removed in a future release.
install_service() {
    log_warning "DEPRECATED: install_service() — use sysmod_ensure_service() instead"
    local src="$1"
    local service_name="$2"
    local needs_restart=false
    
    if copy_if_changed "$src" "/etc/systemd/system/${service_name}"; then
        needs_restart=true
    fi
    
    if [[ "$needs_restart" == "true" ]]; then
        sudo systemctl daemon-reload
    fi
    
    if ! systemctl is-enabled "$service_name" &>/dev/null; then
        sudo systemctl enable "$service_name"
        needs_restart=true
    fi
    
    if ! systemctl is-active "$service_name" &>/dev/null; then
        sudo systemctl start "$service_name"
        elif [[ "$needs_restart" == "true" ]]; then
        sudo systemctl restart "$service_name"
    fi
}

# DEPRECATED: Use sysmod_restart_if_running from system-mods.sh instead.
# Kept for backward compatibility; will be removed in a future release.
restart_if_running() {
    log_warning "DEPRECATED: restart_if_running() — use sysmod_restart_if_running() instead"
    local service="$1"
    
    if systemctl is-active "$service" &>/dev/null; then
        sudo systemctl restart "$service"
        return 0
    else
        return 1
    fi
}

# Check if a package is installed
# Args: package_name
is_package_installed() {
    local package="$1"
    
    if command -v pacman >/dev/null 2>&1; then
        pacman -Qi "$package" &>/dev/null
        elif command -v dpkg >/dev/null 2>&1; then
        dpkg -l "$package" &>/dev/null 2>&1
        elif command -v rpm >/dev/null 2>&1; then
        rpm -q "$package" &>/dev/null
    else
        # Fallback: check if command exists
        command -v "$package" >/dev/null 2>&1
    fi
}

# Install a package if not already installed
# Args: package_name
install_package_if_needed() {
    local package="$1"
    
    if is_package_installed "$package"; then
        return 1  # Already installed, skipped
    fi
    
    if command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --noconfirm --needed "$package"
        elif command -v paru >/dev/null 2>&1; then
        paru -S --noconfirm --needed "$package"
        elif command -v apt-get >/dev/null 2>&1; then
        sudo apt-get install -y "$package"
        elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y "$package"
    else
        return 2  # No package manager found
    fi
    
    return 0  # Package was installed
}

# Display state directory statistics
show_state_info() {
    local completed_count
    completed_count=$(find "$STATE_DIR" -type f 2>/dev/null | wc -l)
    
    echo
    log_info "Installation state information:"
    log_info "  State directory: $STATE_DIR"
    log_info "  Completed steps: $completed_count"
    
    if [[ $completed_count -gt 0 ]]; then
        echo
        log_info "Completed steps:"
        find "$STATE_DIR" -type f -printf "    - %f\n" 2>/dev/null | sort
    fi
    echo
}

# Export functions for use in other scripts
export -f is_step_completed
export -f mark_step_completed
export -f reset_step
export -f reset_all_steps
export -f files_differ
export -f dirs_differ
export -f copy_if_changed
export -f copy_dir_if_changed
export -f is_service_installed
export -f install_service
export -f restart_if_running
export -f is_package_installed
export -f install_package_if_needed
export -f show_state_info

