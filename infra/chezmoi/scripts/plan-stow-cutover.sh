#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHEZMOI_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

HOST_NAME=""
declare -a MANIFEST_PATHS=()

usage() {
  echo "Usage: $0 --host <hostname> [--manifest <path>]..." >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)
      HOST_NAME="${2:-}"
      shift 2
      ;;
    --manifest)
      MANIFEST_PATHS+=("${2:-}")
      shift 2
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

if [[ -z "${HOST_NAME}" ]]; then
  usage
  exit 2
fi

if [[ ${#MANIFEST_PATHS[@]} -eq 0 ]]; then
  MANIFEST_PATHS=(
    "${CHEZMOI_ROOT}/manifests/session-core.manifest"
    "${CHEZMOI_ROOT}/manifests/session-shell.manifest"
  )
fi

for manifest_path in "${MANIFEST_PATHS[@]}"; do
  if [[ ! -f "${manifest_path}" ]]; then
    echo "Manifest not found: ${manifest_path}" >&2
    exit 1
  fi
done

dest_to_home_rel() {
  local dest_rel="$1"
  dest_rel="${dest_rel//__HOST__/${HOST_NAME}}"

  local first_segment="${dest_rel%%/*}"
  local remainder=""
  if [[ "${dest_rel}" == */* ]]; then
    remainder="/${dest_rel#*/}"
  fi

  case "${first_segment}" in
    dot_*)
      printf '.%s%s\n' "${first_segment#dot_}" "${remainder}"
      ;;
    *)
      printf '%s\n' "${dest_rel}"
      ;;
  esac
}

regex_escape() {
  python - "$1" <<'PY'
import re
import sys
print(re.escape(sys.argv[1]))
PY
}

declare -A package_paths=()
declare -A host_paths=()
declare -a migrated_paths=()

while IFS='|' read -r mode source_rel dest_rel; do
  [[ -z "${mode}" ]] && continue
  [[ "${mode}" =~ ^# ]] && continue
  [[ "${mode}" == "exclude" ]] && continue

  source_rel="${source_rel//__HOST__/${HOST_NAME}}"
  dest_rel="${dest_rel//__HOST__/${HOST_NAME}}"
  home_rel="$(dest_to_home_rel "${dest_rel}")"

  migrated_paths+=("${home_rel}")

  case "${source_rel}" in
    packages/*)
      package_name="${source_rel#packages/}"
      package_name="${package_name%%/*}"
      package_paths["${package_name}"]+="${home_rel}"$'\n'
      ;;
    hosts/*/dotfiles/*)
      host_name="${source_rel#hosts/}"
      host_name="${host_name%%/*}"
      host_paths["${host_name}"]+="${home_rel}"$'\n'
      ;;
  esac
done < <(
  for manifest_path in "${MANIFEST_PATHS[@]}"; do
    cat "${manifest_path}"
  done
)

printf 'Migrated home-relative paths:\n'
printf '%s\n' "${migrated_paths[@]}" | sort -u | sed 's/^/  - /'

for package_name in $(printf '%s\n' "${!package_paths[@]}" | sort); do
  printf '\nPackage carve-out for `%s`:\n' "${package_name}"
  ignore_flags=()
  while IFS= read -r path; do
    [[ -z "${path}" ]] && continue
    escaped="$(regex_escape "${path}")"
    ignore_flags+=("--ignore=^${escaped}(/|\$)")
  done < <(printf '%s' "${package_paths[${package_name}]}" | sort -u)

  printf '  %s\n' "stow --restow -d packages -t \"\$HOME\" ${ignore_flags[*]} ${package_name}"
done

for host_name in $(printf '%s\n' "${!host_paths[@]}" | sort); do
  printf '\nHost dotfiles carve-out for `%s`:\n' "${host_name}"
  ignore_flags=()
  while IFS= read -r path; do
    [[ -z "${path}" ]] && continue
    escaped="$(regex_escape "${path}")"
    ignore_flags+=("--ignore=^${escaped}(/|\$)")
  done < <(printf '%s' "${host_paths[${host_name}]}" | sort -u)

  printf '  %s\n' "(cd hosts/${host_name}/dotfiles && stow --no-folding --restow -t \"\$HOME\" ${ignore_flags[*]} .)"
done
