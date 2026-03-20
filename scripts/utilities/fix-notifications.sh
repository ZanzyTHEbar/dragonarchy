#!/usr/bin/env bash
#
# fix-notifications.sh — ensure SwayNC (and related) is running so desktop
# notifications work. Use after a reboot or update when notifications stop.
#
# Usage: bash -lc '$HOME/dotfiles/scripts/utilities/fix-notifications.sh'
#   Or from repo: ./scripts/utilities/fix-notifications.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

say() { printf '%s\n' "$*"; }
hr() { printf '\n%s\n' "------------------------------------------------------------"; }

say "Notification daemon (SwayNC) check"
hr

# 1. Is swaync running?
if pgrep -x swaync >/dev/null 2>&1; then
  say "OK  swaync is running (PID: $(pgrep -x swaync))"
else
  say "MISS  swaync is not running"
fi

# 2. Optional: DBus name (who owns org.freedesktop.Notifications)
if command -v busctl >/dev/null 2>&1; then
  if busctl --user call org.freedesktop.Notifications /org/freedesktop/Notifications org.freedesktop.Notifications GetCapabilities 2>/dev/null | grep -q .; then
    say "OK  org.freedesktop.Notifications is claimed (notifications daemon present)"
  else
    say "MISS  org.freedesktop.Notifications not claimed (no daemon)"
  fi
else
  say "SKIP  busctl not available (cannot check DBus name)"
fi

# 3. If something else holds the notification name, kill known competitors so SwayNC can claim it
COMPETITORS=(mako dunst deadd-notification-center)
KILLED=()
for proc in "${COMPETITORS[@]}"; do
  if pgrep -x "$proc" >/dev/null 2>&1; then
    pkill -x "$proc" 2>/dev/null || true
    sleep 0.2
    KILLED+=("$proc")
  fi
done
if [[ ${#KILLED[@]} -gt 0 ]]; then
  say "Killed competing notification daemon(s): ${KILLED[*]} (so SwayNC can claim the name)"
  hr
fi

# 4. Try to start swaync if missing
if ! pgrep -x swaync >/dev/null 2>&1; then
  hr
  say "Attempting to start swaync..."

  if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && command -v hyprctl >/dev/null 2>&1; then
    hyprctl dispatch exec "uwsm app -- swaync" 2>/dev/null || true
    sleep 1
    if pgrep -x swaync >/dev/null 2>&1; then
      say "OK  swaync started via hyprctl + uwsm"
    else
      say "WARN hyprctl exec may have failed; try starting manually (see below)"
    fi
  elif command -v uwsm >/dev/null 2>&1 && uwsm check is-active >/dev/null 2>&1; then
    uwsm app -- swaync &
    sleep 1
    if pgrep -x swaync >/dev/null 2>&1; then
      say "OK  swaync started via uwsm"
    else
      say "WARN uwsm app may have failed; try starting manually (see below)"
    fi
  else
    say "WARN Not in Hyprland or uwsm not active; run swaync manually in a terminal to see errors"
  fi
fi

# 5. Test notification
hr
if pgrep -x swaync >/dev/null 2>&1; then
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "Notifications" "If you see this, SwayNC is working." -t 3000 2>/dev/null && say "OK  Test notification sent" || say "WARN notify-send failed"
  fi
else
  say "If swaync still won't start, another daemon may hold the name. Kill it then start SwayNC:"
  say "  pkill -x mako; pkill -x dunst; swaync"
  say "To see what claims the notification name:  busctl --user list | grep -i notif"
  say "Or run swaync in a terminal to see errors (e.g. missing /etc/xdg/swaync/configSchema.json)."
  say "Reinstall if needed:  paru -S swaync"
fi

# 6. Full autostart restart option
hr
say "To restart all autostart services (waybar, swaync, hypridle, etc.):"
say "  bash -lc '\$HOME/dotfiles/scripts/theme-manager/restart-autostart'"
say ""
