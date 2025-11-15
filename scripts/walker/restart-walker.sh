#!/usr/bin/env bash
set -euo pipefail

kill_existing() {
  local pids
  mapfile -t pids < <(pgrep -f 'walker --gapplication-service' || true)
  [[ ${#pids[@]} -eq 0 ]] && return 0

  printf 'Stopping walker service (PIDs: %s)\n' "${pids[*]}" >&2
  kill "${pids[@]}" 2>/dev/null || true

  for pid in "${pids[@]}"; do
    for _ in {1..20}; do
      if ! kill -0 "$pid" >/dev/null 2>&1; then
        break
      fi
      sleep 0.1
    done
    if kill -0 "$pid" >/dev/null 2>&1; then
      printf 'PID %s still alive, forcing kill\n' "$pid" >&2
      kill -9 "$pid" 2>/dev/null || true
    fi
  done
}

start_walker() {
  printf 'Starting walker service\n' >&2
  setsid uwsm app -- walker --gapplication-service >/dev/null 2>&1 &
}

kill_existing
start_walker

printf 'Walker service restarted.\n'


