#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

IMAGE_URL_DEFAULT="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2"
WORKDIR_DEFAULT="${TMPDIR:-/tmp}/dotfiles-debian-vm-e2e"
SSH_PORT_DEFAULT="2222"
MEMORY_MB_DEFAULT="4096"
CPUS_DEFAULT="2"
VM_NAME_DEFAULT="dotfiles-debian-headless-e2e"
BOOT_TIMEOUT_SEC_DEFAULT="900"

IMAGE_URL="$IMAGE_URL_DEFAULT"
WORKDIR="$WORKDIR_DEFAULT"
ARTIFACT_DIR=""
SSH_PORT="$SSH_PORT_DEFAULT"
MEMORY_MB="$MEMORY_MB_DEFAULT"
CPUS="$CPUS_DEFAULT"
VM_NAME="$VM_NAME_DEFAULT"
BOOT_TIMEOUT_SEC="$BOOT_TIMEOUT_SEC_DEFAULT"
KEEP_VM=false
WITH_SYSTEM_CONFIG=false
VM_BOOTED=false
ARTIFACTS_COLLECTED=false

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
  --with-system-config     Include install.sh system configuration step
  --keep-vm                Do not clean up the VM process and working files on exit
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
            --with-system-config)
                WITH_SYSTEM_CONFIG=true
                shift
                ;;
            --keep-vm)
                KEEP_VM=true
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

cleanup() {
    local rc=$?
    if [[ "$VM_BOOTED" == "true" && "$ARTIFACTS_COLLECTED" != "true" ]]; then
        collect_artifacts
    fi
    if [[ "$KEEP_VM" == "false" ]]; then
        if [[ -f "${PID_FILE:-}" ]]; then
            local pid
            pid="$(<"$PID_FILE")"
            if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
                kill "$pid" 2>/dev/null || true
                sleep 2
                kill -9 "$pid" 2>/dev/null || true
            fi
        fi
        [[ -n "${WORKDIR:-}" && -d "$WORKDIR" ]] && rm -rf "$WORKDIR"
    else
        echo "Keeping VM artifacts in $WORKDIR" >&2
    fi
    exit "$rc"
}

prepare_dirs() {
    mkdir -p "$WORKDIR"
    if [[ -z "$ARTIFACT_DIR" ]]; then
        ARTIFACT_DIR="$WORKDIR/artifacts"
    fi
    mkdir -p "$ARTIFACT_DIR"

    BASE_IMAGE="$WORKDIR/base-image.qcow2"
    OVERLAY_IMAGE="$WORKDIR/overlay.qcow2"
    SEED_IMAGE="$WORKDIR/seed.img"
    SSH_KEY="$WORKDIR/id_ed25519"
    PID_FILE="$WORKDIR/qemu.pid"
    SERIAL_LOG="$ARTIFACT_DIR/serial.log"
    USER_DATA="$WORKDIR/user-data"
    META_DATA="$WORKDIR/meta-data"
}

download_image() {
    if [[ ! -f "$BASE_IMAGE" ]]; then
        curl -fL --retry 3 --retry-delay 2 "$IMAGE_URL" -o "$BASE_IMAGE"
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
    qemu-img create -f qcow2 -F qcow2 -b "$BASE_IMAGE" "$OVERLAY_IMAGE" >/dev/null

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

run_guest_smoke() {
    local install_flags="--host headless --headless --bundle minimal --no-secrets"
    if [[ "$WITH_SYSTEM_CONFIG" != "true" ]]; then
        install_flags+=" --no-system-config"
    fi

    ssh_base "bash -lc '
        set -euo pipefail
        export TERM=xterm-256color
        export CI=1
        cd ~/dotfiles
        ./install.sh ${install_flags}
        ./install.sh ${install_flags}
        git config --global user.name \"CI VM Smoke\"
        git config --global user.email \"ci-vm@example.com\"
        ./scripts/install/first-run.sh --headless
        state=\$(systemctl is-system-running || true)
        case \"\$state\" in
            running|degraded) ;;
            *) echo \"Unexpected systemd state: \$state\" >&2; exit 1 ;;
        esac
        ./scripts/install/validate.sh --host headless --json | tee ~/validate.json
        jq -e \".failed == 0\" ~/validate.json >/dev/null
    '"
}

collect_artifacts() {
    ssh_base "bash -lc '
        mkdir -p ~/e2e-artifacts
        cp -f ~/validate.json ~/e2e-artifacts/validate.json 2>/dev/null || true
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
    require_cmd qemu-img
    require_cmd qemu-system-x86_64
    require_cmd ssh
    require_cmd ssh-keygen
    require_cmd scp
    require_cmd tar

    trap cleanup EXIT

    prepare_dirs
    download_image
    generate_ssh_key
    render_cloud_init
    start_vm
    wait_for_ssh
    copy_repo
    run_guest_smoke
    collect_artifacts
}

main "$@"
