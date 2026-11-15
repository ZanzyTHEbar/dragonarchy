#!/usr/bin/env bash

set -euo pipefail

SCRIPT_PATH="$(readlink -f -- "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname -- "$SCRIPT_PATH")" && pwd -P)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd -P)"

IMAGE_URL_DEFAULT="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2"
WORKDIR_DEFAULT="${TMPDIR:-/tmp}/dotfiles-debian-vm-e2e"
WORKDIR_MARKER_NAME=".dotfiles-debian-vm-e2e-owned"
WORKDIR_MARKER_CONTENT="dotfiles-debian-vm-e2e-workdir-v1"
SSH_PORT_DEFAULT="2222"
MEMORY_MB_DEFAULT="4096"
CPUS_DEFAULT="2"
VM_NAME_DEFAULT="dotfiles-debian-headless-e2e"
BOOT_TIMEOUT_SEC_DEFAULT="900"
HOST_NAME_DEFAULT="headless"
BUNDLE_NAME_DEFAULT="minimal"

IMAGE_URL="$IMAGE_URL_DEFAULT"
WORKDIR="$WORKDIR_DEFAULT"
ARTIFACT_DIR=""
SSH_PORT="$SSH_PORT_DEFAULT"
MEMORY_MB="$MEMORY_MB_DEFAULT"
CPUS="$CPUS_DEFAULT"
VM_NAME="$VM_NAME_DEFAULT"
BOOT_TIMEOUT_SEC="$BOOT_TIMEOUT_SEC_DEFAULT"
KEEP_VM=false
CLEANUP_WORKDIR=false
WITH_SYSTEM_CONFIG=false
VM_BOOTED=false
ARTIFACTS_COLLECTED=false
WORKDIR_VALIDATED=false
ARTIFACT_DIR_EXTERNAL=false
HOST_NAME="$HOST_NAME_DEFAULT"
BUNDLE_NAME="$BUNDLE_NAME_DEFAULT"
VALIDATE_BUNDLE=""
RUN_FIRST_RUN_COMMAND=true
INSTALL_EXTRA_FLAGS=()
BASE_IMAGE_FORMAT="qcow2"

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Boot a Debian cloud image under QEMU, provision the repo over SSH, and run a
systemd-aware headless install smoke loop inside the guest.

Options:
  --image-url URL          Override Debian cloud image URL
  --workdir PATH           Working directory for downloaded images and VM state
  --artifact-dir PATH      Directory to write serial logs and collected guest artifacts
  --ssh-port PORT          Host port forwarded to guest SSH (default: ${SSH_PORT_DEFAULT})
  --memory-mb MB           Guest RAM in MiB (default: ${MEMORY_MB_DEFAULT})
  --cpus N                 Guest vCPU count (default: ${CPUS_DEFAULT})
  --vm-name NAME           Guest hostname / instance ID
  --boot-timeout-sec SEC   Seconds to wait for guest SSH/systemd (default: ${BOOT_TIMEOUT_SEC_DEFAULT})
  --host NAME              Host profile to pass to install.sh / validate.sh (default: ${HOST_NAME_DEFAULT})
  --bundle NAME            Bundle to pass to install.sh (default: ${BUNDLE_NAME_DEFAULT})
  --validate-bundle NAME   Bundle context for validate.sh (default: same as --bundle)
  --install-extra-flag X   Extra flag to pass through to install.sh (repeatable)
  --skip-first-run-command Do not execute scripts/install/first-run.sh after install
  --with-system-config     Include install.sh system configuration step
  --keep-vm                Do not clean up the VM process on exit
  --cleanup-workdir        Remove a validated owned workdir on exit
  -h, --help               Show this help
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --image-url)
                IMAGE_URL="$2"
                shift 2
                ;;
            --workdir)
                WORKDIR="$2"
                shift 2
                ;;
            --artifact-dir)
                ARTIFACT_DIR="$2"
                ARTIFACT_DIR_EXTERNAL=true
                shift 2
                ;;
            --ssh-port)
                SSH_PORT="$2"
                shift 2
                ;;
            --memory-mb)
                MEMORY_MB="$2"
                shift 2
                ;;
            --cpus)
                CPUS="$2"
                shift 2
                ;;
            --vm-name)
                VM_NAME="$2"
                shift 2
                ;;
            --boot-timeout-sec)
                BOOT_TIMEOUT_SEC="$2"
                shift 2
                ;;
            --host)
                HOST_NAME="$2"
                shift 2
                ;;
            --bundle)
                BUNDLE_NAME="$2"
                shift 2
                ;;
            --validate-bundle)
                VALIDATE_BUNDLE="$2"
                shift 2
                ;;
            --install-extra-flag)
                INSTALL_EXTRA_FLAGS+=("$2")
                shift 2
                ;;
            --skip-first-run-command)
                RUN_FIRST_RUN_COMMAND=false
                shift
                ;;
            --with-system-config)
                WITH_SYSTEM_CONFIG=true
                shift
                ;;
            --keep-vm)
                KEEP_VM=true
                shift
                ;;
            --cleanup-workdir)
                CLEANUP_WORKDIR=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                usage >&2
                exit 1
                ;;
        esac
    done
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Missing required command: $1" >&2
        exit 1
    }
}

normalize_path() {
    local path="$1"
    if [[ "$path" != /* ]]; then
        path="$PWD/$path"
    fi
    readlink -m -- "$path"
}

path_has_symlink() {
    local path="$1"
    local current="/"
    local component
    local -a components

    if [[ "$path" != /* ]]; then
        path="$PWD/$path"
    fi
    IFS='/' read -r -a components <<< "${path#/}"
    for component in "${components[@]}"; do
        [[ -z "$component" || "$component" == "." ]] && continue
        if [[ "$component" == ".." ]]; then
            if [[ "$current" != "/" ]]; then
                current="${current%/*}"
                [[ -n "$current" ]] || current="/"
            fi
            continue
        fi
        if [[ "$current" == "/" ]]; then
            current="/$component"
        else
            current="$current/$component"
        fi
        [[ -L "$current" ]] && return 0
    done
    return 1
}

path_is_same_or_below() {
    [[ "$1" == "$2" || "$1" == "$2/"* ]]
}

unsafe_workdir_location() {
    local path="$1"
    local home_path=""

    [[ "$path" == "/" ]] && return 0
    if [[ -n "${HOME:-}" ]]; then
        home_path="$(normalize_path "$HOME")" || return 0
        path_is_same_or_below "$path" "$home_path" && return 0
    fi
    path_is_same_or_below "$path" "$PROJECT_ROOT" && return 0
    return 1
}

current_user_owns() {
    [[ "$(stat -c '%u' -- "$1")" == "$(id -u)" ]]
}

private_directory() {
    local mode
    mode="$(stat -c '%a' -- "$1")" || return 1
    (( (8#$mode & 0022) == 0 ))
}

safe_existing_parent() {
    local path="$1"
    local owner mode

    [[ -d "$path" && ! -L "$path" ]] || return 1
    path="$(normalize_path "$path")" || return 1
    path_has_symlink "$path" && return 1
    [[ "$path" != "/" ]] || return 1

    owner="$(stat -c '%u' -- "$path")" || return 1
    mode="$(stat -c '%a' -- "$path")" || return 1
    [[ "$owner" == "$(id -u)" || "$mode" == "1777" ]]
}

valid_workdir_marker() {
    local marker="$1"
    local marker_size

    [[ -f "$marker" && ! -L "$marker" ]] || return 1
    current_user_owns "$marker" || return 1
    marker_size="$(stat -c '%s' -- "$marker")" || return 1
    [[ "$marker_size" -eq "${#WORKDIR_MARKER_CONTENT}" ]] || return 1
    [[ "$(<"$marker")" == "$WORKDIR_MARKER_CONTENT" ]]
}

validate_owned_workdir() {
    local requested="$1"
    local path marker

    [[ -n "$requested" ]] || return 1
    path_has_symlink "$requested" && return 1
    path="$(normalize_path "$requested")" || return 1
    unsafe_workdir_location "$path" && return 1
    [[ -d "$path" && ! -L "$path" ]] || return 1
    current_user_owns "$path" || return 1
    private_directory "$path" || return 1
    marker="$path/$WORKDIR_MARKER_NAME"
    valid_workdir_marker "$marker"
}

create_owned_workdir() {
    local requested="$1"
    local path parent marker

    [[ -n "$requested" ]] || return 1
    path_has_symlink "$requested" && return 1
    path="$(normalize_path "$requested")" || return 1
    unsafe_workdir_location "$path" && return 1
    if [[ -e "$path" || -L "$path" ]]; then
        validate_owned_workdir "$path"
        return $?
    fi

    parent="$(dirname -- "$path")"
    safe_existing_parent "$parent" || return 1
    mkdir -- "$path" || return 1
    chmod 700 -- "$path" || return 1
    marker="$path/$WORKDIR_MARKER_NAME"
    printf '%s' "$WORKDIR_MARKER_CONTENT" >"$marker" || return 1
    chmod 600 -- "$marker" || return 1
    validate_owned_workdir "$path"
}

create_safe_directory_path() {
    local target="$1"
    local cursor="$target"
    local parent
    local -a missing=()
    local index

    while [[ ! -e "$cursor" ]]; do
        [[ -L "$cursor" ]] && return 1
        missing+=("$cursor")
        parent="$(dirname -- "$cursor")"
        [[ "$parent" != "$cursor" ]] || return 1
        cursor="$parent"
    done
    [[ -d "$cursor" && ! -L "$cursor" ]] || return 1
    safe_existing_parent "$cursor" || return 1

    for ((index=${#missing[@]} - 1; index >= 0; index--)); do
        mkdir -- "${missing[index]}" || return 1
        chmod 700 -- "${missing[index]}" || return 1
    done
}

prepare_artifact_dir() {
    local requested="$1"
    local path

    [[ -n "$requested" ]] || return 1
    path_has_symlink "$requested" && return 1
    path="$(normalize_path "$requested")" || return 1
    [[ "$path" != "/" ]] || return 1
    [[ "$path" != "$(normalize_path "${HOME:-/}")" ]] || return 1
    [[ "$path" != "$PROJECT_ROOT" ]] || return 1

    if [[ -e "$path" || -L "$path" ]]; then
        [[ -d "$path" && ! -L "$path" ]] || return 1
    else
        create_safe_directory_path "$path" || return 1
    fi
    [[ -d "$path" && ! -L "$path" ]] || return 1
    current_user_owns "$path" || return 1
    private_directory "$path" || return 1
    safe_existing_parent "$path" || return 1
    ARTIFACT_DIR="$path"
}

cleanup() {
    local rc=$?
    if [[ "$VM_BOOTED" == "true" && "$ARTIFACTS_COLLECTED" != "true" && "$WORKDIR_VALIDATED" == "true" ]]; then
        collect_artifacts
    fi
    if [[ "$KEEP_VM" == "false" ]]; then
        if [[ "$WORKDIR_VALIDATED" == "true" && -f "${PID_FILE:-}" && ! -L "${PID_FILE:-}" ]]; then
            local pid
            pid="$(<"$PID_FILE")"
            if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
                kill "$pid" 2>/dev/null || true
                sleep 2
                kill -9 "$pid" 2>/dev/null || true
            fi
        fi
        if [[ "$CLEANUP_WORKDIR" == "true" && "$WORKDIR_VALIDATED" == "true" ]] && validate_owned_workdir "$WORKDIR"; then
            local artifact_path workdir_path
            artifact_path="$(normalize_path "$ARTIFACT_DIR")"
            workdir_path="$(normalize_path "$WORKDIR")"
            if [[ "$ARTIFACT_DIR_EXTERNAL" == "true" ]] && path_is_same_or_below "$artifact_path" "$workdir_path"; then
                echo "Keeping workdir because external artifacts are inside it: $WORKDIR" >&2
            else
                rm -rf -- "$workdir_path" || echo "Unable to clean up workdir: $WORKDIR" >&2
            fi
        else
            echo "Keeping VM artifacts in $WORKDIR" >&2
        fi
    else
        echo "Keeping VM artifacts in $WORKDIR" >&2
    fi
    exit "$rc"
}

prepare_dirs() {
    WORKDIR_VALIDATED=false
    if ! create_owned_workdir "$WORKDIR"; then
        echo "Refusing unsafe or unowned workdir: ${WORKDIR:-}" >&2
        return 1
    fi
    WORKDIR="$(normalize_path "$WORKDIR")"
    if [[ -z "$ARTIFACT_DIR" ]]; then
        ARTIFACT_DIR="$WORKDIR/artifacts"
    fi
    if ! prepare_artifact_dir "$ARTIFACT_DIR"; then
        echo "Refusing unsafe artifact directory: ${ARTIFACT_DIR:-}" >&2
        return 1
    fi
    WORKDIR_VALIDATED=true

    RUN_DIR="$(mktemp -d -- "$WORKDIR/run.XXXXXXXX")"
    chmod 700 -- "$RUN_DIR"
    BASE_IMAGE="$RUN_DIR/base-image.qcow2"
    OVERLAY_IMAGE="$RUN_DIR/overlay.qcow2"
    SEED_IMAGE="$RUN_DIR/seed.img"
    SSH_KEY="$RUN_DIR/id_ed25519"
    PID_FILE="$RUN_DIR/qemu.pid"
    SERIAL_LOG="$ARTIFACT_DIR/serial.log"
    USER_DATA="$RUN_DIR/user-data"
    META_DATA="$RUN_DIR/meta-data"
}

download_image() {
    if [[ ! -f "$BASE_IMAGE" ]]; then
        curl -fL --retry 3 --retry-delay 2 "$IMAGE_URL" -o "$BASE_IMAGE"
    fi
}

detect_base_image_format() {
    local detected_format
    detected_format="$(qemu-img info --output=json "$BASE_IMAGE" | jq -r '.format // empty')"
    if [[ -n "$detected_format" ]]; then
        BASE_IMAGE_FORMAT="$detected_format"
    fi
}

generate_ssh_key() {
    ssh-keygen -q -t ed25519 -N "" -f "$SSH_KEY" >/dev/null
}

render_cloud_init() {
    local ssh_pub
    ssh_pub="$(<"${SSH_KEY}.pub")"

    cat >"$USER_DATA" <<EOF
#cloud-config
preserve_hostname: false
hostname: ${VM_NAME}
users:
  - default
  - name: dragon
    gecos: Dragon CI
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: [sudo, adm, systemd-journal]
    shell: /bin/bash
    ssh_authorized_keys:
      - ${ssh_pub}
ssh_pwauth: false
disable_root: true
package_update: false
runcmd:
  - [ systemctl, enable, ssh ]
  - [ systemctl, start, ssh ]
EOF

    cat >"$META_DATA" <<EOF
instance-id: ${VM_NAME}
local-hostname: ${VM_NAME}
EOF

    cloud-localds "$SEED_IMAGE" "$USER_DATA" "$META_DATA"
}

start_vm() {
    qemu-img create -f qcow2 -F "$BASE_IMAGE_FORMAT" -b "$BASE_IMAGE" "$OVERLAY_IMAGE" >/dev/null

    qemu-system-x86_64 \
        -name "$VM_NAME" \
        -machine accel=tcg \
        -cpu max \
        -smp "$CPUS" \
        -m "$MEMORY_MB" \
        -display none \
        -serial "file:${SERIAL_LOG}" \
        -daemonize \
        -pidfile "$PID_FILE" \
        -device virtio-rng-pci \
        -drive "if=virtio,format=qcow2,file=${OVERLAY_IMAGE}" \
        -drive "if=virtio,format=raw,file=${SEED_IMAGE}" \
        -netdev "user,id=net0,hostfwd=tcp:127.0.0.1:${SSH_PORT}-:22" \
        -device virtio-net-pci,netdev=net0
}

ssh_base() {
    ssh \
        -i "$SSH_KEY" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o BatchMode=yes \
        -o ConnectTimeout=5 \
        -p "$SSH_PORT" \
        dragon@127.0.0.1 \
        "$@"
}

wait_for_ssh() {
    local start_ts
    start_ts=$(date +%s)
    until ssh_base true >/dev/null 2>&1; do
        local now_ts
        now_ts=$(date +%s)
        if (( now_ts - start_ts > BOOT_TIMEOUT_SEC )); then
            echo "Timed out waiting for guest SSH on port ${SSH_PORT} after ${BOOT_TIMEOUT_SEC}s" >&2
            return 1
        fi
        sleep 2
    done

    ssh_base "cloud-init status --wait >/dev/null 2>&1 || true"
    local state
    state="$(ssh_base "systemctl is-system-running || true" | tr -d '\r')"
    case "$state" in
        running|degraded)
            VM_BOOTED=true
            ;;
        *)
            echo "Guest systemd did not reach a healthy state: ${state}" >&2
            return 1
            ;;
    esac
}

copy_repo() {
    tar \
        --exclude=.git \
        --exclude=.cursor \
        --exclude=tools/pkgsolve/target \
        -C "$PROJECT_ROOT" \
        -cf - . \
        | ssh \
            -i "$SSH_KEY" \
            -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            -o BatchMode=yes \
            -p "$SSH_PORT" \
            dragon@127.0.0.1 \
            "rm -rf ~/dotfiles && mkdir -p ~/dotfiles && tar -xf - -C ~/dotfiles"
}

bootstrap_guest_pkgsolve() {
    ssh_base "bash -lc '
        set -euo pipefail
        if command -v pkgsolve >/dev/null 2>&1; then
            exit 0
        fi

        sudo env DEBIAN_FRONTEND=noninteractive apt-get update
        sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential ca-certificates curl pkg-config

        if [[ ! -x \"\$HOME/.cargo/bin/cargo\" ]]; then
            curl --proto \"=https\" --tlsv1.2 -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable
        fi

        export PATH=\"\$HOME/.cargo/bin:\$PATH\"

        cd ~/dotfiles
        pkgsolve_bin=\$(bash ./scripts/tools/build-pkgsolve.sh)
        sudo install -m 0755 \"\$pkgsolve_bin\" /usr/local/bin/pkgsolve
        pkgsolve --help >/dev/null
    '"
}

run_guest_smoke() {
    local validate_bundle="${VALIDATE_BUNDLE:-$BUNDLE_NAME}"
    local first_run_headless=false
    local install_flags=(--host "$HOST_NAME" --bundle "$BUNDLE_NAME" --no-secrets)
    if [[ "$HOST_NAME" == "headless" && "$BUNDLE_NAME" == "minimal" ]]; then
        install_flags+=(--headless)
    fi
    if [[ "$HOST_NAME" == "headless" ]]; then
        first_run_headless=true
    fi
    if [[ "$WITH_SYSTEM_CONFIG" != "true" ]]; then
        install_flags+=(--no-system-config)
    fi
    if [[ ${#INSTALL_EXTRA_FLAGS[@]} -gt 0 ]]; then
        install_flags+=("${INSTALL_EXTRA_FLAGS[@]}")
    fi

    local validate_flags=(--host "$HOST_NAME" --json)
    if [[ -n "$validate_bundle" ]]; then
        validate_flags+=(--bundle "$validate_bundle")
    fi

    local install_flags_quoted validate_flags_quoted
    printf -v install_flags_quoted "%q " "${install_flags[@]}"
    printf -v validate_flags_quoted "%q " "${validate_flags[@]}"

    ssh_base "bash -lc '
        set -euo pipefail
        export TERM=xterm-256color
        export CI=1
        cd ~/dotfiles
        ./install.sh ${install_flags_quoted}
        ./install.sh ${install_flags_quoted}
        test -f .artifacts/pkgsolve/debian/${HOST_NAME}-${BUNDLE_NAME}/resolve/plan.lock.json
        test -f .artifacts/pkgsolve/debian/${HOST_NAME}-${BUNDLE_NAME}/verify/plan.lock.json
        jq -e \".status == \\\"satisfiable\\\" or .status == \\\"partially_satisfiable\\\"\" \
            .artifacts/pkgsolve/debian/${HOST_NAME}-${BUNDLE_NAME}/verify/plan.lock.json >/dev/null
        git config --global user.name \"CI VM Smoke\"
        git config --global user.email \"ci-vm@example.com\"
        if ${RUN_FIRST_RUN_COMMAND}; then
            if ${first_run_headless}; then
                ./scripts/install/first-run.sh --headless
            else
                ./scripts/install/first-run.sh
            fi
        fi
        state=\$(systemctl is-system-running || true)
        case \"\$state\" in
            running|degraded) ;;
            *) echo \"Unexpected systemd state: \$state\" >&2; exit 1 ;;
        esac
        ./scripts/install/validate.sh ${validate_flags_quoted} | tee ~/validate.json
        jq -e \".failed == 0\" ~/validate.json >/dev/null
    '"
}

collect_artifacts() {
    ssh_base "bash -lc '
        mkdir -p ~/e2e-artifacts
        cp -f ~/validate.json ~/e2e-artifacts/validate.json 2>/dev/null || true
        cp -R ~/dotfiles/.artifacts/pkgsolve ~/e2e-artifacts/pkgsolve 2>/dev/null || true
        systemctl is-system-running > ~/e2e-artifacts/systemd-state.txt 2>/dev/null || true
        journalctl -b --no-pager > ~/e2e-artifacts/journalctl-boot.log 2>/dev/null || true
    '" >/dev/null 2>&1 || true

    scp \
        -i "$SSH_KEY" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o BatchMode=yes \
        -P "$SSH_PORT" \
        -r \
        dragon@127.0.0.1:~/e2e-artifacts/. \
        "$ARTIFACT_DIR/" >/dev/null 2>&1 || true

    ARTIFACTS_COLLECTED=true
}

main() {
    parse_args "$@"

    require_cmd curl
    require_cmd cloud-localds
    require_cmd jq
    require_cmd qemu-img
    require_cmd qemu-system-x86_64
    require_cmd ssh
    require_cmd ssh-keygen
    require_cmd scp
    require_cmd tar

    trap cleanup EXIT

    prepare_dirs
    download_image
    detect_base_image_format
    generate_ssh_key
    render_cloud_init
    start_vm
    wait_for_ssh
    copy_repo
    bootstrap_guest_pkgsolve
    run_guest_smoke
    collect_artifacts
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
