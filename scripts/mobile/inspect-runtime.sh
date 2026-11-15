#!/usr/bin/env bash
# inspect-runtime.sh — Detect which Linux runtime we're in
set -euo pipefail

echo "=== Runtime Inspection ==="
echo "Kernel: $(uname -r)"
echo "Arch: $(uname -m)"
echo "User: $(whoami)"
echo "Home: $HOME"
echo "Shell: $SHELL"

if [[ -f /etc/os-release ]]; then
    echo "OS: $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')"
fi

echo ""
echo "=== Package Manager ==="
if command -v pacman &>/dev/null; then
    echo "pacman: available ($(pacman --version | head -1))"
elif command -v pkg &>/dev/null; then
    echo "pkg (Termux): available"
elif command -v apt &>/dev/null; then
    echo "apt: available"
else
    echo "No known package manager found"
fi

echo ""
echo "=== Display ==="
echo "DISPLAY: ${DISPLAY:-<unset>}"
echo "WAYLAND_DISPLAY: ${WAYLAND_DISPLAY:-<unset>}"
echo "XDG_SESSION_TYPE: ${XDG_SESSION_TYPE:-<unset>}"

echo ""
echo "=== Proot ==="
if command -v proot &>/dev/null; then
    echo "proot: available ($(proot --version 2>&1 | head -1))"
else
    echo "proot: not found"
fi
if [[ -d /proc/self/root/.termux ]] 2>/dev/null; then
    echo "Termux prefix detected"
fi

echo ""
echo "=== Chezmoi ==="
if command -v chezmoi &>/dev/null; then
    echo "chezmoi: $(chezmoi --version)"
else
    echo "chezmoi: not found"
fi