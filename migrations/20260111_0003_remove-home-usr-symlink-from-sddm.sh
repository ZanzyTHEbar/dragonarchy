#!/usr/bin/env bash
# Migration: remove accidental ~/usr symlink created by user-level stow of system package `sddm`.
#
# If `packages/sddm` was mistakenly included in the normal (user) stow pass, stow can create:
#   ~/usr -> <dotfiles>/packages/sddm/usr
#
# That is not a valid dotfiles target and can break expectations for tools.
# We back it up and remove it if it points into this dotfiles repo.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

# shellcheck disable=SC1091
source "$REPO_ROOT/scripts/lib/logging.sh"

log_info "Migration $(basename "$0"): remove accidental ~/usr symlink from sddm user-stow"

home_usr="$HOME/usr"
if [[ -L "$home_usr" ]]; then
  resolved="$(readlink -f "$home_usr" 2>/dev/null || true)"
  if [[ -n "$resolved" && "$resolved" == "$REPO_ROOT/packages/sddm/usr" ]]; then
    ts="$(date +%Y%m%d-%H%M%S)"
    backup_root="$HOME/.local/state/dotfiles/backups/${ts}/migration-stow-fixes"
    mkdir -p "$backup_root"
    cp -a "$home_usr" "$backup_root/usr"
    rm -f "$home_usr"
    log_success "Backed up+removed $home_usr (backup: $backup_root/usr)"
  else
    log_info "Keeping $home_usr (does not point to $REPO_ROOT/packages/sddm/usr)"
  fi
elif [[ -e "$home_usr" ]]; then
  log_warning "$home_usr exists but is not a symlink; not touching (resolve manually if needed)"
else
  log_info "No $home_usr present; nothing to do"
fi

log_success "Migration complete"

