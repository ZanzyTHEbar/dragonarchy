#!/usr/bin/env bash
#
# Fix Hyprland package stowing issues
#

set -euo pipefail

# Get script directory and source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/logging.sh"

DOTFILES_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
PACKAGES_DIR="$DOTFILES_DIR/packages"

log_info "🔧 Fixing Hyprland package stowing..."
log_info "Dotfiles: $DOTFILES_DIR"
log_info "Packages: $PACKAGES_DIR"
echo

# Check if hyprland package exists
if [[ ! -d "$PACKAGES_DIR/hyprland" ]]; then
    log_error "Hyprland package not found at $PACKAGES_DIR/hyprland"
    exit 1
fi

# Show what's in the package
log_step "Contents of hyprland package:"
cd "$PACKAGES_DIR/hyprland"
find .config -type f | head -20
echo

# Check for existing files that might conflict
log_step "Checking for conflicts..."
CONFLICTS=()
while IFS= read -r file; do
    target_file="$HOME/${file#./}"
    if [[ -e "$target_file" && ! -L "$target_file" ]]; then
        CONFLICTS+=("$target_file")
        log_warning "Conflict: $target_file exists and is not a symlink"
    fi
done < <(find .config/hypr .config/swaync .config/waybar .config/walker .config/swayosd .config/swaync-widgets -type f 2>/dev/null)

if [[ ${#CONFLICTS[@]} -gt 0 ]]; then
    echo
    log_warning "Found ${#CONFLICTS[@]} conflicting files"
    log_info "These files need to be removed or backed up before stowing"
    echo
    read -p "Back up and remove conflicting files? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$BACKUP_DIR"
        log_info "Backing up to $BACKUP_DIR"
        for file in "${CONFLICTS[@]}"; do
            mkdir -p "$BACKUP_DIR/$(dirname "$file")"
            mv "$file" "$BACKUP_DIR/$file"
            log_info "  Backed up: $file"
        done
        log_success "Backup complete"
    else
        log_error "Cannot proceed without resolving conflicts"
        exit 1
    fi
fi

# Unstow first (clean slate)
log_step "Unstowing hyprland package..."
cd "$PACKAGES_DIR"
stow -D -t "$HOME" hyprland 2>/dev/null || true
log_info "Unstowed"

# Restow without --no-folding (let stow create directories properly)
log_step "Restowing hyprland package..."
if stow -v -t "$HOME" hyprland 2>&1 | tee /tmp/stow_output.txt; then
    log_success "Hyprland package stowed successfully"
else
    log_error "Failed to stow hyprland package"
    echo
    log_info "Output:"
    cat /tmp/stow_output.txt
    exit 1
fi

# Verify installation
log_step "Verifying installation..."
EXPECTED_FILES=(
    "$HOME/.config/hypr/hyprland.conf"
    "$HOME/.config/hypr/config/keyboard.conf"
    "$HOME/.config/hypr/config/keybinds.conf"
    "$HOME/.config/hypr/config/monitor.conf"
    "$HOME/.config/hypr/config/hypridle.conf"
    "$HOME/.config/hypr/config/hyprlock.conf"
    "$HOME/.config/waybar/config.jsonc"
    "$HOME/.config/swaync/config.json"
)

MISSING=()
for file in "${EXPECTED_FILES[@]}"; do
    if [[ -L "$file" ]]; then
        log_success "✓ $file"
    else
        log_error "✗ $file (missing or not a symlink)"
        MISSING+=("$file")
    fi
done

if [[ ${#MISSING[@]} -eq 0 ]]; then
    echo
    log_success "🎉 All Hyprland configs stowed successfully!"
else
    echo
    log_error "Failed to stow ${#MISSING[@]} files"
    exit 1
fi

# Cleanup
rm -f /tmp/stow_output.txt

