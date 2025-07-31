#!/usr/bin/env zsh

# File: ~/.config/zsh/add_dep.zsh

# This script is used to add a dependency to install_deps.zsh

# Usage:
# add_dep --name <binary> --package <pkg_name> [--version <version>] [--method <method>] [--postinstall <cmd>]
# Example: add_dep --name zoxide --package zoxide --version latest --method linux:arch:pacman

# Ensure this script is only sourced in a Zsh shell
if [[ -z "$ZSH_VERSION" ]]; then
    echo "This script must be sourced in a Zsh shell."
    exit 1
fi

# Function to add a dependency to install_deps.zsh
add_dep() {
    local name package version methods=() postinstall=""
    local deps_file="$HOME/.config/zsh/install_deps.zsh"
    local temp_file="/tmp/install_deps_temp.zsh"
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

    # Parse command-line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --name)
            name="$2"
            shift 2
            ;;
        --package)
            package="$2"
            shift 2
            ;;
        --version)
            version="$2"
            shift 2
            ;;
        --method)
            methods+=("$2")
            shift 2
            ;;
        --postinstall)
            postinstall="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: add_dep --name <binary> --package <pkg_name> [--version <version>] [--method <method>] [--postinstall <cmd>]"
            echo "Example: add_dep --name zoxide --package zoxide --version latest --method linux:arch:pacman"
            return 1
            ;;
        esac
    done

    # Validate required arguments
    if [[ -z "$name" || -z "$package" ]]; then
        echo "Error: --name and --package are required."
        return 1
    fi
    if [[ -z "$version" ]]; then
        version="latest"
    fi
    if [[ ${#methods[@]} -eq 0 ]]; then
        # Default to pacman for Arch-based systems
        if [[ "$package_distro" == "arch" ]]; then
            methods=("linux:arch:pacman")
        else
            echo "Error: At least one --method is required (e.g., linux:arch:pacman, linux:debian:apt, macos:brew, install:script:<url>, fallback:download:<url>)."
            return 1
        fi
    fi

    # Validate methods
    for method in "${methods[@]}"; do
        if [[ ! "$method" =~ "^(linux:$package_distro:(pacman|paru|apt)|macos:brew|install:script:.*|fallback:download:.*)$" ]]; then
            echo "Error: Invalid method '$method'. Must be linux:$package_distro:(pacman|paru|apt), macos:brew, install:script:<url>, or fallback:download:<url>."
            return 1
        fi
    done

    # Check if deps_file exists
    if [[ ! -f "$deps_file" ]]; then
        echo "Error: $deps_file not found."
        return 1
    fi

    # Build the new deps entry
    local dep_entry="[\"$name\"]=\"package:$package|version:$version"
    for method in "${methods[@]}"; do
        dep_entry+="|$method"
    done
    if [[ -n "$postinstall" ]]; then
        dep_entry+="|postinstall:$postinstall"
    fi
    dep_entry+="\""

    # Read the deps_file and update the deps array
    local in_deps_array=0
    local new_content=()
    local found_dep=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*typeset[[:space:]]+-A[[:space:]]+deps=\( ]]; then
            in_deps_array=1
            new_content+=("$line")
            continue
        fi
        if [[ $in_deps_array -eq 1 && "$line" =~ ^[[:space:]]*\) ]]; then
            # Add the new entry before closing the array
            if [[ $found_dep -eq 0 ]]; then
                new_content+=("    $dep_entry")
            fi
            new_content+=("$line")
            in_deps_array=0
            continue
        fi
        if [[ $in_deps_array -eq 1 && "$line" =~ ^[[:space:]]*\[\"$name\"\]= ]]; then
            # Replace existing entry
            new_content+=("    $dep_entry")
            found_dep=1
            continue
        fi
        if [[ $in_deps_array -eq 0 || $found_dep -eq 0 ]]; then
            new_content+=("$line")
        fi
    done <"$deps_file"

    # Write the updated content to a temporary file
    printf "%s\n" "${new_content[@]}" >"$temp_file"

    # Validate the syntax of the temporary file
    if ! zsh -n "$temp_file" 2>/dev/null; then
        echo "Error: Generated script has syntax errors. Aborting."
        rm -f "$temp_file"
        return 1
    fi

    # Replace the original file
    mv "$temp_file" "$deps_file"
    echo "Successfully added/updated dependency '$name' in $deps_file."
    echo "New entry: $dep_entry"
}
