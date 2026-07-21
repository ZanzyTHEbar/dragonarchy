#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

_kill_vpn_cmd() {
  local iface="${VPN_IFACE}"
  cat <<EOF
pkill -INT openfortivpn 2>/dev/null || true
sleep 1
pkill -TERM openfortivpn 2>/dev/null || true
sleep 1
pkill -KILL openfortivpn 2>/dev/null || true
pkill -TERM pppd 2>/dev/null || true
pkill -KILL pppd 2>/dev/null || true
ip link set "${iface}" down 2>/dev/null || true
EOF
}

force_disconnect_root() {
  if have_cmd "$SUDO_CMD" && "$SUDO_CMD" -n true >/dev/null 2>&1; then
    "$SUDO_CMD" -n bash -lc "$(_kill_vpn_cmd)" >/dev/null 2>&1
    return 0
  fi

  if have_cmd pkexec; then
    pkexec bash -lc "$(_kill_vpn_cmd)" >/dev/null 2>&1
    return 0
  fi

  return 1
}

connect_vpn() {
  if ! enabled; then
    notify "VPN" "VPN widget disabled on this host."
    return 0
  fi

  local state
  state="$(vpn_state)"
  if [[ "$state" == "connected" ]]; then
    notify "VPN" "Already connected."
    return 0
  fi
  if [[ "$state" == "connecting" ]]; then
    notify "VPN" "Already connecting."
    return 0
  fi

  if ! have_cmd "$VPN_CMD"; then
    notify "VPN" "openfortivpn not found."
    return 1
  fi
  if [[ ! -f "$VPN_CONFIG" ]]; then
    notify "VPN" "Missing config: $VPN_CONFIG"
    return 1
  fi

  local saml_port url config_path
  saml_port="$SAML_PORT_DEFAULT"
  url="$(vpn_login_url || true)"
  config_path="$VPN_CONFIG"
  if systemd_service_exists && [[ -f /etc/openfortivpn/waybar.conf ]]; then
    config_path="/etc/openfortivpn/waybar.conf"
  fi
  local -a cmd=("$VPN_CMD" "--config" "$config_path" "--saml-login=$saml_port")
  if [[ -n "${OPENFORTIVPN_EXTRA_ARGS:-}" ]]; then
    local -a extra=()
    local old_ifs="$IFS"
    IFS=$' \n\t'
    read -r -a extra <<<"${OPENFORTIVPN_EXTRA_ARGS}"
    IFS="$old_ifs"
    cmd+=("${extra[@]}")
  fi

  if port_in_use "$saml_port"; then
    notify "VPN" "Port ${saml_port} is already in use. Stop the listener and retry."
    return 1
  fi

  if systemd_service_exists; then
    if systemd_is_active; then
      notify "VPN" "OpenFortiVPN is already running."
      return 0
    fi
    if stray_openfortivpn_running; then
      notify "VPN" "Stray OpenFortiVPN process detected; cleaning up."
      if systemd_cleanup_exists; then
        systemd_cleanup_vpn || true
      else
        force_disconnect_root || true
      fi
      wait_for_disconnect 5000 || true
    fi
    notify "VPN" "Starting OpenFortiVPN (auth prompt may appear)..."
    if ! systemd_start_vpn; then
      notify "VPN" "Failed to start OpenFortiVPN (check polkit prompt)."
      return 1
    fi
  elif have_cmd "$SUDO_CMD" && "$SUDO_CMD" -n true >/dev/null 2>&1; then
    notify "VPN" "Starting OpenFortiVPN in background..."
    run_background "$SUDO_CMD" -n "${cmd[@]}"
  elif have_cmd pkexec; then
    notify "VPN" "Starting OpenFortiVPN (polkit prompt may appear)..."
    run_background pkexec "${cmd[@]}"
  else
    notify "VPN" "Need sudo or pkexec to start OpenFortiVPN."
    return 1
  fi

  if ! wait_for_port "$saml_port" 6000; then
    notify "VPN" "SAML listener not ready on port ${saml_port}."
    return 1
  fi

  if [[ -n "$url" ]]; then
    notify_action_open_url "$url" || notify "VPN" "Open login: $url"
  else
    notify "VPN" "SAML login URL not available."
  fi
}

disconnect_vpn() {
  if ! vpn_proc_running && ! vpn_iface_up && !(systemd_service_exists && systemd_is_active); then
    notify "VPN" "Already disconnected."
    return 0
  fi

  # If openfortivpn is running outside systemd, kill directly.
  if vpn_proc_running && !(systemd_service_exists && systemd_is_active); then
    notify "VPN" "Disconnecting (auth prompt may appear)..."
    if systemd_cleanup_exists; then
      systemd_cleanup_vpn || true
    else
      force_disconnect_root || true
    fi
    wait_for_disconnect 6000 || true
    if ! vpn_proc_running && ! vpn_iface_up; then
      notify "VPN" "Disconnected."
      return 0
    fi
    notify "VPN" "Disconnect failed; OpenFortiVPN still running."
    return 1
  fi

  if systemd_service_exists; then
    notify "VPN" "Disconnecting (auth prompt may appear)..."
    if ! systemd_stop_vpn; then
      notify "VPN" "Failed to stop OpenFortiVPN (check polkit prompt)."
      return 1
    fi
    if wait_for_disconnect 6000; then
      notify "VPN" "Disconnected."
      return 0
    fi
    if have_cmd systemctl; then
      systemctl kill --signal=SIGINT openfortivpn.service >/dev/null 2>&1 || true
    fi
    if wait_for_disconnect 4000; then
      notify "VPN" "Disconnected."
      return 0
    fi
    if systemd_cleanup_exists; then
      systemd_cleanup_vpn || true
    else
      force_disconnect_root || true
    fi
    if wait_for_disconnect 3000; then
      notify "VPN" "Disconnected."
      return 0
    fi
    notify "VPN" "Disconnect failed; OpenFortiVPN still running."
    return 1
  fi

  if have_cmd "$SUDO_CMD" && "$SUDO_CMD" -n true >/dev/null 2>&1; then
    "$SUDO_CMD" -n pkill -INT "$VPN_PROC_NAME" >/dev/null 2>&1 || true
    notify "VPN" "Disconnecting..."
    return 0
  fi

  if have_cmd pkexec; then
    run_background pkexec pkill -INT "$VPN_PROC_NAME"
    notify "VPN" "Disconnecting (polkit prompt may appear)..."
    return 0
  fi

  notify "VPN" "Need sudo or pkexec to disconnect."
}

toggle_vpn() {
  local state
  state="$(vpn_state)"
  if [[ "$state" == "connected" || "$state" == "connecting" || "$state" == "error" ]]; then
    disconnect_vpn
  else
    connect_vpn
  fi
}
