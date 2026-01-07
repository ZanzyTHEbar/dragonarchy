#!/usr/bin/env bash

# Platform detection helpers.
# Safe to source from any script.

detect_platform() {
    case "$(uname -s)" in
        Linux*)
            if [[ -f /etc/os-release ]]; then
                # shellcheck disable=SC1091
                source /etc/os-release
            fi
            echo "${ID:-linux}"
            ;;
        Darwin*)
            echo "darwin"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Map distro IDs to canonical keys used by the deps manifest.
# Args: platform_id
canonical_platform_key() {
    local platform_id="${1:-}"
    case "$platform_id" in
        arch|cachyos|manjaro) echo "arch" ;;
        debian|ubuntu) echo "debian" ;;
        *) echo "$platform_id" ;;
    esac
}
