#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PKGSOLVE_ROOT="${REPO_ROOT}/tools/pkgsolve"
TOOLCHAIN="${PKGSOLVE_TOOLCHAIN:-stable-x86_64-unknown-linux-gnu}"
RUSTUP_BIN="${PKGSOLVE_RUSTUP:-$(command -v rustup || true)}"

shopt -s globstar nullglob

rustfmt_is_usable() {
    local rustfmt_bin="$1"
    [[ -x "$rustfmt_bin" ]] || return 1
    "$rustfmt_bin" --version >/dev/null 2>&1
}

resolve_rustfmt_bin() {
    if [[ -n "${PKGSOLVE_RUSTFMT:-}" && -x "${PKGSOLVE_RUSTFMT}" ]]; then
        if rustfmt_is_usable "${PKGSOLVE_RUSTFMT}"; then
            printf '%s\n' "${PKGSOLVE_RUSTFMT}"
            return 0
        fi
    fi

    local candidates=(
        "${HOME}/.rustup/toolchains/${TOOLCHAIN}/bin/rustfmt"
        "${HOME}/.rustup/toolchains/${TOOLCHAIN}/lib/rustlib/"*/bin/rustfmt
    )
    local candidate
    for candidate in "${candidates[@]}"; do
        if rustfmt_is_usable "$candidate"; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    if [[ -n "${RUSTUP_BIN}" && -x "${RUSTUP_BIN}" ]]; then
        (exec -a rustup "${RUSTUP_BIN}" component add rustfmt --toolchain "${TOOLCHAIN}") >&2
        candidates=(
            "${HOME}/.rustup/toolchains/${TOOLCHAIN}/bin/rustfmt"
            "${HOME}/.rustup/toolchains/${TOOLCHAIN}/lib/rustlib/"*/bin/rustfmt
        )
        for candidate in "${candidates[@]}"; do
            if rustfmt_is_usable "$candidate"; then
                printf '%s\n' "$candidate"
                return 0
            fi
        done
    fi

    if command -v rustfmt >/dev/null 2>&1; then
        local path_rustfmt
        path_rustfmt="$(command -v rustfmt)"
        if rustfmt_is_usable "$path_rustfmt"; then
            printf '%s\n' "$path_rustfmt"
            return 0
        fi
    fi

    return 1
}

run_docker_rustfmt() {
    if ! command -v docker >/dev/null 2>&1; then
        echo "rustfmt is unavailable locally and docker is not installed for fallback formatting" >&2
        return 1
    fi

    local relative_files=()
    local rust_file
    for rust_file in "${rust_files[@]}"; do
        relative_files+=("${rust_file#${REPO_ROOT}/}")
    done

    echo "local rustfmt proxy is unusable; falling back to Dockerized rustfmt" >&2
    docker run --rm \
        -v "${REPO_ROOT}:/work" \
        -w /work \
        debian:bookworm-slim \
        bash -lc 'apt-get update >/dev/null && apt-get install -y rustfmt >/dev/null && rustfmt --edition 2021 "$@"' \
        bash \
        "$@" \
        "${relative_files[@]}"
}

if [[ ! -d "${PKGSOLVE_ROOT}" ]]; then
    echo "pkgsolve source directory not found at ${PKGSOLVE_ROOT}" >&2
    exit 1
fi

rust_files=(
    "${PKGSOLVE_ROOT}"/*.rs
    "${PKGSOLVE_ROOT}"/src/**/*.rs
    "${PKGSOLVE_ROOT}"/tests/**/*.rs
)

if [[ "${#rust_files[@]}" -eq 0 ]]; then
    echo "no Rust sources found under ${PKGSOLVE_ROOT}" >&2
    exit 1
fi

if RUSTFMT_BIN="$(resolve_rustfmt_bin)"; then
    "${RUSTFMT_BIN}" --edition 2021 "$@" "${rust_files[@]}"
else
    run_docker_rustfmt "$@"
fi
