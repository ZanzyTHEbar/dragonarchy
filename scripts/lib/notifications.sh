#!/usr/bin/env bash
#
# notifications.sh - shared notification helpers
#
# Usage: source "${DOTFILES_ROOT}/scripts/lib/notifications.sh"
#

notify_send() {
  local app="" icon="" urgency="" expire="" wait=0
  local -a actions=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --app) app="$2"; shift 2 ;;
      --icon) icon="$2"; shift 2 ;;
      --urgency) urgency="$2"; shift 2 ;;
      --expire) expire="$2"; shift 2 ;;
      --action) actions+=("$2"); shift 2 ;;
      --wait) wait=1; shift ;;
      --) shift; break ;;
      *) break ;;
    esac
  done

  local title="${1:-}"
  local body="${2:-}"

  command -v notify-send >/dev/null 2>&1 || return 0

  local -a cmd=(notify-send)
  [[ -n "$app" ]] && cmd+=(--app-name="$app")
  [[ -n "$icon" ]] && cmd+=(--icon="$icon")
  [[ -n "$urgency" ]] && cmd+=(--urgency="$urgency")
  [[ -n "$expire" ]] && cmd+=(--expire-time="$expire")

  local supports_actions=0
  if [[ ${#actions[@]} -gt 0 || $wait -eq 1 ]]; then
    if notify-send --help 2>/dev/null | grep -q -- '--action'; then
      supports_actions=1
    fi
  fi

  if [[ $supports_actions -eq 1 ]]; then
    local action
    for action in "${actions[@]}"; do
      cmd+=(--action="$action")
    done
    [[ $wait -eq 1 ]] && cmd+=(--wait)
    "${cmd[@]}" "$title" "$body" 2>/dev/null || true
    return 0
  fi

  "${cmd[@]}" "$title" "$body" 2>/dev/null || true
}
