#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ASSETS_DIR="$REPO_ROOT/assets/dragon"
ICON_SOURCE="$ASSETS_DIR/logo-source.png"
OUTPUT_ROOT="$ASSETS_DIR/icons/hicolor"

# shellcheck source=/dev/null
source "$REPO_ROOT/scripts/lib/logging.sh"

SIZES=(16 24 32 48 64 96 128 192 256 512)

ensure_dependencies() {
  if command -v magick >/dev/null 2>&1; then
    CONVERT_BIN=(magick)
  elif command -v convert >/dev/null 2>&1; then
    CONVERT_BIN=(convert)
  else
    log_error "ImageMagick (magick/convert) is required but not installed"
    exit 1
  fi
}

render_icon() {
  local size=$1
  local target_dir="$OUTPUT_ROOT/${size}x${size}/apps"
  local target_path="$target_dir/dragon-control.png"

  mkdir -p "$target_dir"
  log_info "Generating ${size}x${size} icon at $target_path"
  "${CONVERT_BIN[@]}" "$ICON_SOURCE" \
    -resize ${size}x${size} \
    -background none \
    -gravity center \
    -extent ${size}x${size} \
    "$target_path"
}

main() {
  ensure_dependencies

  if [[ ! -f "$ICON_SOURCE" ]]; then
    log_error "Icon source not found at $ICON_SOURCE"
    exit 1
  fi

  log_step "Generating Dragon icon variants"
  for size in "${SIZES[@]}"; do
    render_icon "$size"
  done
  log_success "Dragon icon variants ready in $OUTPUT_ROOT"
}

main "$@"
