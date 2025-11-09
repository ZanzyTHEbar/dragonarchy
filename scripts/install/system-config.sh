#!/usr/bin/env bash

# System Configuration Script (SAFE)
# - Hardware-specific kernel parameter updates (idempotent)
# - Never overwrites /etc/kernel/cmdline (appends missing tokens only)
# - Rebuilds initramfs only when necessary
# - Avoids actions that terminate user sessions

set -euo pipefail

# Resolve directories and logging
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091  # Runtime-resolved path to logging library
source "${SCRIPT_DIR}/../lib/logging.sh"
# shellcheck disable=SC1091  # Runtime-resolved path to bootloader library
source "${SCRIPT_DIR}/../lib/bootloader.sh"

export CONFIG_DIR
CONFIG_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Options (future extension)
SETUP_HARDWARE=true
FORCE=false

# ------------------------ Hardware Detection ------------------------

detect_hardware() {
    local cpu_vendor="" gpu_vendor=""
    if grep -q "vendor_id.*AuthenticAMD" /proc/cpuinfo; then
        cpu_vendor="amd"
    elif grep -q "vendor_id.*GenuineIntel" /proc/cpuinfo; then
        cpu_vendor="intel"
    fi

    if lspci | grep -qi "amd\|radeon"; then
        gpu_vendor="amd"
    elif lspci | grep -qi "intel.*graphics"; then
        gpu_vendor="intel"
    elif lspci | grep -qi "nvidia"; then
        gpu_vendor="nvidia"
    fi

    printf "%s-%s" "$cpu_vendor" "$gpu_vendor"
}

# ------------------------ Hardware Config ------------------------

setup_amd_nvidia_configuration() {
    log_info "Setting up AMD CPU + NVIDIA GPU kernel parameters..."
    local kernel_params="amd_pstate=active nvidia-drm.modeset=1 nvidia.NVreg_PreserveVideoMemoryAllocations=1"
    boot_append_kernel_params "$kernel_params"

    mkdir -p /etc/modules-load.d
    {
        echo "nvidia"
        echo "nvidia_modeset"
        echo "nvidia_uvm"
        echo "nvidia_drm"
    } >> /etc/modules-load.d/nvidia.conf
    log_success "AMD+NVIDIA configuration applied"
}

setup_intel_nvidia_configuration() {
    log_info "Setting up Intel CPU + NVIDIA GPU kernel parameters..."
    local kernel_params="intel_pstate=active i915.modeset=1 nvidia-drm.modeset=1 nvidia.NVreg_PreserveVideoMemoryAllocations=1"
    boot_append_kernel_params "$kernel_params"

    mkdir -p /etc/modules-load.d
    echo "i915" >> /etc/modules-load.d/intel.conf
    {
        echo "nvidia"; echo "nvidia_modeset"; echo "nvidia_uvm"; echo "nvidia_drm"
    } >> /etc/modules-load.d/nvidia.conf
    log_success "Intel+NVIDIA configuration applied"
}

setup_amd_configuration() {
    log_info "Setting up AMD CPU + AMD GPU kernel parameters..."
    local kernel_params="amd_pstate=active amdgpu.si_support=1 amdgpu.cik_support=1 amdgpu.dc=1 amdgpu.ppfeaturemask=0xffffffff radeon.si_support=0 radeon.cik_support=0 processor.max_cstate=1"
    boot_append_kernel_params "$kernel_params"

    mkdir -p /etc/modules-load.d
    echo "amdgpu" >> /etc/modules-load.d/amd.conf
    echo "crc32c" >> /etc/modules-load.d/amd.conf
    log_success "AMD configuration applied"
}

setup_intel_configuration() {
    log_info "Setting up Intel CPU + Intel GPU kernel parameters..."
    local kernel_params="intel_pstate=active i915.fastboot=1 i915.enable_fbc=1 i915.enable_psr=2 i915.modeset=1 acpi_osi=Linux mem_sleep_default=deep"
    boot_append_kernel_params "$kernel_params"

    mkdir -p /etc/modules-load.d
    echo "i915" >> /etc/modules-load.d/intel.conf
    echo "crc32c" >> /etc/modules-load.d/intel.conf
    log_success "Intel configuration applied"
}

setup_hardware_config() {
    if [[ "$SETUP_HARDWARE" != "true" ]]; then
        return 0
    fi
    log_step "Detecting hardware and applying kernel parameters..."
    local hw
    hw="$(detect_hardware)"
    log_info "Detected hardware: $hw"
    case "$hw" in
        amd-amd)       setup_amd_configuration ;;
        amd-nvidia)    setup_amd_nvidia_configuration ;;
        intel-intel)   setup_intel_configuration ;;
        intel-nvidia)  setup_intel_nvidia_configuration ;;
        *)             log_warning "Unknown hardware configuration: $hw" ;;
    esac
}

# ------------------------ CLI and Main ------------------------

usage() {
cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --no-hardware       Skip hardware kernel parameter configuration
  --force             Reserved for future features
  -h, --help          Show this help
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --no-hardware) SETUP_HARDWARE=false; shift ;;
            --force) FORCE=true; shift ;;
            -h|--help) usage; exit 0 ;;
            *) log_error "Unknown option: $1"; usage; exit 1 ;;
        esac
    done
}

check_privileges() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script requires root privileges"
        log_info "Please run with sudo: sudo $0"
        exit 1
    fi
}

main() {
    echo
    log_info "🔧 Starting system configuration (SAFE mode)"
    echo
    check_privileges

    setup_hardware_config

    # Rebuild initramfs once if changes occurred
    boot_rebuild_if_changed

    echo
    log_success "🎉 System configuration completed!"
    if [[ "${BOOT_PARAMS_CHANGED:-false}" == "true" ]]; then
        log_warning "A reboot is recommended to apply kernel parameter changes"
    fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    parse_args "$@"
    main
fi
