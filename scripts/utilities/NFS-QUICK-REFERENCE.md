# NFS Automount Quick Reference

## TL;DR Command Examples

```bash
# Show current configuration
./nfs.sh --mode status

# First time setup
./nfs.sh server.local /nfs data backup common

# Add more mounts (keeps existing)
./nfs.sh server.local /nfs cache media

# Change mount point name (smart merge)
./nfs.sh --mode update server.local /nfs data:newname

# Complete server migration
./nfs.sh --mode replace newserver.local /nfs data backup

# Remove specific mounts
./nfs.sh --mode remove server.local /nfs data

# Remove everything
./nfs.sh --mode clean
```

## Mode Cheat Sheet

| Mode | What It Does | Safe? | Use When |
|------|--------------|-------|----------|
| **add** | Adds new, skips existing | ✅ Yes | First setup, adding mounts |
| **update** | Smart merge, resolves conflicts | ⚠️ Partial | Changing names, updating config |
| **replace** | Deletes ALL, creates fresh | ❌ No | Server migration, major reconfig |
| **remove** | Removes specific entries | ⚠️ Partial | Decommissioning mounts |
| **clean** | Removes ALL managed entries | ❌ No | Complete cleanup |
| **status** | Shows current config | ✅ Yes | Checking state, no changes |

## Common Scenarios - One Liners

```bash
# Rename mount point: /mnt/data → /mnt/dragonnet
./nfs.sh --mode update server.local /nfs data:dragonnet

# Switch servers: oldserver → newserver
./nfs.sh --mode replace newserver.local /nfs data backup common

# Add mount without breaking existing
./nfs.sh server.local /nfs newshare

# Remove dead server's mounts (server can be offline)
./nfs.sh --mode remove dead-server.local /nfs data backup

# Check what's configured
./nfs.sh --mode status

# Start fresh
./nfs.sh --mode clean
./nfs.sh server.local /nfs data
```

## Decision Tree

```
Need to make changes?
├─ Just checking? → --mode status
├─ First time? → ./nfs.sh (no --mode, uses add)
├─ Adding new mounts? → ./nfs.sh (no --mode, uses add)
├─ Changing mount point names?
│  └─ --mode update
├─ Changing servers?
│  ├─ All mounts? → --mode replace
│  └─ Some mounts? → --mode update
├─ Removing mounts?
│  ├─ Specific ones? → --mode remove
│  └─ All of them? → --mode clean
└─ Something broke? → --mode clean, then start over
```

## Safety Ladder (Most Safe → Most Destructive)

1. 🟢 **status** - Read-only, completely safe
2. 🟢 **add** - Only adds, never removes, abort on conflict
3. 🟡 **update** - Removes conflicts, adds new, keeps others
4. 🟡 **remove** - Removes matches, keeps others
5. 🔴 **replace** - Removes ALL, creates fresh (backup made)
6. 🔴 **clean** - Removes ALL managed entries (backup made)

## Troubleshooting One-Liners

```bash
# See what's configured
./nfs.sh --mode status

# Check server is reachable
ping server.local
showmount -e server.local

# Check automount status
systemctl status mnt-data.automount

# Manual mount test
sudo mount -t nfs4 server.local:/nfs/data /mnt/data
sudo umount /mnt/data

# Recover from mistakes (find latest backup)
ls -lt /etc/fstab.backup.* | head -1

# Start completely fresh
./nfs.sh --mode clean
./nfs.sh server.local /nfs data

# See systemd logs
journalctl -u mnt-data.automount -f
```

## Examples by Use Case

### Development Workflow
```bash
# Start dev environment
./nfs.sh dev-server.local /nfs/dev data:dev-data common:dev-shared

# Switch to staging
./nfs.sh --mode replace staging-server.local /nfs/staging data:staging-data common:staging-shared

# Switch to production
./nfs.sh --mode replace prod-server.local /nfs/prod data:prod-data common:prod-shared
```

### Gradual Migration
```bash
# Current state: all on oldserver
./nfs.sh --mode status

# Move 'data' to newserver, keep others on oldserver
./nfs.sh --mode update newserver.local /data data

# Later: move 'backup' to newserver too
./nfs.sh --mode update newserver.local /data backup

# Check mixed configuration
./nfs.sh --mode status
```

### Cleanup & Maintenance
```bash
# Remove unused mounts
./nfs.sh --mode remove oldserver.local /nfs cache temp

# Remove dead server (server offline = OK)
./nfs.sh --mode remove dead-server.local /nfs data backup

# Complete cleanup for maintenance
./nfs.sh --mode clean
```

## Pro Tips

1. **Always check status first**: `./nfs.sh --mode status`
2. **Backups are automatic**: Check `/etc/fstab.backup.*` if needed
3. **Conflicts in ADD?**: Use `--mode update` instead
4. **Server unreachable?**: Use `--mode remove` (doesn't check server)
5. **Not sure?**: Use `--mode status` (read-only, always safe)
6. **Custom names**: `data:dragonnet` → mounts to `/mnt/dragonnet`
7. **Auto names**: `data/backup/2024` → mounts to `/mnt/data-backup-2024`

## What Gets Modified

### Fstab Structure
```
# Your manual entries (UNTOUCHED)
UUID=... / ext4 ...

# BEGIN NFS-AUTOMOUNT MANAGED SECTION - DO NOT EDIT
# Last updated: 2025-01-20 14:30:00
# Mode: update
# Command: nfs.sh --mode update server /nfs data:dragonnet
server.local:/nfs/data /mnt/dragonnet nfs4 [options]
server.local:/nfs/common /mnt/shared nfs4 [options]
# END NFS-AUTOMOUNT MANAGED SECTION

# Your other manual entries (UNTOUCHED)
```

**Script only modifies managed section!**

### Systemd Units Affected
- `mnt-{mountname}.automount` - Auto-mount on access
- `mnt-{mountname}.mount` - Underlying mount unit
- All units auto-managed by systemd from fstab

## When Things Go Wrong

```bash
# 1. Check what's configured
./nfs.sh --mode status

# 2. Check if server is up
ping server.local
showmount -e server.local

# 3. Check systemd status
systemctl status mnt-data.automount
journalctl -u mnt-data.automount -n 50

# 4. Try manual mount
sudo mount -t nfs4 server.local:/nfs/data /mnt/test
ls /mnt/test
sudo umount /mnt/test

# 5. If all else fails: clean slate
./nfs.sh --mode clean
./nfs.sh server.local /nfs data

# 6. Still broken? Check backups
ls -lt /etc/fstab.backup.*
sudo cp /etc/fstab.backup.YYYYMMDD_HHMMSS /etc/fstab
sudo systemctl daemon-reload
```

## Full Documentation

For comprehensive guide with scenarios and troubleshooting:
- [Complete NFS Automount Guide](../../docs/NFS_AUTOMOUNT_GUIDE.md)

For script source and testing:
- Script: `scripts/utilities/nfs.sh`
- Tests: `scripts/utilities/test-nfs-modes.sh`

