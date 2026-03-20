#!/usr/bin/env bash
#
# notification-daemon-cleanup.sh — find and remove notification daemons that
# compete with SwayNC (mako, dunst, deadd, etc.) so only SwayNC owns the name.
#
# Usage:
#   ./scripts/utilities/notification-daemon-cleanup.sh         # report only
#   ./scripts/utilities/notification-daemon-cleanup.sh --remove # uninstall & disable
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

# Known notification daemons that claim org.freedesktop.Notifications (compete with SwayNC)
# Format: "package_name" (Arch package name for uninstall)
COMPETITOR_PACKAGES=(
  mako
  dunst
  deadd-notification-center
  deadd-notification-center-git
  notify-osd
  xfce4-notifyd
  mate-notification-daemon
  gnome-shell  # provides notifications when running; usually not a "package" to remove
)

# systemd user units that often start notification daemons
COMPETITOR_SERVICES=(
  mako.service
  dunst.service
  deadd-notification-center.service
)

say() { printf '%s\n' "$*"; }
hr() { printf '\n%s\n' "------------------------------------------------------------"; }

REMOVE=false
if [[ "${1:-}" == "--remove" || "${1:-}" == "-r" ]]; then
  REMOVE=true
fi

say "Notification daemon cleanup (SwayNC is the desired daemon)"
say "Mode: $([ "$REMOVE" = true ] && echo 'REMOVE (will uninstall & disable)' || echo 'REPORT ONLY (use --remove to apply)')"
hr

# --- 1. Installed packages ---
say "### 1. Installed packages (competitors)"
FOUND_PKGS=()
for pkg in "${COMPETITOR_PACKAGES[@]}"; do
  # Skip gnome-shell etc. that we don't want to suggest removing
  if [[ "$pkg" == "gnome-shell" ]]; then
    continue
  fi
  if pacman -Q "$pkg" 2>/dev/null; then
    FOUND_PKGS+=("$pkg")
  fi
done
if [[ ${#FOUND_PKGS[@]} -eq 0 ]]; then
  say "None of the known competitor packages are installed."
else
  say "Installed: ${FOUND_PKGS[*]}"
  if [[ "$REMOVE" == true ]]; then
    say "Uninstalling (you will be prompted): sudo pacman -Rns ${FOUND_PKGS[*]}"
    sudo pacman -Rns "${FOUND_PKGS[@]}" || true
  fi
fi

# --- 2. systemd user services ---
hr
say "### 2. systemd user services (competitors)"
if ! command -v systemctl >/dev/null 2>&1; then
  say "systemctl not available, skipping."
else
  FOUND_SVCS=()
  for svc in "${COMPETITOR_SERVICES[@]}"; do
    if systemctl --user list-unit-files --type=service 2>/dev/null | grep -q "^${svc}"; then
      FOUND_SVCS+=("$svc")
      systemctl --user status "$svc" --no-pager 2>/dev/null | head -3 || true
    fi
  done
  if [[ ${#FOUND_SVCS[@]} -eq 0 ]]; then
    say "None of the known competitor user services exist."
  else
    say "Found user services: ${FOUND_SVCS[*]}"
    if [[ "$REMOVE" == true ]]; then
      for svc in "${FOUND_SVCS[@]}"; do
        systemctl --user disable --now "$svc" 2>/dev/null || true
        say "Disabled and stopped: $svc"
      done
    fi
  fi
fi

# --- 3. XDG autostart .desktop files ---
hr
say "### 3. XDG autostart (competitors)"
AUTOSTART_DIRS=(
  "${XDG_CONFIG_HOME:-$HOME/.config}/autostart"
  "/etc/xdg/autostart"
)
FOUND_DESKTOPS=()
for dir in "${AUTOSTART_DIRS[@]}"; do
  [[ ! -d "$dir" ]] && continue
  for f in "$dir"/*.desktop; do
    [[ ! -f "$f" ]] && continue
    matched=
    for pkg in mako dunst deadd notify-osd xfce4-notifyd mate-notification; do
      if grep -qi "Exec=.*${pkg}" "$f" 2>/dev/null || grep -qi "Exec=.*notification.*daemon" "$f" 2>/dev/null; then
        matched=1
        break
      fi
    done
    if [[ -n "${matched:-}" ]]; then
      FOUND_DESKTOPS+=("$f")
      say "Found: $f"
      grep -E "^Exec=|^Name=" "$f" 2>/dev/null | head -2 || true
    fi
  done
done
if [[ ${#FOUND_DESKTOPS[@]} -eq 0 ]]; then
  say "No competitor autostart .desktop files found."
else
  if [[ "$REMOVE" == true ]]; then
    for f in "${FOUND_DESKTOPS[@]}"; do
      if [[ "$f" == /etc/* ]]; then
        say "System autostart (override to disable): copy $f to ${XDG_CONFIG_HOME:-$HOME/.config}/autostart/ and set Hidden=true"
      else
        if [[ -w "$f" ]]; then
          if grep -q "^Hidden=true" "$f" 2>/dev/null; then
            say "Already disabled (Hidden=true): $f"
          else
            if grep -q "^\[Desktop Entry\]" "$f"; then
              sed -i '/^\[Desktop Entry\]/a Hidden=true' "$f"
              say "Set Hidden=true in: $f"
            else
              echo "Hidden=true" >> "$f"
              say "Appended Hidden=true to: $f"
            fi
          fi
        else
          say "No write permission, skip: $f"
        fi
      fi
    done
  fi
fi

# --- 4. Current DBus owner (informational) ---
hr
say "### 4. Current notification name owner (session bus)"
if command -v busctl >/dev/null 2>&1; then
  if busctl --user call org.freedesktop.Notifications /org/freedesktop/Notifications org.freedesktop.Notifications GetCapabilities 2>/dev/null | grep -q .; then
    say "org.freedesktop.Notifications is claimed (a daemon is active)."
    busctl --user list 2>/dev/null | grep -i notif || true
  else
    say "org.freedesktop.Notifications is not claimed (no daemon)."
  fi
else
  say "busctl not available."
fi

# --- Summary and next steps ---
hr
if [[ "$REMOVE" == true ]]; then
  say "Cleanup applied. Start SwayNC if needed:"
  say "  bash -lc '\$HOME/dotfiles/scripts/utilities/fix-notifications.sh'"
else
  say "To uninstall competitor packages and disable their services/autostart, run:"
  say "  $SCRIPT_DIR/notification-daemon-cleanup.sh --remove"
fi
say ""
