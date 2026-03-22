#!/usr/bin/env bash

# Platform detection helpers.
# Safe to source from any script.

platform_os_release_field() {
    local key="${1:-}"
    [[ -n "$key" && -r /etc/os-release ]] || return 0

    (
        # shellcheck disable=SC1091
        source /etc/os-release
        printf '%s\n' "${!key:-}"
    )
}

platform_id_like() {
    platform_os_release_field "ID_LIKE" | tr '[:upper:]' '[:lower:]'
}

platform_version_id() {
    platform_os_release_field "VERSION_ID"
}

platform_version_codename() {
    local codename
    codename="$(platform_os_release_field "VERSION_CODENAME")"
    if [[ -z "$codename" ]]; then
        codename="$(platform_os_release_field "UBUNTU_CODENAME")"
    fi
    printf '%s\n' "$codename" | tr '[:upper:]' '[:lower:]'
}

platform_version_major() {
    local version_id
    version_id="$(platform_version_id)"
    printf '%s\n' "${version_id%%.*}"
}

_platform_id_like_has() {
    local needle="${1:-}"
    local like
    like=" $(platform_id_like) "
    [[ -n "$needle" && "$like" == *" ${needle} "* ]]
}

detect_platform() {
    case "$(uname -s)" in
        Linux*)
            local platform_id
            platform_id="$(platform_os_release_field "ID" | tr '[:upper:]' '[:lower:]')"
            echo "${platform_id:-linux}"
            ;;
        Darwin*)
            echo "darwin"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

platform_is_arch_family() {
    local platform_id="${1:-$(detect_platform)}"
    case "$platform_id" in
        arch|cachyos|manjaro|endeavouros)
            return 0
            ;;
    esac

    _platform_id_like_has "arch"
}

platform_is_debian_family() {
    local platform_id="${1:-$(detect_platform)}"
    case "$platform_id" in
        debian|ubuntu|linuxmint|pop|pop-os|pop!_os|neon|elementary|zorin|tuxedo|kali|parrot|raspbian)
            return 0
            ;;
    esac

    _platform_id_like_has "ubuntu" || _platform_id_like_has "debian"
}

# Map distro IDs to canonical keys used by the deps manifest.
# Args: platform_id
canonical_platform_key() {
    local platform_id="${1:-$(detect_platform)}"
    if platform_is_arch_family "$platform_id"; then
        echo "arch"
        return 0
    fi

    if platform_is_debian_family "$platform_id"; then
        echo "debian"
        return 0
    fi

    echo "$platform_id"
}

debian_family_variant_key() {
    local platform_id="${1:-$(detect_platform)}"
    case "$platform_id" in
        debian|kali|parrot|raspbian)
            echo "debian"
            ;;
        ubuntu|linuxmint|pop|pop-os|pop!_os|neon|elementary|zorin|tuxedo)
            echo "ubuntu"
            ;;
        *)
            if _platform_id_like_has "ubuntu"; then
                echo "ubuntu"
            elif _platform_id_like_has "debian"; then
                echo "debian"
            else
                echo "debian-family"
            fi
            ;;
    esac
}

debian_family_provider_track() {
    local platform_id="${1:-$(detect_platform)}"
    local variant
    variant="$(debian_family_variant_key "$platform_id")"

    local codename
    codename="$(platform_version_codename)"

    local version_id
    version_id="$(platform_version_id)"

    local version_major
    version_major="$(platform_version_major)"

    case "$variant" in
        debian)
            case "$codename" in
                sid|unstable|forky|testing)
                    echo "debian_hyprland_archive"
                    return 0
                    ;;
                trixie|bookworm|bullseye|buster)
                    echo "debian_legacy_no_hyprland"
                    return 0
                    ;;
            esac

            if [[ "$version_major" =~ ^[0-9]+$ ]] && (( version_major >= 14 )); then
                echo "debian_hyprland_archive"
            else
                echo "debian_legacy_no_hyprland"
            fi
            ;;
        ubuntu)
            case "$codename" in
                resolute|devel)
                    echo "ubuntu_hyprland_archive"
                    return 0
                    ;;
                oracular|plucky|questing|noble|jammy|focal|mantic|lunar|kinetic)
                    echo "ubuntu_legacy_no_hyprland"
                    return 0
                    ;;
            esac

            case "$version_id" in
                26.*)
                    echo "ubuntu_hyprland_archive"
                    ;;
                *)
                    echo "ubuntu_legacy_no_hyprland"
                    ;;
            esac
            ;;
        *)
            echo "debian_family_fallback_no_hyprland"
            ;;
    esac
}

platform_provider_track() {
    local platform_id="${1:-$(detect_platform)}"
    local platform_key
    platform_key="$(canonical_platform_key "$platform_id")"

    case "$platform_key" in
        arch)
            echo "arch_official"
            ;;
        debian)
            debian_family_provider_track "$platform_id"
            ;;
        *)
            echo "generic"
            ;;
    esac
}

platform_track_supports_hyprland_archive() {
    local track="${1:-$(platform_provider_track)}"
    case "$track" in
        debian_hyprland_archive|ubuntu_hyprland_archive)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

platform_feature_csv() {
    local platform_id="${1:-$(detect_platform)}"
    local platform_key
    platform_key="$(canonical_platform_key "$platform_id")"

    local features=()
    case "$platform_key" in
        arch)
            features+=("distro_arch_family" "track_arch_official")
            ;;
        debian)
            features+=("distro_debian_family")

            local variant
            variant="$(debian_family_variant_key "$platform_id")"
            case "$variant" in
                debian) features+=("variant_debian") ;;
                ubuntu) features+=("variant_ubuntu_family") ;;
                *) features+=("variant_debian_family") ;;
            esac

            features+=("track_$(platform_provider_track "$platform_id")")
            ;;
        *)
            features+=("distro_${platform_key}")
            ;;
    esac

    local joined=""
    local feature
    for feature in "${features[@]}"; do
        if [[ -z "$joined" ]]; then
            joined="$feature"
        else
            joined+=",$feature"
        fi
    done

    printf '%s\n' "$joined"
}

platform_summary() {
    local platform_id="${1:-$(detect_platform)}"
    local platform_key
    platform_key="$(canonical_platform_key "$platform_id")"

    local summary="id=${platform_id} key=${platform_key}"
    if [[ "$platform_key" == "debian" ]]; then
        summary+=" variant=$(debian_family_variant_key "$platform_id")"
        summary+=" codename=$(platform_version_codename)"
        summary+=" version=$(platform_version_id)"
        summary+=" track=$(platform_provider_track "$platform_id")"
    fi

    printf '%s\n' "$summary"
}
