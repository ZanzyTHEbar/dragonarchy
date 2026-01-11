#!/usr/bin/env bash
# Migration: remove broken user-level hicolor index.theme override.
#
# Some earlier dotfiles versions stowed:
#   ~/.local/share/icons/hicolor/index.theme
#
# That file overrides the system hicolor theme definition and (if incomplete) breaks icon lookups
# for scalable/symbolic icons, causing "white square" tray/app icons in Waybar + Walker.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

# shellcheck disable=SC1091
source "$REPO_ROOT/scripts/lib/logging.sh"

log_info "Migration $(basename "$0"): remove user-level hicolor override"

target="$HOME/.local/share/icons/hicolor/index.theme"

if [[ -L "$target" ]]; then
  resolved="$(readlink -f "$target" 2>/dev/null || true)"
  if [[ -n "$resolved" && "$resolved" == "$REPO_ROOT/"* ]]; then
    ts="$(date +%Y%m%d-%H%M%S)"
    backup_root="$HOME/.local/state/dotfiles/backups/${ts}/migration-icon-fixes"
    mkdir -p "$backup_root"
    cp -a "$target" "$backup_root/index.theme"
    rm -f "$target"
    log_success "Removed stowed user-level hicolor index.theme (backup: $backup_root/index.theme)"
  else
    log_info "Keeping $target (not pointing into dotfiles repo)"
  fi
elif [[ -f "$target" ]]; then
  # If user manually created it, back it up but warn (it might be intentional).
  ts="$(date +%Y%m%d-%H%M%S)"
  backup_root="$HOME/.local/state/dotfiles/backups/${ts}/migration-icon-fixes"
  mkdir -p "$backup_root"
  cp -a "$target" "$backup_root/index.theme"
  rm -f "$target"
  log_warning "Removed user-level hicolor index.theme regular file (backup: $backup_root/index.theme)"
else
  log_info "No user-level hicolor index.theme present; nothing to do"
fi

log_success "Migration complete"

