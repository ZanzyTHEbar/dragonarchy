#!/usr/bin/env bash
# Quick setup script for clipboard system symlinks
# Run this after stowing hyprland package

set -euo pipefail

echo "Creating clipboard system symlinks..."

cd ~/.local/bin

# Create relative symlinks to dotfiles
ln -sf ../../dotfiles/packages/hyprland/.local/bin/clipse-wrapper clipse-wrapper
ln -sf ../../dotfiles/packages/hyprland/.local/bin/clipboard-menu clipboard-menu  
ln -sf ../../dotfiles/packages/hyprland/.local/bin/generate-clipse-themes generate-clipse-themes
ln -sf ../../dotfiles/packages/hyprland/.local/bin/test-clipse-theme test-clipse-theme

echo "✅ Symlinks created:"
ls -la ~/.local/bin/ | grep -E "(clipse|clipboard)"

echo ""
echo "Testing clipse daemon..."
if pgrep clipse >/dev/null; then
  echo "✅ Clipse daemon is running"
else
  echo "⚠️  Starting clipse daemon..."
  clipse -listen &
  sleep 1
  if pgrep clipse >/dev/null; then
    echo "✅ Clipse daemon started"
  else
    echo "❌ Clipse daemon failed to start"
  fi
fi

echo ""
echo "Generating themes..."
generate-clipse-themes

echo ""
echo "✅ Setup complete! Try:"
echo "  Super + V         - Clipse (TUI)"
echo "  Super + Shift + V - Walker (Advanced)"

