#!/usr/bin/env bash

# TOML manifest helpers (requires yq v4).
#
# Expected:
#   yq -p=toml -r '.path.to.value' file.toml

__manifest_yq_bin=""

__manifest_log_info() {
    command -v log_info >/dev/null 2>&1 && log_info "$@" || true
}

__manifest_log_warning() {
    command -v log_warning >/dev/null 2>&1 && log_warning "$@" || true
}

__manifest_log_error() {
    command -v log_error >/dev/null 2>&1 && log_error "$@" || true
}

manifest_yq_query() {
    local manifest_file="$1"
    local query="$2"

    local yq_bin
    yq_bin=$(manifest_yq_resolve_bin) || return 0

    "$yq_bin" -p=toml -r "$query" "$manifest_file" 2>/dev/null || true
}

__manifest_yq_is_v4() {
    local yq_bin="$1"
    [[ -z "$yq_bin" ]] && return 1
    [[ ! -x "$yq_bin" ]] && return 1

    local version
    version=$($yq_bin --version 2>/dev/null || true)
    [[ "$version" == *"mikefarah"* ]] && return 0
    [[ "$version" == *"version v4"* ]] && return 0
    return 1
}

# Resolve a yq v4 binary to use.
# Prefers a bootstrapped user-local copy to avoid conflicts with kislyuk yq.
manifest_yq_resolve_bin() {
    if [[ -n "${__manifest_yq_bin}" ]] && __manifest_yq_is_v4 "${__manifest_yq_bin}"; then
        echo "${__manifest_yq_bin}"
        return 0
    fi

    local local_bin="$HOME/.local/bin/yq"
    if __manifest_yq_is_v4 "$local_bin"; then
        __manifest_yq_bin="$local_bin"
        echo "$local_bin"
        return 0
    fi

    if command -v yq >/dev/null 2>&1; then
        local found
        found=$(command -v yq)
        if __manifest_yq_is_v4 "$found"; then
            __manifest_yq_bin="$found"
            echo "$found"
            return 0
        fi
    fi

    return 1
}

# Bootstrap yq so we can parse the manifest.
# Args: canonical_platform_key
manifest_ensure_yq() {
    local platform_key="$1"

    if manifest_yq_resolve_bin >/dev/null 2>&1; then
        return 0
    fi

    __manifest_log_warning "Required parser 'yq' v4 not found; bootstrapping mikefarah/yq..."

    local os arch url tmp
    case "$(uname -s)" in
        Linux*) os="linux" ;;
        Darwin*) os="darwin" ;;
        *)
            __manifest_log_error "Unsupported OS for yq bootstrap: $(uname -s)"
            return 1
            ;;
    esac

    case "$(uname -m)" in
        x86_64) arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
        *)
            __manifest_log_error "Unsupported architecture for yq bootstrap: $(uname -m)"
            return 1
            ;;
    esac

    url="https://github.com/mikefarah/yq/releases/latest/download/yq_${os}_${arch}"
    tmp=$(mktemp)

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$tmp"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$tmp" "$url"
    else
        __manifest_log_error "Neither curl nor wget available to download yq"
        rm -f "$tmp" 2>/dev/null || true
        return 1
    fi

    chmod +x "$tmp"
    mkdir -p "$HOME/.local/bin"
    mv "$tmp" "$HOME/.local/bin/yq"

    if ! __manifest_yq_is_v4 "$HOME/.local/bin/yq"; then
        __manifest_log_error "Downloaded yq, but it does not appear to be v4"
        return 1
    fi

    __manifest_yq_bin="$HOME/.local/bin/yq"
    __manifest_log_info "Bootstrapped yq v4 to $HOME/.local/bin/yq"
    return 0
}

# Check if a group is enabled for a given host + feature set.
# Args: manifest_file platform manager group host feature_csv
manifest_group_enabled() {
    local manifest_file="$1"
    local platform="$2"
    local manager="$3"
    local group="$4"
    local host="${5:-}"
    local feature_csv="${6:-}"

    local base_path=".platforms.${platform}.${manager}.${group}"

    # If group missing entirely, treat as disabled.
    local exists
    exists=$(manifest_yq_query "$manifest_file" "${base_path} | type")
    [[ -z "$exists" || "$exists" == "null" ]] && return 1

    # requires_features
    local required_feature
    while IFS= read -r required_feature; do
        [[ -z "$required_feature" || "$required_feature" == "null" ]] && continue
        if [[ ",${feature_csv}," != *",${required_feature},"* ]]; then
            return 1
        fi
    done < <(manifest_yq_query "$manifest_file" "${base_path}.requires_features[]")

    # requires_hosts
    local has_requires_hosts="false"
    local required_host
    while IFS= read -r required_host; do
        [[ -z "$required_host" || "$required_host" == "null" ]] && continue
        has_requires_hosts="true"
        [[ -n "$host" && "$host" == "$required_host" ]] && {
            has_requires_hosts="matched"
            break
        }
    done < <(manifest_yq_query "$manifest_file" "${base_path}.requires_hosts[]")

    if [[ "$has_requires_hosts" == "true" ]]; then
        return 1
    fi

    # exclude_hosts
    local excluded_host
    while IFS= read -r excluded_host; do
        [[ -z "$excluded_host" || "$excluded_host" == "null" ]] && continue
        [[ -n "$host" && "$host" == "$excluded_host" ]] && return 1
    done < <(manifest_yq_query "$manifest_file" "${base_path}.exclude_hosts[]")

    return 0
}

# Emit packages for a group, one per line.
# Args: manifest_file platform manager group host feature_csv
manifest_group_packages() {
    local manifest_file="$1"
    local platform="$2"
    local manager="$3"
    local group="$4"
    local host="${5:-}"
    local feature_csv="${6:-}"

    if ! manifest_group_enabled "$manifest_file" "$platform" "$manager" "$group" "$host" "$feature_csv"; then
        return 0
    fi

    manifest_yq_query "$manifest_file" ".platforms.${platform}.${manager}.${group}.packages[]"
}

# Emit a tool list (e.g. tools.pipx.packages), one per line.
# Args: manifest_file toml_path
manifest_tool_list() {
    local manifest_file="$1"
    local path="$2"

    manifest_yq_query "$manifest_file" ".${path}[]"
}
