#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKER_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKSPACE="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-packer.XXXXXX")"

cleanup() {
    rm -rf "$WORKSPACE"
}

trap cleanup EXIT

if ! command -v packer >/dev/null 2>&1; then
    echo "run-packer-build.sh: packer is required" >&2
    exit 1
fi

cp "$PACKER_ROOT/plugins.pkr.hcl" "$WORKSPACE/"
cp "$PACKER_ROOT/variables.pkr.hcl" "$WORKSPACE/"
cp "$PACKER_ROOT"/sources/*.pkr.hcl "$WORKSPACE/"
cp "$PACKER_ROOT"/builds/*.pkr.hcl "$WORKSPACE/"
cp -a "$PACKER_ROOT/scripts" "$WORKSPACE/scripts"

shopt -s nullglob
for vars_file in \
    "$PACKER_ROOT"/*.pkrvars.hcl \
    "$PACKER_ROOT"/*.pkrvars.json \
    "$PACKER_ROOT"/*.auto.pkrvars.hcl \
    "$PACKER_ROOT"/*.auto.pkrvars.json
do
    cp "$vars_file" "$WORKSPACE/"
done
shopt -u nullglob

(
    cd "$WORKSPACE"
    packer init .
    packer build "$@" .
)
