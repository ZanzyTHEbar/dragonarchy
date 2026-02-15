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

    # Prefer trait-based detection
    if host_has_trait "$hosts_dir" "$hostname" "hyprland"; then
        __hosts_log_info "Host '$hostname' detected as Hyprland (trait)" >&2
        return 0
    fi

    # Fallback to heuristic detection
    local method
    method=$(hyprland_detection_method "$hosts_dir" "$hostname") || return 1
    __hosts_log_info "Host '$hostname' detected as Hyprland ($method)" >&2
    return 0
}

# ─── Trait system ───────────────────────────────────────────────

# Read all traits for a host, one per line.
# Strips comments and blank lines.
# Args: hosts_dir hostname
# Prints: trait names, one per line
host_traits() {
    local hosts_dir="$1"
    local hostname="$2"
    local traits_file="${hosts_dir}/${hostname}/.traits"

    [[ -f "$traits_file" ]] || return 0

    while IFS= read -r line; do
        # Strip comments and whitespace
        line="${line%%#*}"
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [[ -n "$line" ]] && echo "$line"
    done < "$traits_file"
}

# Check if a host has a specific trait.
# Args: hosts_dir hostname trait
# Returns: 0 if trait present, 1 otherwise
host_has_trait() {
    local hosts_dir="$1"
    local hostname="$2"
    local trait="$3"

    local t
    while IFS= read -r t; do
        [[ "$t" == "$trait" ]] && return 0
    done < <(host_traits "$hosts_dir" "$hostname")

    return 1
}

# List all traits for a host as a comma-separated string.
# Args: hosts_dir hostname
host_traits_summary() {
    local hosts_dir="$1"
    local hostname="$2"

    host_traits "$hosts_dir" "$hostname" | paste -sd, -
}
