#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

json_escape() {
  local value="$1"
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//$'\n'/\\n}
  printf "%s" "$value"
}

notify() {
  local title="$1"
  local body="${2:-}"
  notify_send --app "VPN" "$title" "$body"
}

open_url() {
  local url="$1"
  if have_cmd xdg-open; then
    xdg-open "$url" >/dev/null 2>&1 || true
    return 0
  fi
  if have_cmd gio; then
    gio open "$url" >/dev/null 2>&1 || true
    return 0
  fi
  return 1
}

notify_action_open_url() {
  local url="$1"
  (
    local action=""
    action="$(notify_send --app "VPN" \
      --action "open=Open Login" \
      --action "copy=Copy Link" \
      --wait \
      -- "VPN Login" "Click to open SAML login" || true)"
    case "$action" in
      open)
        open_url "$url"
        ;;
      copy)
        if have_cmd wl-copy; then
          printf "%s" "$url" | wl-copy
        elif have_cmd xclip; then
          printf "%s" "$url" | xclip -selection clipboard
        fi
        ;;
      *)
        notify_send --app "VPN" -- "VPN Login" "Open this URL: $url" >/dev/null 2>&1 || true
        ;;
    esac
  ) &
  disown || true
  return 0
}

status_json() {
  if ! enabled; then
    echo '{"text":"","alt":"","tooltip":"","class":"hidden"}'
    return 0
  fi

  if ! have_cmd "$VPN_CMD"; then
    echo '{"text":"","alt":"error","tooltip":"openfortivpn not found","class":"error"}'
    return 0
  fi

  if [[ -f "$VPN_CONFIG" && ! -r "$VPN_CONFIG" ]]; then
    echo "{\"text\":\"\",\"alt\":\"error\",\"tooltip\":\"$(json_escape "Permission denied reading: $VPN_CONFIG")\",\"class\":\"error\"}"
    return 0
  fi

  if [[ ! -f "$VPN_CONFIG" ]]; then
    echo "{\"text\":\"\",\"alt\":\"error\",\"tooltip\":\"$(json_escape "Missing config: $VPN_CONFIG")\",\"class\":\"error\"}"
    return 0
  fi

  local state tooltip host addr
  state="$(vpn_state)"
  host="$(config_value host)"
  addr="$(vpn_addr)"

  case "$state" in
    connected)
      tooltip="VPN: connected"
      ;;
    connecting)
      tooltip="VPN: connecting"
      ;;
    *)
      tooltip="VPN: disconnected"
      ;;
  esac

  if [[ -n "$host" ]]; then
    tooltip="${tooltip}"$'\n'"Host: ${host}"
  fi
  if [[ -n "$addr" && "$state" == "connected" ]]; then
    tooltip="${tooltip}"$'\n'"IP: ${addr}"
  fi

  tooltip="${tooltip}"$'\n'"Left: toggle | Middle: connect | Right: disconnect"
  if [[ "$state" == "error" ]]; then
    tooltip="${tooltip}"$'\n'"Stray OpenFortiVPN process detected; click to disconnect"
  fi

  echo "{\"text\":\"\",\"alt\":\"$(json_escape "$state")\",\"tooltip\":\"$(json_escape "$tooltip")\",\"class\":\"$(json_escape "$state")\"}"
}
