#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BASE_IMAGE="${1:-debian:bookworm-slim}"

if ! command -v docker >/dev/null 2>&1; then
    echo "docker is required to run the Debian headless smoke loop" >&2
    exit 1
fi

echo "Building Debian headless smoke image for ${BASE_IMAGE}..."
docker build \
    --progress=plain \
    --build-arg "BASE_IMAGE=${BASE_IMAGE}" \
    -f "${PROJECT_ROOT}/tests/docker/debian-headless/Dockerfile" \
    "${PROJECT_ROOT}"
