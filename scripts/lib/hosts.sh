#!/usr/bin/env bash

# Host discovery and feature detection helpers.
# Safe to source from any script.

__hosts_log_info() {
    command -v log_info >/dev/null 2>&1 && log_info "$@" || true
}

# Args: hosts_dir
get_available_hosts() {
    local hosts_dir="$1"
    if [[ -d "$hosts_dir" ]]; then
        find "$hosts_dir" -maxdepth 1 -type d ! -path "$hosts_dir" -exec basename {} \; | sort
    fi
}

# Args: hosts_dir
# Prints: detected hostname
# Note: returns the system hostname even if there is no matching hosts/ directory.
detect_host() {
    local _hosts_dir="$1"
    local hostname
    hostname=$(hostname | cut -d. -f1)

    if [[ -d "${_hosts_dir}/${hostname}" ]]; then
        echo "$hostname"
    else
        echo "$hostname"
    fi
}

# Args: hosts_dir hostname
# Prints: detection method (marker|setup.sh|docs)
# Returns: 0 if Hyprland detected, 1 otherwise
hyprland_detection_method() {
    local hosts_dir="$1"
    local hostname="$2"
    local host_dir="${hosts_dir}/${hostname}"

    [[ ! -d "$host_dir" ]] && return 1

    if [[ -f "$host_dir/.hyprland" ]] || [[ -f "$host_dir/HYPRLAND" ]]; then
        echo "marker"
        return 0
    fi

    if [[ -f "$host_dir/setup.sh" ]]; then
        if grep -qi "hyprland\|hyprlock\|hypridle\|waybar" "$host_dir/setup.sh"; then
            echo "setup.sh"
            return 0
        fi
    fi

    if [[ -d "$host_dir/docs" ]]; then
        if find "$host_dir/docs" -type f -name "*.md" -exec grep -qi "hyprland" {} \; 2>/dev/null; then
            echo "docs"
            return 0
        fi
    fi

    return 1
}

# Args: hosts_dir hostname
is_hyprland_host() {
    local hosts_dir="$1"
    local hostname="$2"

    local method
    method=$(hyprland_detection_method "$hosts_dir" "$hostname") || return 1
    __hosts_log_info "Host '$hostname' detected as Hyprland ($method)"
    return 0
}
