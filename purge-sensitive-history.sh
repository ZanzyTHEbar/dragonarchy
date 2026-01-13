#!/usr/bin/env bash
#
# Purge sensitive clipboard files from git history
# 
# WARNING: This script will rewrite git history!
# Make sure to backup your repository first!
#

set -euo pipefail

REPO_DIR="/home/daofficialwizard/dotfiles"
BACKUP_DIR="/home/daofficialwizard/dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║  WARNING: This will rewrite git history!                  ║${NC}"
echo -e "${RED}║  All collaborators will need to re-clone the repository   ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if we're in the right directory
if [[ ! -d "$REPO_DIR/.git" ]]; then
    echo -e "${RED}Error: Not in a git repository${NC}"
    exit 1
fi

cd "$REPO_DIR"

# Create backup
echo -e "${YELLOW}Creating backup at: $BACKUP_DIR${NC}"
if ! git clone "$REPO_DIR" "$BACKUP_DIR" 2>/dev/null; then
    echo -e "${RED}Failed to create backup${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Backup created${NC}"
echo ""

# Check for git-filter-repo
if command -v git-filter-repo &> /dev/null; then
    echo -e "${GREEN}Found git-filter-repo${NC}"
    USE_TOOL="git-filter-repo"
elif command -v bfg &> /dev/null; then
    echo -e "${GREEN}Found BFG Repo Cleaner${NC}"
    USE_TOOL="bfg"
else
    echo -e "${YELLOW}Neither git-filter-repo nor BFG found${NC}"
    echo -e "${YELLOW}Install one with:${NC}"
    echo "  sudo pacman -S git-filter-repo"
    echo "  OR"
    echo "  yay -S bfg"
    echo ""
    echo -e "${YELLOW}Falling back to git filter-branch (slower)${NC}"
    USE_TOOL="filter-branch"
fi
echo ""

# Confirm before proceeding
read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirm
if [[ "$confirm" != "yes" ]]; then
    echo "Aborted."
    exit 0
fi
echo ""

# Files to purge
FILES=(
    "packages/hyprland/.config/clipse/clipboard_history.json"
    "packages/hyprland/.config/clipse/clipse.log"
)
DIRS=(
    "packages/hyprland/.config/clipse/tmp_files"
)

case "$USE_TOOL" in
    "git-filter-repo")
        echo -e "${GREEN}Using git-filter-repo${NC}"
        
        # Purge files
        for file in "${FILES[@]}"; do
            echo "Removing $file from history..."
            git filter-repo --force --invert-paths --path "$file"
        done
        
        # Purge directories
        for dir in "${DIRS[@]}"; do
            echo "Removing $dir from history..."
            git filter-repo --force --invert-paths --path "$dir"
        done
        ;;
        
    "bfg")
        echo -e "${GREEN}Using BFG Repo Cleaner${NC}"
        
        # BFG works with file/folder names, not full paths
        bfg --delete-files clipboard_history.json .
        bfg --delete-files clipse.log .
        bfg --delete-folders tmp_files .
        
        # Clean up
        git reflog expire --expire=now --all
        git gc --prune=now --aggressive
        ;;
        
    "filter-branch")
        echo -e "${YELLOW}Using git filter-branch (this may take a while)${NC}"
        
        # Purge files
        for file in "${FILES[@]}"; do
            echo "Removing $file from history..."
            git filter-branch --force --index-filter \
                "git rm --cached --ignore-unmatch $file" \
                --prune-empty --tag-name-filter cat -- --all
        done
        
        # Purge directories
        for dir in "${DIRS[@]}"; do
            echo "Removing $dir from history..."
            git filter-branch --force --index-filter \
                "git rm -r --cached --ignore-unmatch $dir" \
                --prune-empty --tag-name-filter cat -- --all
        done
        
        # Clean up
        rm -rf .git/refs/original/
        git reflog expire --expire=now --all
        git gc --prune=now --aggressive
        ;;
esac

echo ""
echo -e "${GREEN}✓ History rewritten successfully${NC}"
echo ""

# Verify cleanup
echo "Verifying cleanup..."
found=0
for file in "${FILES[@]}"; do
    if git log --all --full-history -- "$file" 2>/dev/null | grep -q "commit"; then
        echo -e "${RED}✗ $file still found in history${NC}"
        found=1
    else
        echo -e "${GREEN}✓ $file removed from history${NC}"
    fi
done

for dir in "${DIRS[@]}"; do
    if git log --all --full-history -- "$dir" 2>/dev/null | grep -q "commit"; then
        echo -e "${RED}✗ $dir still found in history${NC}"
        found=1
    else
        echo -e "${GREEN}✓ $dir removed from history${NC}"
    fi
done

if [[ $found -eq 1 ]]; then
    echo ""
    echo -e "${RED}Some files were not fully removed. Please check manually.${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Cleanup successful!                                       ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check for remotes
if git remote | grep -q "origin"; then
    echo -e "${YELLOW}⚠️  IMPORTANT: You need to force push to remote repositories${NC}"
    echo ""
    echo "Run these commands:"
    echo ""
    echo "  git push --force --all origin"
    echo "  git push --force --tags origin"
    echo ""
    echo -e "${RED}WARNING: All collaborators will need to re-clone!${NC}"
    echo ""
    
    read -p "Do you want to force push now? (type 'yes' to confirm): " push_confirm
    if [[ "$push_confirm" == "yes" ]]; then
        echo "Force pushing to origin..."
        git push --force --all origin
        git push --force --tags origin
        echo -e "${GREEN}✓ Pushed to remote${NC}"
    else
        echo "Skipped push. Remember to push later!"
    fi
fi

echo ""
echo "Next steps:"
echo "1. ✓ Git history has been cleaned"
echo "2. [ ] Rotate any exposed credentials (passwords, SSH keys)"
echo "3. [ ] Check if repo was public on GitHub/GitLab"
echo "4. [ ] Configure clipse to prevent future issues"
echo "5. [ ] Delete SECURITY_CLEANUP.md and this script after completion"
echo ""
echo "Backup location: $BACKUP_DIR"
