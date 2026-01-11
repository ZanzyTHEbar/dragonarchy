#!/usr/bin/env bash
# Migration: proactively fix common stow conflicts caused by replaced symlinks.
#
# Earlier versions of theme scripts could replace stow-managed symlinks with regular files
# (notably: ~/.config/kitty/kitty.conf and ~/.config/walker/config.toml).
# That breaks idempotency and forces stow conflict resolution.
#
# This migration:
# - Backs up those files if they are regular files (not symlinks)
# - Removes them so stow can recreate correct links on next install/update

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

# shellcheck disable=SC1091
source "$REPO_ROOT/scripts/lib/logging.sh"

log_info "Migration $(basename "$0"): clean up replaced stow symlinks (kitty/walker)"

ts="$(date +%Y%m%d-%H%M%S)"
backup_root="$HOME/.local/state/dotfiles/backups/${ts}/migration-stow-fixes"

backup_and_remove_if_regular_file() {
  local path="$1"
  local label="$2"

  # If it's already a symlink, great.
  if [[ -L "$path" ]]; then
    return 0
  fi

  # Only touch regular files; if it's a directory, that's a structural conflict and should be manual.
  if [[ -d "$path" ]]; then
    log_warning "$label: $path is a directory; not touching (resolve manually if stow conflicts)"
    return 0
  fi

  if [[ -f "$path" ]]; then
    local rel="${path#${HOME}/}"
    mkdir -p "$backup_root/$(dirname "$rel")"
    cp -a "$path" "$backup_root/$rel"
    rm -f "$path"
    log_success "$label: backed up+removed regular file at $path"
  fi
}

backup_and_remove_if_regular_file "$HOME/.config/kitty/kitty.conf" "kitty.conf"
backup_and_remove_if_regular_file "$HOME/.config/walker/config.toml" "walker config.toml"

if [[ -d "$backup_root" ]]; then
  log_info "Backups stored at: $backup_root"
fi

log_success "Migration complete"

