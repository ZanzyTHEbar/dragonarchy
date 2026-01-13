#!/usr/bin/env bash
#
# Verify NVIDIA setup on goldendragon (driver, kernel params, PRIME/offload, basic GL/VK)
#
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${PROJECT_ROOT}/scripts/lib/logging.sh"

has_cmd() { command -v "$1" >/dev/null 2>&1; }

main() {
  log_step "NVIDIA verification (goldendragon)"
  echo

  log_info "PCI devices (GPU):"
  if has_cmd lspci; then
    lspci -nn | grep -Ei 'VGA compatible controller|3D controller|Display controller' || true
    echo
    log_info "NVIDIA driver binding:"
    lspci -k | awk '
      BEGIN{show=0}
      /VGA compatible controller|3D controller|Display controller/{show=1}
      show==1{print}
      show==1 && NF==0{show=0}
    ' | grep -i -A4 nvidia || true
  else
    log_warning "lspci not found"
  fi
  echo

  log_info "Kernel cmdline NVIDIA parameters:"
  if [[ -r /proc/cmdline ]]; then
    echo "/proc/cmdline: $(cat /proc/cmdline)"
    for p in nvidia-drm.modeset=1 nvidia-drm.fbdev=1 nvidia.NVreg_PreserveVideoMemoryAllocations=1; do
      if grep -qw "$p" /proc/cmdline; then
        log_success "present: $p"
      else
        log_warning "missing: $p (apply via hosts/goldendragon/setup.sh then reboot)"
      fi
    done
  fi
  echo

  log_info "Loaded kernel modules:"
  if has_cmd lsmod; then
    lsmod | grep -E '^nvidia|^nvidia_drm|^nvidia_modeset|^nvidia_uvm' || log_warning "No NVIDIA modules currently loaded"
  fi
  echo

  log_info "nvidia-smi:"
  if has_cmd nvidia-smi; then
    nvidia-smi || true
  else
    log_warning "nvidia-smi not found (install nvidia-utils)"
  fi
  echo

  log_info "NVIDIA services (best-effort):"
  if has_cmd systemctl; then
    systemctl --no-pager --full status nvidia-persistenced.service nvidia-powerd.service nvidia-suspend.service nvidia-resume.service nvidia-hibernate.service 2>/dev/null || true
  fi
  echo

  log_step "PRIME / offload checks (recommended on hybrid laptops)"
  if has_cmd prime-run; then
    log_success "prime-run found"
  else
    log_warning "prime-run not found (install nvidia-prime)"
  fi

  if has_cmd glxinfo; then
    echo
    log_info "glxinfo (default):"
    glxinfo -B 2>/dev/null | sed -n '1,80p' || true
    if has_cmd prime-run; then
      echo
      log_info "glxinfo (prime-run / NVIDIA offload):"
      prime-run glxinfo -B 2>/dev/null | sed -n '1,80p' || true
    fi
  else
    log_warning "glxinfo not found (install mesa-utils to check OpenGL renderer)"
  fi

  if has_cmd vulkaninfo; then
    echo
    log_info "vulkaninfo summary (default):"
    vulkaninfo --summary 2>/dev/null | sed -n '1,120p' || true
    if has_cmd prime-run; then
      echo
      log_info "vulkaninfo summary (prime-run):"
      prime-run vulkaninfo --summary 2>/dev/null | sed -n '1,120p' || true
    fi
  else
    log_warning "vulkaninfo not found (install vulkan-tools to check Vulkan ICDs)"
  fi

  echo
  log_step "Expected results"
  cat <<'EOF'
- nvidia-smi should show the GPU and driver version
- /sys/module/nvidia_drm/parameters/modeset should effectively be enabled after reboot
- prime-run glxinfo -B should show an NVIDIA renderer string
- prime-run vulkaninfo --summary should enumerate NVIDIA as a physical device
EOF
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi

