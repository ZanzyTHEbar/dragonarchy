#!/usr/bin/env bash

# Shared wallpaper helpers for theme scripts.

if [[ -z ${THEME_WALLPAPER_UTILS_INITIALIZED:-} ]]; then
  THEME_WALLPAPER_UTILS_INITIALIZED=1
  THEME_WALLPAPER_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/theme-manager/wallpaper.conf"

  if [[ -f "$THEME_WALLPAPER_CONFIG" ]]; then
    # shellcheck disable=SC1090
    source "$THEME_WALLPAPER_CONFIG"
  fi

  theme_wallpaper_wayland_env() {
    THEME_WALLPAPER_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$UID}"
    THEME_WALLPAPER_DISPLAY="${WAYLAND_DISPLAY:-}"

    if [[ -z "$THEME_WALLPAPER_DISPLAY" && -d "$THEME_WALLPAPER_RUNTIME_DIR" ]]; then
      local candidate
      for candidate in "$THEME_WALLPAPER_RUNTIME_DIR"/wayland-*; do
        [[ -S "$candidate" ]] || continue
        THEME_WALLPAPER_DISPLAY="$(basename "$candidate")"
        break
      done
    fi
  }

  theme_wallpaper_env_run() {
    theme_wallpaper_wayland_env
    if [[ -n "${THEME_WALLPAPER_DISPLAY:-}" ]]; then
      XDG_RUNTIME_DIR="$THEME_WALLPAPER_RUNTIME_DIR" \
        WAYLAND_DISPLAY="$THEME_WALLPAPER_DISPLAY" \
        "$@"
    else
      "$@"
    fi
  }

  theme_wallpaper_env_run_bg() {
    theme_wallpaper_wayland_env
    if [[ -n "${THEME_WALLPAPER_DISPLAY:-}" ]]; then
      setsid env \
        XDG_RUNTIME_DIR="$THEME_WALLPAPER_RUNTIME_DIR" \
        WAYLAND_DISPLAY="$THEME_WALLPAPER_DISPLAY" \
        "$@" >/dev/null 2>&1 &
    else
      setsid "$@" >/dev/null 2>&1 &
    fi
  }

  theme_wallpaper_backend() {
    local backend="${WALLPAPER_BACKEND:-auto}"
    case "$backend" in
      auto)
        if command -v swww >/dev/null 2>&1; then
          backend="swww"
        else
          backend="swaybg"
        fi
        ;;
      swww|swaybg)
        ;;
      *)
        backend="swaybg"
        ;;
    esac
    printf '%s' "$backend"
  }

  theme_wallpaper_start_swww() {
    command -v swww-daemon >/dev/null 2>&1 || return 1
    local -a daemon_cmd=(swww-daemon)
    if command -v uwsm >/dev/null 2>&1; then
      daemon_cmd=(uwsm app -- swww-daemon)
    fi
    if [[ -n "${SWWW_DAEMON_ARGS:-}" ]]; then
      # shellcheck disable=SC2206
      daemon_cmd+=(${SWWW_DAEMON_ARGS})
    fi
    theme_wallpaper_env_run_bg "${daemon_cmd[@]}"
    return 0
  }

  theme_wallpaper_swww_ready() {
    local i
    for i in {1..20}; do
      if theme_wallpaper_env_run swww query >/dev/null 2>&1; then
        return 0
      fi
      sleep 0.05
    done
    return 1
  }

  theme_wallpaper_apply_color() {
    local color="${1:-${WALLPAPER_FALLBACK_COLOR:-#000000}}"
    pkill -x swaybg >/dev/null 2>&1 || true
    theme_wallpaper_env_run_bg uwsm app -- swaybg --color "$color"
  }

  theme_wallpaper_apply() {
    local image="${1:-}"
    local mode="${2:-${WALLPAPER_MODE:-fill}}"
    [[ -n "$image" ]] || return 1

    local backend
    backend="$(theme_wallpaper_backend)"

    if [[ "$backend" == "swww" && ! -x "$(command -v swww 2>/dev/null)" ]]; then
      backend="swaybg"
    fi

    if [[ "$backend" == "swww" ]]; then
      if ! theme_wallpaper_env_run swww query >/dev/null 2>&1; then
        theme_wallpaper_start_swww || true
      fi

      if ! theme_wallpaper_swww_ready; then
        backend="swaybg"
      fi
    fi

    if [[ "$backend" == "swww" ]]; then
      local type="${SWWW_TRANSITION_TYPE:-fade}"
      local fps="${SWWW_TRANSITION_FPS:-60}"
      local step="${SWWW_TRANSITION_STEP:-90}"
      local -a args=(img "$image")

      [[ -n "$type" ]] && args+=(--transition-type "$type")
      [[ -n "$fps" ]] && args+=(--transition-fps "$fps")
      [[ -n "$step" ]] && args+=(--transition-step "$step")
      [[ -n "${SWWW_TRANSITION_ANGLE:-}" ]] && args+=(--transition-angle "$SWWW_TRANSITION_ANGLE")
      [[ -n "${SWWW_TRANSITION_POS:-}" ]] && args+=(--transition-pos "$SWWW_TRANSITION_POS")

      if theme_wallpaper_env_run swww "${args[@]}" >/dev/null 2>&1; then
        pkill -x swaybg >/dev/null 2>&1 || true
        return 0
      fi
    fi

    pkill -x swaybg >/dev/null 2>&1 || true
    theme_wallpaper_env_run_bg uwsm app -- swaybg -i "$image" -m "$mode"
  }
fi
