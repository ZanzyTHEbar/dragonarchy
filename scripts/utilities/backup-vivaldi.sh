#!/usr/bin/env bash
#
# Backup Vivaldi profile to an external mount using rsync.
# Designed to run from cron (non-interactive).
#
set -euo pipefail

PROFILE_SRC_DEFAULT="${HOME}/.config/vivaldi-backup"
PROFILE_SRC="${VIVALDI_PROFILE_SRC:-$PROFILE_SRC_DEFAULT}"

BACKUP_ROOT="${VIVALDI_BACKUP_ROOT:-/mnt/common/backups/vivaldi-backup}"
HOST="$(hostname 2>/dev/null || echo unknown-host)"
DEST="${BACKUP_ROOT}/${HOST}"

LOG_DIR="${HOME}/.local/state/dotfiles/logs"
LOG_FILE="${LOG_DIR}/vivaldi-backup.log"
mkdir -p "$LOG_DIR"

LOCK_FILE="${XDG_RUNTIME_DIR:-/tmp}/vivaldi-backup.lock"

{
  echo "[$(date --iso-8601=seconds)] starting backup"
  echo "src=$PROFILE_SRC"
  echo "dest=$DEST"
} >>"$LOG_FILE" 2>&1

if ! command -v rsync >/dev/null 2>&1; then
  echo "rsync not found; aborting" >>"$LOG_FILE"
  exit 1
fi

if ! command -v flock >/dev/null 2>&1; then
  echo "flock not found; aborting (avoid concurrent backups)" >>"$LOG_FILE"
  exit 1
fi

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  echo "lock busy; exiting" >>"$LOG_FILE"
  exit 0
fi

if [[ ! -d "$PROFILE_SRC" ]]; then
  echo "source profile missing: $PROFILE_SRC" >>"$LOG_FILE"
  exit 1
fi

if [[ ! -d "$BACKUP_ROOT" ]]; then
  echo "backup root not mounted/present: $BACKUP_ROOT" >>"$LOG_FILE"
  exit 1
fi

mkdir -p "$DEST"
if [[ ! -w "$DEST" ]]; then
  echo "backup destination not writable: $DEST" >>"$LOG_FILE"
  exit 1
fi

# NOTE: We exclude transient lock/socket artifacts to avoid noisy churn.
rsync -a --delete --delete-delay --human-readable \
  --exclude='SingletonLock' \
  --exclude='SingletonSocket' \
  --exclude='SingletonCookie' \
  --exclude='*.tmp' \
  "$PROFILE_SRC/" "$DEST/" >>"$LOG_FILE" 2>&1

echo "[$(date --iso-8601=seconds)] done" >>"$LOG_FILE"

