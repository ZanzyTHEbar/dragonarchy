#!/usr/bin/env bash
#
# Control-plane mode helpers
#
# Existing installer callers keep their historical defaults. Legacy update and
# migration dispatches use the stricter helper below and require both ownership
# markers to be explicit.

dotfiles_system_owner() {
    local owner="${DOTFILES_SYSTEM_OWNER:-legacy}"
    case "$owner" in
        legacy|ansible)
            printf '%s' "$owner"
            ;;
        *)
            printf '%s' "legacy"
            return 1
            ;;
    esac
}

dotfiles_user_owner() {
    local owner="${DOTFILES_USER_OWNER:-stow}"
    case "$owner" in
        stow|chezmoi)
            printf '%s' "$owner"
            ;;
        *)
            printf '%s' "stow"
            return 1
            ;;
    esac
}

dotfiles_system_owner_is_ansible() {
    [[ "$(dotfiles_system_owner)" == "ansible" ]]
}

dotfiles_user_owner_is_chezmoi() {
    [[ "$(dotfiles_user_owner)" == "chezmoi" ]]
}

dotfiles_require_explicit_legacy_ownership() {
    local operation="${1:-legacy control-plane dispatch}"
    local system_owner="${DOTFILES_SYSTEM_OWNER:-<missing>}"
    local user_owner="${DOTFILES_USER_OWNER:-<missing>}"

    if [[ -z "${DOTFILES_SYSTEM_OWNER+x}" || -z "${DOTFILES_USER_OWNER+x}" ]]; then
        printf 'REFUSED: %s requires explicit legacy ownership markers (DOTFILES_SYSTEM_OWNER=legacy and DOTFILES_USER_OWNER=stow)\n' \
            "$operation" >&2
        return 1
    fi

    case "$system_owner:$user_owner" in
        legacy:stow)
            return 0
            ;;
        ansible:stow|ansible:chezmoi|legacy:chezmoi)
            printf 'REFUSED: %s blocked for managed ownership (system=%s, user=%s)\n' \
                "$operation" "$system_owner" "$user_owner" >&2
            return 1
            ;;
        *)
            printf 'REFUSED: %s blocked because ownership is ambiguous (system=%s, user=%s)\n' \
                "$operation" "$system_owner" "$user_owner" >&2
            return 1
            ;;
    esac
}

dotfiles_validate_no_symlinked_ancestors() {
    local target="$1"
    local operation="${2:-migration target}"
    local parent="${target%/*}"
    local current=""
    local component
    local -a components=()

    if [[ "$target" != /* || "$parent" != /* ]]; then
        printf 'REFUSED: %s must use an absolute path\n' "$operation" >&2
        return 1
    fi

    IFS='/' read -r -a components <<< "${parent#/}"
    for component in "${components[@]}"; do
        [[ -z "$component" || "$component" == "." ]] && continue
        if [[ "$component" == ".." ]]; then
            printf 'REFUSED: %s contains a parent traversal\n' "$operation" >&2
            return 1
        fi

        current="$current/$component"
        if [[ -L "$current" ]]; then
            printf 'REFUSED: %s has a symlinked ancestor: %s\n' "$operation" "$current" >&2
            return 1
        fi
        if [[ -e "$current" && ! -d "$current" ]]; then
            printf 'REFUSED: %s has a non-directory ancestor: %s\n' "$operation" "$current" >&2
            return 1
        fi
        [[ -e "$current" ]] || return 0
    done
}
