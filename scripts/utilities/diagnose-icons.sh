#!/usr/bin/env bash
# Diagnose icon rendering issues (Waybar tray, Walker search results, notifications).
#
# This prints high-signal checks:
# - GTK icon theme config
# - SVG decoding path (gdk-pixbuf + glycin + librsvg)
# - Common missing icon names referenced by .desktop files
#
# Safe to run without sudo. If you want to refresh icon cache, re-run with sudo:
#   sudo ./scripts/utilities/diagnose-icons.sh --refresh-cache

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

say() { printf '%s\n' "$*"; }
hr() { printf '\n%s\n' "------------------------------------------------------------"; }

REFRESH_CACHE=false
if [[ "${1:-}" == "--refresh-cache" ]]; then
  REFRESH_CACHE=true
fi

say "dotfiles icon diagnostics"
say "repo: $REPO_ROOT"
hr

say "### Packages"
for p in adwaita-icon-theme hicolor-icon-theme librsvg gdk-pixbuf2 glycin glycin-gtk4; do
  if pacman -Qi "$p" >/dev/null 2>&1; then
    ver="$(pacman -Qi "$p" | awk -F': ' '/^Version/{print $2; exit}')"
    say "OK  $p ($ver)"
  else
    say "MISSING  $p"
  fi
done

hr
say "### GTK settings (gsettings)"
if command -v gsettings >/dev/null 2>&1; then
  say "gtk-theme:  $(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null || echo '?')"
  say "icon-theme: $(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null || echo '?')"
else
  say "gsettings not available"
fi

hr
say "### User-level hicolor override check"
user_hicolor="$HOME/.local/share/icons/hicolor/index.theme"
if [[ -e "$user_hicolor" || -L "$user_hicolor" ]]; then
  say "FOUND  $user_hicolor"
  if [[ -L "$user_hicolor" ]]; then
    say " -> $(readlink -f "$user_hicolor" 2>/dev/null || true)"
  fi
  say "NOTE: A user-level hicolor index.theme overrides /usr/share/icons/hicolor/index.theme and can break icon lookup."
else
  say "OK  no user-level hicolor index.theme override"
fi

hr
say "### SVG decode sanity"
tmp_png="$(mktemp --suffix=.png /tmp/dotfiles-icon-test.XXXXXX 2>/dev/null || mktemp /tmp/dotfiles-icon-test.XXXXXX)"
tmp_c="$(mktemp --suffix=.c /tmp/dotfiles-icon-test.XXXXXX 2>/dev/null || mktemp /tmp/dotfiles-icon-test.XXXXXX)"
cleanup() {
  rm -f "$tmp_png" "$tmp_c" 2>/dev/null || true
}
trap cleanup EXIT

if command -v rsvg-convert >/dev/null 2>&1; then
  if rsvg-convert /usr/share/icons/hicolor/scalable/apps/btrfs-assistant.svg -o "$tmp_png" >/dev/null 2>&1; then
    say "OK  librsvg can render SVG (rsvg-convert)"
  else
    say "FAIL  rsvg-convert could not render SVG"
  fi
else
  say "MISSING  rsvg-convert"
fi

if command -v gdk-pixbuf-pixdata >/dev/null 2>&1; then
  if gdk-pixbuf-pixdata /usr/share/icons/hicolor/scalable/apps/btrfs-assistant.svg "$tmp_c" >/dev/null 2>&1; then
    say "OK  gdk-pixbuf can decode SVG (via glycin/gdk-pixbuf)"
  else
    say "FAIL  gdk-pixbuf could not decode SVG"
  fi
else
  say "MISSING  gdk-pixbuf-pixdata"
fi

hr
say "### Icon name existence (hicolor/scalable/apps)"
declare -a names=(
  "btrfs-assistant.svg"
  "cachy-update.svg"
  "cachy-update-blue.svg"
  "cachy-update_updates-available.svg"
  "cachy-update_updates-available-blue.svg"
  "arch-update-blue.svg"
  "arch-update_updates-available-blue.svg"
  "org.cachyos.hello.svg"
)
for f in "${names[@]}"; do
  if [[ -e "/usr/share/icons/hicolor/scalable/apps/$f" ]]; then
    if [[ -L "/usr/share/icons/hicolor/scalable/apps/$f" ]]; then
      say "OK  $f -> $(readlink -f "/usr/share/icons/hicolor/scalable/apps/$f")"
    else
      say "OK  $f"
    fi
  else
    say "MISSING  $f"
  fi
done

hr
say "### .desktop Icon= references (subset)"
if [[ -d /usr/share/applications ]]; then
  rg -n "^Icon=" /usr/share/applications/*.desktop 2>/dev/null | rg -n "arch-update|cachy|cachyos|btrfs|actual" | head -n 200 || true
else
  say "/usr/share/applications not present?"
fi

hr
say "### Optional: refresh icon cache"
if [[ "$REFRESH_CACHE" == "true" ]]; then
  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f /usr/share/icons/hicolor || true
    say "Ran gtk-update-icon-cache -f /usr/share/icons/hicolor"
  else
    say "gtk-update-icon-cache not available"
  fi
else
  say "Skip (run with --refresh-cache, preferably under sudo)"
fi

