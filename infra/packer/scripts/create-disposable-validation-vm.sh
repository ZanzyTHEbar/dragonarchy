#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: create-disposable-validation-vm.sh [OPTIONS]

Clone a validation template into a disposable VM for branch-shift and chezmoi cutover testing.

Options:
  --template NAME              Source validation template name
  --vm-id ID                   Cluster-unique VMID for the disposable VM
  --name NAME                  Disposable VM name
  --ssh-public-key-file PATH   Public key file injected via cloud-init
  --ipconfig0 VALUE            Cloud-init network config, e.g. ip=192.168.0.250/24,gw=192.168.0.1
  --storage-pool NAME          Target storage for full clones
  --bridge NAME                Proxmox bridge (default: vmbr0)
  --ci-user NAME               Cloud-init login user (default: dragon)
  --memory-mb MB               VM RAM (default: 8192)
  --cores N                    VM vCPU count (default: 4)
  --disk-size SIZE             Optional resize for scsi0 after clone
  --linked-clone               Use a linked clone instead of a full clone
  -h, --help                   Show this help
EOF
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Missing required command: $1" >&2
        exit 1
    }
}

template=""
vm_id=""
vm_name=""
ssh_public_key_file=""
ipconfig0="ip=dhcp"
storage_pool=""
bridge="vmbr0"
ci_user="dragon"
memory_mb="8192"
cores="4"
disk_size=""
full_clone=true

while [[ $# -gt 0 ]]; do
    case "$1" in
        --template)
            template="$2"
            shift 2
            ;;
        --vm-id)
            vm_id="$2"
            shift 2
            ;;
        --name)
            vm_name="$2"
            shift 2
            ;;
        --ssh-public-key-file)
            ssh_public_key_file="$2"
            shift 2
            ;;
        --ipconfig0)
            ipconfig0="$2"
            shift 2
            ;;
        --storage-pool)
            storage_pool="$2"
            shift 2
            ;;
        --bridge)
            bridge="$2"
            shift 2
            ;;
        --ci-user)
            ci_user="$2"
            shift 2
            ;;
        --memory-mb)
            memory_mb="$2"
            shift 2
            ;;
        --cores)
            cores="$2"
            shift 2
            ;;
        --disk-size)
            disk_size="$2"
            shift 2
            ;;
        --linked-clone)
            full_clone=false
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

[[ -n "$template" ]] || { echo "--template is required" >&2; exit 1; }
[[ -n "$vm_id" ]] || { echo "--vm-id is required" >&2; exit 1; }
[[ -n "$vm_name" ]] || { echo "--name is required" >&2; exit 1; }
[[ -n "$ssh_public_key_file" ]] || { echo "--ssh-public-key-file is required" >&2; exit 1; }
[[ -f "$ssh_public_key_file" ]] || { echo "SSH public key file not found: $ssh_public_key_file" >&2; exit 1; }

require_cmd qm

if qm status "$vm_id" >/dev/null 2>&1; then
    echo "VMID already exists: $vm_id" >&2
    exit 1
fi

if [[ "$template" =~ ^[0-9]+$ ]]; then
    source_vmid="$template"
else
    source_vmid="$(
        qm list | awk -v target="$template" '$2 == target { print $1; exit }'
    )" || {
        echo "Unable to resolve template VMID for: $template" >&2
        exit 1
    }
    [[ -n "$source_vmid" ]] || {
        echo "Unable to resolve template VMID for: $template" >&2
        exit 1
    }
fi

clone_args=("$source_vmid" "$vm_id" --name "$vm_name")
if [[ "$full_clone" == true ]]; then
    clone_args+=(--full true)
    if [[ -n "$storage_pool" ]]; then
        clone_args+=(--storage "$storage_pool")
    fi
fi

echo "Cloning ${template} (${source_vmid}) into ${vm_name} (${vm_id})..."
qm clone "${clone_args[@]}"

echo "Applying disposable VM settings..."
qm set "$vm_id" \
    --agent enabled=1,fstrim_cloned_disks=1 \
    --cpu host \
    --cores "$cores" \
    --memory "$memory_mb" \
    --net0 "virtio,bridge=${bridge}" \
    --ciuser "$ci_user" \
    --sshkeys "$ssh_public_key_file" \
    --ipconfig0 "$ipconfig0" \
    --tags "dotfiles;validation-vm"

if [[ -n "$disk_size" ]]; then
    qm resize "$vm_id" scsi0 "$disk_size"
fi

echo "Starting ${vm_name}..."
qm start "$vm_id"

echo "Disposable validation VM started: ${vm_name} (${vm_id})."
