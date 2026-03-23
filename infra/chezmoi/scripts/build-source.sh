#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHEZMOI_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${CHEZMOI_ROOT}/../.." && pwd)"

HOST_NAME=""
MANIFEST_PATH="${CHEZMOI_ROOT}/manifests/session-core.manifest"
OUTPUT_PATH=""

usage() {
  echo "Usage: $0 --host <hostname> [--manifest <path>] [--output <path>]" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)
      HOST_NAME="${2:-}"
      shift 2
      ;;
    --manifest)
      MANIFEST_PATH="${2:-}"
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

if [[ ! -f "${MANIFEST_PATH}" ]]; then
  echo "Manifest not found: ${MANIFEST_PATH}" >&2
  exit 1
fi

rm -rf "${OUTPUT_PATH}"
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

while IFS='|' read -r mode source_rel dest_rel; do
  [[ -z "${mode}" ]] && continue
  [[ "${mode}" =~ ^# ]] && continue

  if [[ "${mode}" != "required" && "${mode}" != "optional" ]]; then
    echo "Unknown manifest mode: ${mode}" >&2
    exit 1
  fi

  copy_entry "${mode}" "${source_rel}" "${dest_rel}"
done < "${MANIFEST_PATH}"

echo "Generated chezmoi source: ${OUTPUT_PATH}"
