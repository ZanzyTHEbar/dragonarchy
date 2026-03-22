#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
MANIFEST_PATH="${REPO_ROOT}/tools/pkgsolve/Cargo.toml"
TARGET_BIN="${REPO_ROOT}/tools/pkgsolve/target/release/pkgsolve"

resolve_cargo_bin() {
    if [[ -n "${PKGSOLVE_CARGO:-}" && -x "${PKGSOLVE_CARGO}" ]]; then
        printf '%s\n' "${PKGSOLVE_CARGO}"
        return 0
    fi

    local direct_stable="${HOME}/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin/cargo"
    if [[ -x "$direct_stable" ]]; then
        printf '%s\n' "$direct_stable"
        return 0
    fi

    command -v cargo
}

resolve_rustc_bin() {
    if [[ -n "${PKGSOLVE_RUSTC:-}" && -x "${PKGSOLVE_RUSTC}" ]]; then
        printf '%s\n' "${PKGSOLVE_RUSTC}"
        return 0
    fi

    local direct_stable="${HOME}/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin/rustc"
    if [[ -x "$direct_stable" ]]; then
        printf '%s\n' "$direct_stable"
        return 0
    fi

    command -v rustc
}

if [[ ! -f "$MANIFEST_PATH" ]]; then
    echo "pkgsolve manifest not found at ${MANIFEST_PATH}" >&2
    exit 1
fi

if ! CARGO_BIN="$(resolve_cargo_bin)"; then
    echo "cargo is required to build pkgsolve" >&2
    exit 1
fi

RUSTC_BIN="$(resolve_rustc_bin || true)"

if [[ -n "${RUSTC_BIN:-}" && -x "${RUSTC_BIN:-}" ]]; then
    env RUSTC="$RUSTC_BIN" "$CARGO_BIN" build --manifest-path "$MANIFEST_PATH" --release >&2
else
    "$CARGO_BIN" build --manifest-path "$MANIFEST_PATH" --release >&2
fi

printf '%s\n' "$TARGET_BIN"
