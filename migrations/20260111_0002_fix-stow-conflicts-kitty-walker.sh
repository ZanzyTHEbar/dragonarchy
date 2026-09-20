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
# shellcheck disable=SC1091
source "$REPO_ROOT/scripts/lib/control-plane-mode.sh"

dotfiles_require_explicit_legacy_ownership "migration $(basename "$0")" || exit 1

log_info "Migration $(basename "$0"): clean up replaced stow symlinks (kitty/walker)"

ts="$(date +%Y%m%d-%H%M%S)"
backup_root="$HOME/.local/state/dotfiles/backups/${ts}/migration-stow-fixes"
MIGRATION_COMMITTED=false
declare -a REMOVED_PATHS=()
declare -a BACKUP_PATHS=()

restore_removed_files() {
  local index path backup
  [[ "$MIGRATION_COMMITTED" == true ]] && return 0

  for ((index = ${#REMOVED_PATHS[@]} - 1; index >= 0; index--)); do
    path="${REMOVED_PATHS[index]}"
    backup="${BACKUP_PATHS[index]}"
    if [[ ! -e "$path" && ! -L "$path" && -f "$backup" ]]; then
      mv -f -- "$backup" "$path" || log_error "Could not restore $path after an interrupted migration"
    fi
  done
}

trap restore_removed_files EXIT

backup_and_remove_if_regular_file() {
  local path="$1"
  local label="$2"
  local resolved=""

  dotfiles_validate_no_symlinked_ancestors "$path" "migration $(basename "$0") target $path" || return 1

  # If it's already a symlink, great.
  if [[ -L "$path" ]]; then
    return 0
  fi

  # If the file lives inside a stow-managed symlinked directory, do not treat it
  # as a disposable regular file. Removing it would delete the real repo file.
  resolved="$(readlink -f "$path" 2>/dev/null || true)"
  if [[ -n "$resolved" && "$resolved" == "$REPO_ROOT/"* ]]; then
    log_info "$label: $path resolves inside the repo; leaving stow-managed file intact"
    return 0
  fi

  # Only touch regular files; if it's a directory, that's a structural conflict and should be manual.
  if [[ -d "$path" ]]; then
    log_warning "$label: $path is a directory; not touching (resolve manually if stow conflicts)"
    return 0
  fi

  if [[ -f "$path" ]]; then
    local rel="${path#${HOME}/}"
    local backup_path="$backup_root/$rel"
    dotfiles_validate_no_symlinked_ancestors \
      "$backup_path" "migration $(basename "$0") backup $backup_path" || return 1
    if [[ -L "$backup_path" ]]; then
      log_error "$label: backup path is a symlink; leaving $path untouched"
      return 1
    fi
    mkdir -p "$(dirname "$backup_path")"
    if ! cp -a -- "$path" "$backup_path"; then
      log_error "$label: could not create a backup; leaving $path untouched"
      return 1
    fi
    if ! cmp -s -- "$path" "$backup_path"; then
      log_error "$label: backup verification failed; leaving $path untouched"
      return 1
    fi

    # Record before removal so the EXIT trap can restore the file if the
    # process is interrupted immediately after the unlink.
    REMOVED_PATHS+=("$path")
    BACKUP_PATHS+=("$backup_path")
    if ! rm -f -- "$path"; then
      log_error "$label: could not remove $path; leaving it untouched"
      return 1
    fi
    log_success "$label: backed up+removed regular file at $path"
  fi
}

backup_and_remove_if_regular_file "$HOME/.config/kitty/kitty.conf" "kitty.conf"
backup_and_remove_if_regular_file "$HOME/.config/walker/config.toml" "walker config.toml"

if [[ -d "$backup_root" ]]; then
  log_info "Backups stored at: $backup_root"
fi

MIGRATION_COMMITTED=true
log_success "Migration complete"
