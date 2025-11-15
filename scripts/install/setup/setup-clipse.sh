#!/usr/bin/env bash
# Clipse Enhanced Setup Script
# Sets up theme-aware clipboard manager with advanced features

set -euo pipefail

# Get the correct dotfiles root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   Enhanced Clipse Clipboard Manager Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if clipse is installed
if ! command -v clipse &>/dev/null; then
  echo "❌ clipse is not installed"
  echo "📦 Installing clipse..."
  
  if command -v yay &>/dev/null; then
    yay -S --noconfirm clipse-bin
  elif command -v paru &>/dev/null; then
    paru -S --noconfirm clipse-bin
  else
    echo "Error: No AUR helper found (yay/paru required)" >&2
    exit 1
  fi
fi

echo "✅ clipse installed: $(clipse --version 2>/dev/null || echo 'version unknown')"

# Create configuration directories
echo ""
echo "📁 Creating configuration directories..."
mkdir -p ~/.config/clipse
mkdir -p ~/.local/share/clipse
mkdir -p ~/.local/bin

# Copy configuration file if it exists
echo "📝 Installing clipse configuration..."
if [[ -f "$DOTFILES_ROOT/packages/hyprland/.config/clipse/clipse.toml" ]]; then
  cp "$DOTFILES_ROOT/packages/hyprland/.config/clipse/clipse.toml" ~/.config/clipse/
  echo "✅ Configuration installed"
else
  echo "⚠️  Configuration file not found, creating default..."
  cat > ~/.config/clipse/clipse.toml <<'EOF'
# Clipse Enhanced Configuration
historyFile = "clipboard_history.json"
maxHistory = 100
enablePersistence = true
allowDuplicates = false
themeFile = "~/.config/clipse/theme.toml"
EOF
fi

# Install scripts
echo "🔧 Installing clipse scripts..."
rm -f ~/.local/bin/clipse-wrapper ~/.local/bin/generate-clipse-themes ~/.local/bin/test-clipse-theme
ln -sf "$DOTFILES_ROOT/scripts/theme-manager/clipse-wrapper" ~/.local/bin/clipse-wrapper
ln -sf "$DOTFILES_ROOT/scripts/theme-manager/generate-clipse-themes" ~/.local/bin/generate-clipse-themes
ln -sf "$DOTFILES_ROOT/scripts/theme-manager/test-clipse-theme" ~/.local/bin/test-clipse-theme

chmod +x "$DOTFILES_ROOT/scripts/theme-manager/clipse-wrapper"
chmod +x "$DOTFILES_ROOT/scripts/theme-manager/generate-clipse-themes"
chmod +x "$DOTFILES_ROOT/scripts/theme-manager/test-clipse-theme"

# Generate themes for all available themes
echo "🎨 Generating clipse themes..."
~/.local/bin/generate-clipse-themes

# Check if clipse daemon is running
echo ""
echo "🔍 Checking clipse daemon..."
if pgrep -x clipse >/dev/null; then
  echo "✅ clipse daemon is running"
else
  echo "⚠️  clipse daemon is not running"
  echo "🚀 Starting clipse daemon..."
  clipse -listen &
  sleep 1
  if pgrep -x clipse >/dev/null; then
    echo "✅ clipse daemon started successfully"
  else
    echo "❌ Failed to start clipse daemon"
  fi
fi

# Check if wl-clip-persist is running
echo ""
echo "🔍 Checking wl-clip-persist..."
if pgrep -f "wl-clip-persist" >/dev/null; then
  echo "✅ wl-clip-persist is running"
else
  echo "⚠️  wl-clip-persist is not running"
  echo "   This is normal if Hyprland hasn't started yet"
  echo "   It will auto-start with Hyprland"
fi

# Test theme
echo ""
echo "🎨 Testing current theme..."
if [[ -f ~/.config/clipse/theme.toml ]]; then
  echo "✅ Theme configuration found"
  ~/.local/bin/test-clipse-theme
else
  echo "⚠️  No theme configuration found"
  echo "   Run: generate-clipse-themes"
fi

# Display keybindings
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   Keybindings"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Primary Access:"
echo "  Super + V            - Clipboard history (theme-aware)"
echo "  Super + Shift + V    - Fuzzy search mode"
echo "  Super + Ctrl + V     - Images only"
echo "  Super + Alt + V      - Pinned items"
echo ""
echo "Within Clipse:"
echo "  Enter  - Copy item    p - Pin item"
echo "  e      - Edit item    d - Delete item"
echo "  /      - Search       Tab - Preview"
echo "  q      - Quit         D - Clear all"
echo ""
echo "Utilities:"
echo "  Super + Alt + C           - Clear history"
echo "  Super + Ctrl + Alt + C    - Restart daemon"
echo ""

# Configuration summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   Configuration Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Config:   ~/.config/clipse/clipse.toml"
echo "Theme:    ~/.config/clipse/theme.toml"
echo "History:  ~/.local/share/clipse/clipboard_history.json"
echo "Scripts:  ~/.local/bin/clipse-*"
echo ""
echo "Docs:     ~/.config/clipse/README.md"
echo ""

# Final checks
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   Final Checks"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

ALL_GOOD=true

# Check wl-clipboard
if command -v wl-copy &>/dev/null && command -v wl-paste &>/dev/null; then
  echo "✅ wl-clipboard tools available"
else
  echo "❌ wl-clipboard missing (install: pacman -S wl-clipboard)"
  ALL_GOOD=false
fi

# Check fzf
if command -v fzf &>/dev/null; then
  echo "✅ fzf available (fuzzy search enabled)"
else
  echo "⚠️  fzf not found (fuzzy search disabled)"
  echo "   Install: pacman -S fzf"
fi

# Check kitty (for image preview)
if command -v kitty &>/dev/null; then
  echo "✅ kitty available (image preview enabled)"
else
  echo "⚠️  kitty not found (image preview disabled)"
  echo "   Using fallback terminal"
fi

echo ""
if $ALL_GOOD; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "   ✅ Setup Complete!"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "Try it now: Press Super + V to open clipboard!"
  echo ""
else
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "   ⚠️  Setup Complete with Warnings"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "Some optional features may not work."
  echo "Install missing dependencies for full functionality."
  echo ""
fi

