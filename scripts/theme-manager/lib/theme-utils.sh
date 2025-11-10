#!/usr/bin/env bash

# Utility helpers shared by theme generation scripts.

if [[ -z ${THEME_UTILS_INITIALIZED:-} ]]; then
  THEME_UTILS_INITIALIZED=1

  THEME_UTILS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  THEME_MANAGER_DIR="$(cd "$THEME_UTILS_DIR/.." && pwd)"
  DOTFILES_ROOT="$(cd "$THEME_MANAGER_DIR/../.." && pwd)"

  : "${THEMES_DIR:=$(cd "$DOTFILES_ROOT/packages/themes/.config/themes" && pwd)}"
fi

tm_strip_hash() {
  local value="${1#\#}"
  printf '%s' "${value,,}"
}

tm_compact_rgba() {
  local value="$1"
  value=${value//,/}
  value=${value// /}
  value=${value#rgba(}
  value=${value%\)}
  printf '%s' "$value"
}

tm_rgba_to_hex() {
  local compact
  compact="$(tm_compact_rgba "$1")"
  printf '#%s' "${compact:0:6}"
}

tm_hex_normalize() {
  printf '#%s' "$(tm_strip_hash "$1")"
}

tm_hex_blend() {
  local base mix weight inv
  base="$(tm_strip_hash "$1")"
  mix="$(tm_strip_hash "$2")"
  weight="${3:-50}"
  inv=$((100 - weight))
  local r=$(( ( (0x${base:0:2}) * inv + (0x${mix:0:2}) * weight + 50 ) / 100 ))
  local g=$(( ( (0x${base:2:2}) * inv + (0x${mix:2:2}) * weight + 50 ) / 100 ))
  local b=$(( ( (0x${base:4:2}) * inv + (0x${mix:4:2}) * weight + 50 ) / 100 ))
  printf '#%02x%02x%02x' "$r" "$g" "$b"
}

tm_palette_rgba() {
  local file="$1" key="$2"
  awk -v k="$key" '$1==("$"k) {print $3}' "$file" | sed -E 's/rgba\(([^)]*)\)/\1/' | tr -d ' \n' | head -n1 || true
}

tm_palette_hex() {
  local file="$1" key="$2" default="${3:-}"
  local raw
  raw="$(tm_palette_rgba "$file" "$key")"
  if [[ -z "$raw" ]]; then
    if [[ -n "$default" ]]; then
      tm_hex_normalize "$default"
      return 0
    fi
    return 1
  fi
  tm_rgba_to_hex "$raw"
}


