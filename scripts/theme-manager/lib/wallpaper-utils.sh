#!/usr/bin/env bash
# Installed preference/backend selection; no detached writers or fallback after failure.
THEME_WALLPAPER_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/theme-manager/wallpaper.conf"
if [[ -f "$THEME_WALLPAPER_CONFIG" ]]; then
    source "$THEME_WALLPAPER_CONFIG"
fi
theme_wallpaper_backend() {
    local backend="${WALLPAPER_BACKEND:-auto}"
    if [[ "$backend" == auto ]]; then
        if command -v swww >/dev/null 2>&1 && command -v swww-daemon >/dev/null 2>&1; then backend=swww; else backend=swaybg; fi
    fi
    case "$backend" in
        swww) command -v swww >/dev/null && command -v swww-daemon >/dev/null ;;
        swaybg) command -v swaybg >/dev/null ;;
        *) echo "Unsupported wallpaper backend: $backend" >&2; return 2 ;;
    esac || { echo "Configured wallpaper backend is unavailable: $backend" >&2; return 1; }
    printf '%s\n' "$backend"
}

# Remaining legacy menu callers use the installed owner too; no second writer.
theme_wallpaper_apply() {
    "$HOME/.local/bin/theme-bg-apply"
}
