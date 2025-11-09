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

export CONFIG_DIR
CONFIG_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Options (future extension)
SETUP_HARDWARE=true
FORCE=false

# Track whether kernel parameters changed
KERNEL_PARAMS_CHANGED=false

# ------------------------ Helper Functions ------------------------

# Merge space-separated token lists, preserving order and de-duplicating
merge_kernel_params() {
    # shellcheck disable=SC2206
    local current_tokens=($1)
    # shellcheck disable=SC2206
    local add_tokens=($2)
    local out=()
    local -A seen=()
    for t in "${current_tokens[@]}"; do
        if [[ -n "$t" && -z "${seen[$t]:-}" ]]; then
            out+=("$t"); seen["$t"]=1
        fi
    done
    for t in "${add_tokens[@]}"; do
        if [[ -n "$t" && -z "${seen[$t]:-}" ]]; then
            out+=("$t"); seen["$t"]=1
        fi
    done
    printf "%s" "${out[*]}"
}

# Append params to /etc/kernel/cmdline safely (idempotent)
append_kernel_params_to_cmdline() {
    local params="$1"
    local target="/etc/kernel/cmdline"
    
    if [[ ! -f "$target" ]]; then
        log_warning "Kernel cmdline file not found at $target; skipping to avoid breaking boot"
        return 0
    fi
    
    local existing merged
    existing="$(tr '\n' ' ' < "$target" | xargs || true)"
    merged="$(merge_kernel_params "$existing" "$params")"
    
    if [[ "$merged" == "$existing" ]]; then
        log_info "Kernel cmdline already contains desired parameters"
        return 0
    fi
    
    cp "$target" "${target}.backup.$(date +%Y%m%d_%H%M%S)"
    printf "%s\n" "$merged" > "${target}.tmp"
    mv "${target}.tmp" "$target"
    sync
    log_success "Updated $target (backup created)"
    KERNEL_PARAMS_CHANGED=true
}

# Append params to the first 'options' line in a systemd-boot entry (idempotent)
append_kernel_params_to_boot_entry() {
    local entry="$1"; local params="$2"
    [[ -f "$entry" ]] || return 0
    
    local current merged
    current="$(grep -m1 '^options ' "$entry" | sed 's/^options[[:space:]]\+//')"
    if [[ -z "$current" ]]; then
        log_warning "No 'options' line found in $entry; skipping"
        return 0
    fi
    merged="$(merge_kernel_params "$current" "$params")"
    if [[ "$merged" == "$current" ]]; then
        log_info "Boot entry already contains desired parameters: $entry"
        return 0
    fi
    
    cp "$entry" "${entry}.backup.$(date +%Y%m%d_%H%M%S)"
    awk -v repl="$merged" 'BEGIN{done=0} /^options / && !done {print "options " repl; done=1; next} {print}' "$entry" > "${entry}.tmp"
    mv "${entry}.tmp" "$entry"
    sync
    log_success "Updated boot entry: $entry (backup created)"
    KERNEL_PARAMS_CHANGED=true
}

# Rebuild initramfs if any changes were made
rebuild_initramfs_if_needed() {
    if [[ "$KERNEL_PARAMS_CHANGED" != "true" ]]; then
        return 0
    fi
    log_step "Rebuilding initramfs due to kernel parameter changes..."
    if command -v mkinitcpio >/dev/null 2>&1; then
        if mkinitcpio -P; then
            log_success "mkinitcpio: presets rebuilt"
        else
            log_warning "mkinitcpio failed; please validate initramfs configuration"
        fi
        elif command -v dracut >/dev/null 2>&1; then
        if dracut --regenerate-all --force; then
            log_success "dracut: images regenerated"
        else
            log_warning "dracut failed; please validate dracut configuration"
        fi
    else
        log_warning "No initramfs tool (mkinitcpio/dracut) found; please rebuild initramfs manually"
    fi
}

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
    
    if [[ -d "/boot/loader/entries" ]]; then
        local entry
        entry="$(find /boot/loader/entries -name '*.conf' | head -1 || true)"
        [[ -n "$entry" ]] && append_kernel_params_to_boot_entry "$entry" "$kernel_params"
    else
        append_kernel_params_to_cmdline "$kernel_params"
    fi
    
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
    
    if [[ -d "/boot/loader/entries" ]]; then
        local entry
        entry="$(find /boot/loader/entries -name '*.conf' | head -1 || true)"
        [[ -n "$entry" ]] && append_kernel_params_to_boot_entry "$entry" "$kernel_params"
    else
        append_kernel_params_to_cmdline "$kernel_params"
    fi
    
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
    
    if [[ -d "/boot/loader/entries" ]]; then
        local entry
        entry="$(find /boot/loader/entries -name '*.conf' | head -1 || true)"
        if [[ -n "$entry" ]]; then
            append_kernel_params_to_boot_entry "$entry" "$kernel_params"
        else
            log_warning "No systemd-boot entries found; skipping"
        fi
    else
        log_warning "systemd-boot not detected; attempting to update /etc/kernel/cmdline instead"
        append_kernel_params_to_cmdline "$kernel_params"
    fi
    
    mkdir -p /etc/modules-load.d
    echo "amdgpu" >> /etc/modules-load.d/amd.conf
    echo "crc32c" >> /etc/modules-load.d/amd.conf
    log_success "AMD configuration applied"
}

setup_intel_configuration() {
    log_info "Setting up Intel CPU + Intel GPU kernel parameters..."
    local kernel_params="intel_pstate=active i915.fastboot=1 i915.enable_fbc=1 i915.enable_psr=2 i915.modeset=1 acpi_osi=Linux mem_sleep_default=deep"
    
    if [[ -d "/boot/loader/entries" ]]; then
        local entry
        entry="$(find /boot/loader/entries -name '*.conf' | head -1 || true)"
        if [[ -n "$entry" ]]; then
            append_kernel_params_to_boot_entry "$entry" "$kernel_params"
        else
            log_warning "No systemd-boot entries found; skipping"
        fi
    else
        log_warning "systemd-boot not detected; attempting to update /etc/kernel/cmdline instead"
        append_kernel_params_to_cmdline "$kernel_params"
    fi
    
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
    rebuild_initramfs_if_needed
    
    echo
    log_success "🎉 System configuration completed!"
    if [[ "$KERNEL_PARAMS_CHANGED" == "true" ]]; then
        log_warning "A reboot is recommended to apply kernel parameter changes"
    fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    parse_args "$@"
    main
fi
