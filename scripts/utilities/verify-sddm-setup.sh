#!/usr/bin/env bash
# Verify SDDM theme installation and configuration

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo -e "${BLUE}=== SDDM Theme Installation Verification ===${NC}\n"

# Check 1: Is SDDM installed?
echo -n "1. Checking if SDDM is installed... "
if command -v sddm >/dev/null 2>&1; then
    echo -e "${GREEN}✓ SDDM is installed${NC}"
    SDDM_VERSION=$(sddm --version 2>&1 | head -1 || echo "Unknown version")
    echo "   Version: $SDDM_VERSION"
else
    echo -e "${RED}✗ SDDM is not installed${NC}"
    echo -e "${YELLOW}   SDDM theme setup is not needed without SDDM${NC}"
    exit 0
fi

# Check 2: Are themes present in dotfiles?
echo -n "2. Checking dotfiles SDDM package... "
DOTFILES_THEMES_DIR="$DOTFILES_DIR/packages/sddm/usr/share/sddm/themes"
if [[ -d "$DOTFILES_THEMES_DIR" ]]; then
    THEME_COUNT=$(find "$DOTFILES_THEMES_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l)
    echo -e "${GREEN}✓ Found $THEME_COUNT theme(s) in dotfiles${NC}"
    echo "   Location: $DOTFILES_THEMES_DIR"
    find "$DOTFILES_THEMES_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sed 's/^/   - /'
else
    echo -e "${RED}✗ Dotfiles SDDM themes directory not found${NC}"
    exit 1
fi

# Check 3: Are themes installed in system?
echo -n "3. Checking system SDDM themes... "
SYSTEM_THEMES_DIR="/usr/share/sddm/themes"
if [[ -d "$SYSTEM_THEMES_DIR" ]]; then
    INSTALLED_COUNT=$(find "$SYSTEM_THEMES_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l)
    echo -e "${GREEN}✓ Found $INSTALLED_COUNT theme(s) in system${NC}"
    echo "   Location: $SYSTEM_THEMES_DIR"
    
    # Check if our themes are present
    echo -n "   Checking for dotfiles themes... "
    MISSING_THEMES=()
    while IFS= read -r theme; do
        if [[ ! -d "$SYSTEM_THEMES_DIR/$(basename "$theme")" ]]; then
            MISSING_THEMES+=("$(basename "$theme")")
        fi
    done < <(find "$DOTFILES_THEMES_DIR" -mindepth 1 -maxdepth 1 -type d)
    
    if [[ ${#MISSING_THEMES[@]} -eq 0 ]]; then
        echo -e "${GREEN}✓ All dotfiles themes are installed${NC}"
    else
        echo -e "${YELLOW}⚠ Missing themes: ${MISSING_THEMES[*]}${NC}"
    fi
else
    echo -e "${RED}✗ System themes directory not found${NC}"
    echo -e "${YELLOW}   Run: $SCRIPT_DIR/theme-manager/refresh-sddm${NC}"
fi

# Check 4: Is SDDM configured with a theme?
echo -n "4. Checking SDDM theme configuration... "
SDDM_CONF="/etc/sddm.conf.d/10-theme.conf"
if [[ -f "$SDDM_CONF" ]]; then
    echo -e "${GREEN}✓ Configuration file exists${NC}"
    echo "   Location: $SDDM_CONF"
    
    # Extract configured theme
    CONFIGURED_THEME=$(grep -E '^\s*Current\s*=' "$SDDM_CONF" | sed -E 's/^\s*Current\s*=\s*//' | tr -d '[:space:]')
    if [[ -n "$CONFIGURED_THEME" ]]; then
        echo "   Current theme: $CONFIGURED_THEME"
        
        # Check if configured theme exists
        if [[ -d "$SYSTEM_THEMES_DIR/$CONFIGURED_THEME" ]]; then
            echo -e "   ${GREEN}✓ Theme directory exists${NC}"
            
            # Check for Main.qml (required for SDDM themes)
            if [[ -f "$SYSTEM_THEMES_DIR/$CONFIGURED_THEME/Main.qml" ]]; then
                echo -e "   ${GREEN}✓ Main.qml found (theme is valid)${NC}"
            else
                echo -e "   ${RED}✗ Main.qml not found (theme may not work)${NC}"
            fi
        else
            echo -e "   ${RED}✗ Theme directory not found${NC}"
        fi
    else
        echo -e "${YELLOW}   ⚠ No theme configured in file${NC}"
    fi
else
    echo -e "${YELLOW}✗ Configuration file not found${NC}"
    echo -e "${YELLOW}   Default SDDM theme will be used${NC}"
    echo -e "${YELLOW}   To configure: $DOTFILES_DIR/scripts/theme-manager/sddm-set <theme-name>${NC}"
fi

# Check 5: SDDM service status
echo -n "5. Checking SDDM service status... "
if systemctl is-enabled sddm.service >/dev/null 2>&1; then
    if systemctl is-active sddm.service >/dev/null 2>&1; then
        echo -e "${GREEN}✓ SDDM service is enabled and running${NC}"
    else
        echo -e "${YELLOW}⚠ SDDM service is enabled but not running${NC}"
    fi
else
    echo -e "${YELLOW}⚠ SDDM service is not enabled${NC}"
    echo -e "${YELLOW}   Enable with: sudo systemctl enable sddm.service${NC}"
fi

# Summary
echo -e "\n${BLUE}=== Summary ===${NC}"

if [[ ${#MISSING_THEMES[@]} -eq 0 ]] && [[ -f "$SDDM_CONF" ]] && [[ -n "$CONFIGURED_THEME" ]]; then
    echo -e "${GREEN}✓ SDDM theme setup appears to be complete!${NC}"
    echo ""
    echo "To change themes:"
    echo "  • Interactive: $DOTFILES_DIR/scripts/theme-manager/sddm-menu"
    echo "  • Direct: $DOTFILES_DIR/scripts/theme-manager/sddm-set <theme-name>"
    echo ""
    echo "To apply changes immediately (will end current session):"
    echo "  sudo systemctl restart sddm"
else
    echo -e "${YELLOW}⚠ SDDM theme setup is incomplete${NC}"
    echo ""
    echo "To complete setup:"
    echo "  1. Install themes: $DOTFILES_DIR/scripts/theme-manager/refresh-sddm"
    echo "  2. Configure theme: $DOTFILES_DIR/scripts/theme-manager/sddm-set <theme-name>"
    echo ""
    echo "Or run the full install script:"
    echo "  $DOTFILES_DIR/install.sh"
fi

exit 0

