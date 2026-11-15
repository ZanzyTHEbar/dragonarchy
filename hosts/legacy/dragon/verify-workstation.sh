#!/usr/bin/env bash
set -euo pipefail

echo "== PCI (GPU) =="
lspci -k | grep -A3 -E "VGA|3D|Display" || true
echo

echo "== OpenGL (glxinfo -B) =="
if command -v glxinfo >/dev/null 2>&1; then
  glxinfo -B || true
else
  echo "glxinfo not found (package: mesa-utils)"
fi
echo

echo "== Vulkan (vulkaninfo --summary) =="
if command -v vulkaninfo >/dev/null 2>&1; then
  vulkaninfo --summary || true
else
  echo "vulkaninfo not found (package: vulkan-tools)"
fi
echo

echo "== Services (AIO/LED) =="
systemctl status --no-pager liquidctl-dragon.service 2>/dev/null || true
echo
systemctl status --no-pager dynamic_led.service 2>/dev/null || true
echo

echo "Done."

