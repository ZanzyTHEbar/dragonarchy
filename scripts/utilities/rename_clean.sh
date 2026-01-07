#!/usr/bin/env bash

set -euo pipefail

usage() {
  echo "Usage: $0 [options] directory"
  echo ""
  echo "Renames files (and optionally directories) by replacing spaces, tabs, and hyphens"
  echo "with underscores, collapsing consecutive underscores, and trimming leading/trailing ones."
  echo ""
  echo "Options:"
  echo "  -r   Recurse into subdirectories (default: only the given directory)"
  echo "  -d   Also rename directories (subdirectories if -r is used)"
  echo "  -n   Dry-run mode: show what would be renamed without doing it"
  echo "  -h   Show this help message"
  exit 1
}

dry_run=false
recursive=false
rename_dirs=false

while getopts ":rdnh" opt; do
  case $opt in
    r) recursive=true ;;
    d) rename_dirs=true ;;
    n) dry_run=true ;;
    h) usage ;;
    ?) echo "Invalid option: -$OPTARG" >&2; usage ;;
  esac
done

shift $((OPTIND - 1))

if [[ $# -ne 1 ]]; then
  echo "Error: Exactly one directory must be provided" >&2
  usage
fi

target_dir="$1"

if [[ ! -d "$target_dir" ]]; then
  echo "Error: '$target_dir' is not a directory" >&2
  exit 1
fi

# Change to the target directory for simpler relative paths
cd "$target_dir"
echo "Processing: $(pwd)"

process_entry() {
  local file="$1"
  local dir="${file%/*}"
  local base="${file##*/}"

  local newbase="${base// /_}"
  newbase="${newbase//$'\t'/_}"
  newbase="${newbase//-/_}"

  # Collapse consecutive underscores
  while [[ "$newbase" == *__* ]]; do
    newbase="${newbase//__/_}"
  done

  # Trim leading underscores
  while [[ "$newbase" == _* ]]; do
    newbase="${newbase#_}"
  done

  # Trim trailing underscores
  while [[ "$newbase" == *_ ]]; do
    newbase="${newbase%_}"
  done

  local old_display="${file#./}"
  local newfile="${dir}/${newbase}"
  newfile="${newfile#./}"
  local new_display="$newfile"

  if [[ -z "$newbase" ]]; then
    echo "Skipping '$old_display': resulting name would be empty"
    return
  fi

  if [[ "$base" == "$newbase" ]]; then
    return  # No change needed
  fi

  if [[ -e "$newfile" ]]; then
    echo "Skipping '$old_display' → '$new_display': target already exists"
    return
  fi

  if $dry_run; then
    echo "Would rename '$old_display' → '$new_display'"
  else
    mv -v "$file" "$newfile"
  fi
}

# --- Rename files first (always safe order) ---
file_opts="-type f"
if ! $recursive; then
  file_opts="$file_opts -maxdepth 1"
fi

find . $file_opts -print0 |
while IFS= read -r -d '' file; do
  process_entry "$file"
done

# --- Rename directories (if enabled) ---
if $rename_dirs; then
  dir_opts="-type d -mindepth 1"
  if $recursive; then
    dir_opts="$dir_opts -depth"  # Bottom-up for safety
  else
    dir_opts="$dir_opts -maxdepth 1"
  fi

  find . $dir_opts -print0 |
  while IFS= read -r -d '' file; do
    process_entry "$file"
  done
fi

echo "Done."
