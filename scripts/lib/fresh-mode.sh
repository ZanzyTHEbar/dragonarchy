#!/usr/bin/env bash
#
# fresh-mode.sh - Fresh machine detection for dotfiles installer
#
# Detects whether this machine has any existing stow-managed symlinks
# and optionally enables "fresh mode" to purge conflicts before stowing.
#
# Callers must set:
#   PACKAGES_DIR - absolute path to packages/ directory
#   FRESH_MODE   - "true"/"false" flag (may be mutated by maybe_enable_fresh_mode)
#   INSTALL_DOTFILES - "true"/"false" (controls whether detection runs)
#
# Requires: logging.sh

# Detect whether this appears to be a "fresh machine" for dotfiles:
# i.e. we don't see any existing stow-managed symlinks pointing into our `packages/`.
is_fresh_machine() {
    local packages_real
    packages_real=$(readlink -f "$PACKAGES_DIR" 2>/dev/null || true)
    [[ -z "$packages_real" ]] && packages_real="$PACKAGES_DIR"

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
