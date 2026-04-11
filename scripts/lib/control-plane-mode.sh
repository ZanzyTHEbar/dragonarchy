#!/usr/bin/env bash
#
# Control-plane mode helpers
#
# Defaults preserve the legacy installer behavior unless the operator explicitly
# selects the new control plane for system or user state.

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
