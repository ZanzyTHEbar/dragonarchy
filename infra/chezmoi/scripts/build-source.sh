#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHEZMOI_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${CHEZMOI_ROOT}/../.." && pwd)"

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

for manifest_path in "${MANIFEST_PATHS[@]}"; do
  if [[ ! -f "${manifest_path}" ]]; then
    echo "Manifest not found: ${manifest_path}" >&2
    exit 1
  fi
done

if [[ -e "${OUTPUT_PATH}" ]]; then
  rm -rf "${OUTPUT_PATH}"
fi

mkdir -p "${OUTPUT_PATH}"

copy_entry() {
  local mode="$1"
  local source_rel="$2"
  local dest_rel="$3"

  source_rel="${source_rel//__HOST__/${HOST_NAME}}"
  dest_rel="${dest_rel//__HOST__/${HOST_NAME}}"

  local source_abs="${REPO_ROOT}/${source_rel}"
  local dest_abs="${OUTPUT_PATH}/${dest_rel}"

  if [[ ! -e "${source_abs}" ]]; then
    if [[ "${mode}" == "optional" ]]; then
      return 0
    fi

    echo "Required source missing: ${source_rel}" >&2
    exit 1
  fi

  if [[ -d "${source_abs}" ]]; then
    mkdir -p "${dest_abs}"
    cp -a "${source_abs}/." "${dest_abs}/"
    return 0
  fi

  mkdir -p "$(dirname "${dest_abs}")"
  cp -a "${source_abs}" "${dest_abs}"
}

exclude_entry() {
  local dest_rel="$1"

  dest_rel="${dest_rel//__HOST__/${HOST_NAME}}"
  local dest_abs="${OUTPUT_PATH}/${dest_rel}"

  rm -rf "${dest_abs}"
}

for manifest_path in "${MANIFEST_PATHS[@]}"; do
  while IFS='|' read -r mode source_rel dest_rel; do
    [[ -z "${mode}" ]] && continue
    [[ "${mode}" =~ ^# ]] && continue

    if [[ "${mode}" != "required" && "${mode}" != "optional" && "${mode}" != "exclude" ]]; then
      echo "Unknown manifest mode in ${manifest_path}: ${mode}" >&2
      exit 1
    fi

    if [[ "${mode}" == "exclude" ]]; then
      exclude_entry "${dest_rel}"
      continue
    fi

    copy_entry "${mode}" "${source_rel}" "${dest_rel}"
  done < "${manifest_path}"
done

echo "Generated chezmoi source: ${OUTPUT_PATH}"
