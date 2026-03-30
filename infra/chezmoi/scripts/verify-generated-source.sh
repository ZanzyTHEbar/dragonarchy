#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHEZMOI_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

HOST_NAME=""
OUTPUT_PATH=""
declare -a MANIFEST_PATHS=()

usage() {
  echo "Usage: $0 --host <hostname> [--manifest <path>]... [--output <path>]" >&2
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
    --output)
      OUTPUT_PATH="${2:-}"
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

if [[ -z "${OUTPUT_PATH}" ]]; then
  OUTPUT_PATH="${CHEZMOI_ROOT}/generated/${HOST_NAME}"
fi

if [[ ${#MANIFEST_PATHS[@]} -eq 0 ]]; then
  MANIFEST_PATHS=(
    "${CHEZMOI_ROOT}/manifests/session-core.manifest"
    "${CHEZMOI_ROOT}/manifests/session-shell.manifest"
  )
fi

if [[ ! -d "${OUTPUT_PATH}" ]]; then
  echo "Generated source not found: ${OUTPUT_PATH}" >&2
  exit 1
fi

failures=0

check_entry() {
  local mode="$1"
  local dest_rel="$2"

  dest_rel="${dest_rel//__HOST__/${HOST_NAME}}"
  local dest_abs="${OUTPUT_PATH}/${dest_rel}"

  if [[ -e "${dest_abs}" ]]; then
    printf 'OK   %s\n' "${dest_rel}"
    return 0
  fi

  if [[ "${mode}" == "optional" ]]; then
    printf 'SKIP %s\n' "${dest_rel}"
    return 0
  fi

  printf 'MISS %s\n' "${dest_rel}" >&2
  failures=$((failures + 1))
}

check_excluded_entry() {
  local dest_rel="$1"

  dest_rel="${dest_rel//__HOST__/${HOST_NAME}}"
  local dest_abs="${OUTPUT_PATH}/${dest_rel}"

  if [[ ! -e "${dest_abs}" ]]; then
    printf 'EXCL %s\n' "${dest_rel}"
    return 0
  fi

  printf 'PRES %s\n' "${dest_rel}" >&2
  failures=$((failures + 1))
}

for manifest_path in "${MANIFEST_PATHS[@]}"; do
  if [[ ! -f "${manifest_path}" ]]; then
    echo "Manifest not found: ${manifest_path}" >&2
    exit 1
  fi

  while IFS='|' read -r mode _source_rel dest_rel; do
    [[ -z "${mode}" ]] && continue
    [[ "${mode}" =~ ^# ]] && continue
    if [[ "${mode}" == "exclude" ]]; then
      check_excluded_entry "${dest_rel}"
      continue
    fi
    check_entry "${mode}" "${dest_rel}"
  done < "${manifest_path}"
done

if [[ "${failures}" -ne 0 ]]; then
  exit 1
fi
