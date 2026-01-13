# Security Cleanup: Purging Sensitive Clipboard Data from Git History

## ⚠️ CRITICAL: Sensitive Data Exposure

Clipboard history files containing **passwords, SSH keys, commands, and personal information** were committed to git.

## ✅ Completed Steps

1. ✅ Added clipse files to `.gitignore`
2. ✅ Removed files from git index
3. ✅ Deleted files from filesystem

## 🔴 REQUIRED: Purge from Git History

**These files still exist in git history and must be removed.**

### Option 1: Using git-filter-repo (Recommended)

#### Install git-filter-repo
```bash
# On Arch Linux
sudo pacman -S git-filter-repo

# Or via pip
pip install git-filter-repo
```

#### Purge the sensitive files
```bash
cd /home/daofficialwizard/dotfiles

# Backup first!
git clone . ../dotfiles-backup

# Purge the files from all history
git filter-repo --path packages/hyprland/.config/clipse/clipboard_history.json --invert-paths
git filter-repo --path packages/hyprland/.config/clipse/clipse.log --invert-paths
git filter-repo --path packages/hyprland/.config/clipse/tmp_files/ --invert-paths
```

### Option 2: Using BFG Repo Cleaner

#### Install BFG
```bash
# On Arch Linux
yay -S bfg

# Or download manually
# wget https://repo1.maven.org/maven2/com/madgag/bfg/1.14.0/bfg-1.14.0.jar
```

#### Purge the files
```bash
cd /home/daofficialwizard/dotfiles

# Backup first!
git clone . ../dotfiles-backup

# Create a file list
cat > /tmp/files-to-delete.txt << 'EOF'
packages/hyprland/.config/clipse/clipboard_history.json
packages/hyprland/.config/clipse/clipse.log
packages/hyprland/.config/clipse/tmp_files
EOF

# Run BFG
bfg --delete-files clipboard_history.json .
bfg --delete-files clipse.log .
bfg --delete-folders tmp_files .

# Clean up
git reflog expire --expire=now --all
git gc --prune=now --aggressive
```

### Option 3: Manual with git filter-branch (Last Resort)

```bash
cd /home/daofficialwizard/dotfiles

# Backup first!
git clone . ../dotfiles-backup

# Remove each file from history
git filter-branch --force --index-filter \
  'git rm --cached --ignore-unmatch packages/hyprland/.config/clipse/clipboard_history.json' \
  --prune-empty --tag-name-filter cat -- --all

git filter-branch --force --index-filter \
  'git rm --cached --ignore-unmatch packages/hyprland/.config/clipse/clipse.log' \
  --prune-empty --tag-name-filter cat -- --all

git filter-branch --force --index-filter \
  'git rm -r --cached --ignore-unmatch packages/hyprland/.config/clipse/tmp_files' \
  --prune-empty --tag-name-filter cat -- --all

# Clean up
git reflog expire --expire=now --all
git gc --prune=now --aggressive
```

## 🔄 Force Push to Remote

**⚠️ WARNING: This will rewrite remote history. Coordinate with any collaborators!**

```bash
# Check what remotes exist
git remote -v

# Force push to all remotes
git push --force --all origin
git push --force --tags origin

# If you have other remotes, push to them too
# git push --force --all <remote-name>
```

## 🔐 Additional Security Measures

### 1. Review Exposed Credentials

From the clipboard history, the following may need to be rotated:

- **Passwords** (multiple found in clipboard)
- **SSH keys** referenced:
  - `/run/media/daofficialwizard/Ventoy/certs/*`
  - `~/.ssh/` keys
- **Email addresses**:
  - `z.heim@avular.com`
  - `p.hanckmann@avular.com`
- **Personal information** (names, addresses)

### 2. Rotate Compromised Credentials

```bash
# Generate new SSH keys if needed
ssh-keygen -t ed25519 -C "your_email@example.com"

# Update any passwords that were in clipboard
# Change any tokens or API keys
```

### 3. Configure Clipse Properly

Create a clipse config to limit history and exclude sensitive patterns:

```bash
# Edit ~/.config/clipse/config.json
cat > ~/.config/clipse/config.json << 'EOF'
{
  "historySize": 100,
  "maxItemLength": 1000,
  "excludePatterns": [
    ".*password.*",
    ".*token.*",
    ".*key.*",
    "-----BEGIN.*PRIVATE KEY-----"
  ]
}
EOF
```

### 4. Check GitHub/Remote for Exposure

If this was pushed to GitHub or any public remote:

1. **Check GitHub security alerts** (if applicable)
2. **Consider the repo compromised** - sensitive data may have been scraped
3. **Rotate all exposed credentials immediately**
4. **Consider making the repo private** (if public)

### 5. Verify Cleanup

```bash
# Search for any remaining sensitive content
cd /home/daofficialwizard/dotfiles
git log --all --full-history -- packages/hyprland/.config/clipse/

# Should return nothing after cleanup
```

## 📋 Checklist

- [ ] Install git-filter-repo or BFG
- [ ] Create backup of repository
- [ ] Run history purge command
- [ ] Force push to all remotes
- [ ] Verify files are gone from history
- [ ] Rotate any exposed credentials
- [ ] Configure clipse to prevent future issues
- [ ] Check if repo was public (GitHub/GitLab/etc)
- [ ] Monitor for any unauthorized access
- [ ] Delete this SECURITY_CLEANUP.md file after completion

## 🔍 Verification Commands

```bash
# Verify files are not in current working tree
ls -la packages/hyprland/.config/clipse/

# Verify files are not in any commit
git log --all --full-history -- packages/hyprland/.config/clipse/clipboard_history.json

# Check repository size (should be smaller after cleanup)
git count-objects -vH
```

## 📞 Need Help?

If you need assistance:
- git-filter-repo docs: https://github.com/newren/git-filter-repo
- BFG Repo Cleaner: https://rtyley.github.io/bfg-repo-cleaner/
- GitHub removing sensitive data: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository

---

**Remember**: After cleanup, this file itself should be deleted as it documents the security incident.
