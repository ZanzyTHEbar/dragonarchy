#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: create-cloud-base-template.sh [OPTIONS]

Create a Proxmox gold cloud-base template from an official Debian or Arch cloud image.

Options:
  --distro NAME                Template source: debian-14 | arch
  --vm-id ID                   Cluster-unique VMID for the template
  --ssh-public-key-file PATH   Public key file injected via cloud-init
  --name NAME                  Template name override
  --image-url URL              Cloud image URL override
  --bios NAME                  Firmware mode override (default depends on distro)
  --machine NAME               Machine type override (default depends on distro)
  --storage-pool NAME          Proxmox storage pool (default: local-lvm)
  --bridge NAME                Proxmox bridge (default: vmbr0)
  --ci-user NAME               Cloud-init login user (default: dragon)
  --memory-mb MB               Template RAM (default: 4096)
  --cores N                    Template vCPU count (default: 2)
  --disk-size SIZE             Final disk size, e.g. 40G (default: 40G)
  -h, --help                   Show this help
EOF
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Missing required command: $1" >&2
        exit 1
    }
}

distro=""
vm_id=""
vm_name=""
image_url=""
ssh_public_key_file=""
bios=""
machine=""
storage_pool="local-lvm"
bridge="vmbr0"
ci_user="dragon"
memory_mb="4096"
cores="2"
disk_size="40G"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --distro)
            distro="$2"
            shift 2
            ;;
        --vm-id)
            vm_id="$2"
            shift 2
            ;;
        --ssh-public-key-file)
            ssh_public_key_file="$2"
            shift 2
            ;;
        --name)
            vm_name="$2"
            shift 2
            ;;
        --image-url)
            image_url="$2"
            shift 2
            ;;
        --bios)
            bios="$2"
            shift 2
            ;;
        --machine)
            machine="$2"
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

[[ -n "$distro" ]] || { echo "--distro is required" >&2; exit 1; }
[[ -n "$vm_id" ]] || { echo "--vm-id is required" >&2; exit 1; }
[[ -n "$ssh_public_key_file" ]] || { echo "--ssh-public-key-file is required" >&2; exit 1; }
[[ -f "$ssh_public_key_file" ]] || { echo "SSH public key file not found: $ssh_public_key_file" >&2; exit 1; }

case "$distro" in
    debian-14)
        default_name="debian-14-cloud-base"
        default_image_url="https://cloud.debian.org/images/cloud/forky/daily/latest/debian-14-genericcloud-amd64-daily.qcow2"
        default_bios="ovmf"
        default_machine="q35"
        ;;
    arch)
        default_name="arch-cloud-base"
        default_image_url="https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-cloudimg.qcow2"
        default_bios="seabios"
        default_machine="pc"
        ;;
    *)
        echo "Unsupported distro: $distro" >&2
        exit 1
        ;;
esac

vm_name="${vm_name:-$default_name}"
image_url="${image_url:-$default_image_url}"
bios="${bios:-$default_bios}"
machine="${machine:-$default_machine}"

require_cmd curl
require_cmd mktemp
require_cmd qm

if qm status "$vm_id" >/dev/null 2>&1; then
    echo "VMID already exists: $vm_id" >&2
    exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

image_path="${tmpdir}/cloud-image.qcow2"

echo "Downloading ${distro} cloud image..."
curl -fsSL "$image_url" -o "$image_path"

echo "Creating VM shell ${vm_id} (${vm_name})..."
qm create "$vm_id" \
    --name "$vm_name" \
    --ostype l26 \
    --agent enabled=1,fstrim_cloned_disks=1 \
    --bios "$bios" \
    --machine "$machine" \
    --cpu host \
    --cores "$cores" \
    --memory "$memory_mb" \
    --scsihw virtio-scsi-single \
    --net0 "virtio,bridge=${bridge}" \
    --serial0 socket \
    --vga serial0

echo "Importing cloud disk into ${storage_pool}..."
qm importdisk "$vm_id" "$image_path" "$storage_pool"

echo "Attaching disk and cloud-init drive..."
qm set "$vm_id" --scsi0 "${storage_pool}:vm-${vm_id}-disk-0,discard=on"
if [[ "$bios" == "ovmf" ]]; then
    qm set "$vm_id" --efidisk0 "${storage_pool}:0,efitype=4m,pre-enrolled-keys=1"
fi
qm set "$vm_id" --boot order=scsi0
qm set "$vm_id" --ide2 "${storage_pool}:cloudinit"
qm set "$vm_id" --ciuser "$ci_user"
qm set "$vm_id" --sshkeys "$ssh_public_key_file"
qm set "$vm_id" --ipconfig0 ip=dhcp
qm set "$vm_id" --tags "dotfiles;base-template;${distro}"

echo "Resizing boot disk to ${disk_size}..."
qm resize "$vm_id" scsi0 "$disk_size"

echo "Converting ${vm_name} to a template..."
qm template "$vm_id"

echo "Created template ${vm_name} (VMID ${vm_id})."
