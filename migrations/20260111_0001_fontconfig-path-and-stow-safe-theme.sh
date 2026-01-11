#!/usr/bin/env bash
# Migration: move legacy fontconfig path and fix stow conflicts caused by replaced symlinks.
#
# - Fontconfig reads: ~/.config/fontconfig/fonts.conf (not ~/.config/fonts.conf)
# - Older installs may have a stale ~/.config/fonts.conf symlink/file; remove it if it points into dotfiles.
# - If theme-set previously replaced stow symlinks (kitty.conf / walker config), those become regular files.
#   We don't auto-delete them here (could clobber user edits), but we do log actionable hints.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

# shellcheck disable=SC1091
source "$REPO_ROOT/scripts/lib/logging.sh"

log_info "Migration $(basename "$0"): fontconfig path + stow-safe theme config"

# 1) Remove legacy ~/.config/fonts.conf if it points at our dotfiles (or is a broken symlink)
LEGACY="$HOME/.config/fonts.conf"
if [[ -L "$LEGACY" ]]; then
  resolved="$(readlink -f "$LEGACY" 2>/dev/null || true)"
  if [[ -z "$resolved" || "$resolved" == "$REPO_ROOT/"* ]]; then
    log_info "Removing legacy fontconfig symlink: $LEGACY"
    rm -f "$LEGACY"
  fi
elif [[ -f "$LEGACY" ]]; then
  # If it was a real file created by some previous manual step, keep it but warn.
  log_warning "Legacy $LEGACY exists as a regular file; fontconfig may ignore it. Consider removing it."
fi

# 2) Sanity: ensure new fontconfig directory exists (stow will link the file)
mkdir -p "$HOME/.config/fontconfig"

# 3) Hint about stow conflicts caused by replaced symlinks
maybe_warn_replaced_symlink() {
  local p="$1"
  local expected_prefix="$2"
  if [[ -e "$p" && ! -L "$p" ]]; then
    log_warning "Potential stow conflict: $p is a regular file (expected a symlink)."
    log_warning "If you hit stow conflicts, back up and remove it, then re-run install/update."
    log_warning "Expected target should live under: $expected_prefix"
  fi
}

maybe_warn_replaced_symlink "$HOME/.config/kitty/kitty.conf" "$REPO_ROOT/packages/kitty"
maybe_warn_replaced_symlink "$HOME/.config/walker/config.toml" "$REPO_ROOT/packages/hyprland"

log_success "Migration complete"

