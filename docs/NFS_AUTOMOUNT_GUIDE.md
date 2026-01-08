# NFS Automount Multi-Mode Configuration Guide

## Overview

The `nfs.sh` script provides robust, idempotent NFS mount management with multiple operation modes. It uses managed section markers in `/etc/fstab` for safe re-configuration and supports complex scenarios like server migration, mount point changes, and cleanup operations.

## Key Features

- **Multi-Mode Operation**: Add, replace, update, remove, clean, and status modes
- **Idempotent Re-runs**: Safe to run multiple times without breaking existing config
- **Conflict Detection**: Automatically detects and handles mount point/path conflicts
- **Atomic Updates**: All operations backup fstab and apply changes atomically
- **Managed Sections**: Uses markers to track script-managed entries vs manual entries
- **Automount Integration**: Automatically manages systemd automount units
- **Smart Merging**: Update mode intelligently merges new and existing configurations

## Operation Modes

### 1. ADD Mode (Default)

**Use Case**: Adding new NFS mounts while preserving existing ones

**Behavior**:
- Keeps all existing managed entries
- Adds new entries if they don't already exist
- **Skips** entries that already exist (exact match)
- **Fails** if conflicts detected (same mount point, different NFS path)

```bash
# First run - creates initial config
./nfs.sh server.local /nfs data backup

# Second run - adds new mounts, keeps existing
./nfs.sh server.local /nfs common cache
# Result: Now have data, backup, common, cache mounts
```

**When to Use**:
- Initial setup
- Adding new mounts to existing configuration
- When you want strict conflict checking

**Conflict Behavior**: Aborts on conflict, suggests using `--mode update`

---

### 2. REPLACE Mode

**Use Case**: Complete configuration replacement (nuclear option)

**Behavior**:
- **Removes ALL** existing managed entries
- Stops and disables all existing automount units
- Creates fresh configuration with only new entries
- Complete clean slate

```bash
# Initial config
./nfs.sh server.local /nfs data backup common

# Complete replacement - only 'shared' will exist after
./nfs.sh --mode replace server.local /nfs shared
# Result: data, backup, common removed; only shared remains
```

**When to Use**:
- Server migration (changing NFS server)
- Major reconfiguration
- Starting over from scratch
- Switching environments (dev → prod)

**Warning**: Destructive! All previous entries are lost.

---

### 3. UPDATE Mode (Smart Merge)

**Use Case**: Changing mount points or NFS paths while keeping unrelated mounts

**Behavior**:
- Removes entries that **conflict** with new configuration
  - Same NFS path = conflict
  - Same mount point = conflict
- Keeps entries that don't conflict
- Adds all new entries

```bash
# Initial setup
./nfs.sh server.local /nfs data:old-name backup common

# Update: change data mount point, add new mount, keep others
./nfs.sh --mode update server.local /nfs data:new-name cache
# Result: data→new-name, cache (new), backup (kept), common (kept)

# Update: change server for specific mount
./nfs.sh --mode update newserver.local /nfs data:new-name
# Result: data now from newserver, backup and common from old server (kept)
```

**When to Use**:
- Renaming mount points
- Migrating specific mounts to new server
- Updating mount configuration without losing everything
- Most flexible option for changes

**Conflict Resolution**: Automatic - removes old, adds new

---

### 4. REMOVE Mode

**Use Case**: Removing specific NFS mounts while keeping others

**Behavior**:
- Removes only entries matching the provided configuration
- Matches by NFS path **OR** mount point
- Keeps all other managed entries
- Stops automount units for removed entries

```bash
# Current config: data, backup, common, cache

# Remove specific mounts
./nfs.sh --mode remove server.local /nfs data cache
# Result: backup, common remain; data, cache removed
```

**When to Use**:
- Decommissioning specific mounts
- Cleaning up unused mounts
- Selective removal

**Note**: Does NOT require NFS server to be reachable (safe for removing dead servers)

---

### 5. CLEAN Mode

**Use Case**: Remove all managed NFS entries

**Behavior**:
- Removes entire managed section from fstab
- Stops and disables all managed automount units
- Complete cleanup - returns to pre-script state
- **No arguments required**

```bash
# Remove everything managed by this script
./nfs.sh --mode clean

# Confirm with status
./nfs.sh --mode status
# Output: "No managed configuration found"
```

**When to Use**:
- Uninstalling NFS completely
- Starting completely fresh
- Troubleshooting (clean slate)

**Note**: Does not affect manually-added fstab entries outside managed section

---

### 6. STATUS Mode

**Use Case**: View current configuration without making changes

**Behavior**:
- Shows managed section from fstab
- Lists all managed entries (NFS path → mount point)
- Shows automount unit status (active/inactive)
- Shows currently mounted NFS filesystems
- **No arguments required**

```bash
# Check current configuration
./nfs.sh --mode status
```

**Output Example**:
```
=== NFS Automount Managed Configuration ===

Managed Section in /etc/fstab:
----------------------------------------
  # BEGIN NFS-AUTOMOUNT MANAGED SECTION - DO NOT EDIT
  # Last updated: 2025-01-20 14:30:00
  # Mode: update
  server.local:/nfs/data /mnt/dragonnet nfs4 [options]
  server.local:/nfs/common /mnt/shared nfs4 [options]
  # END NFS-AUTOMOUNT MANAGED SECTION
----------------------------------------

Parsed Entries:
  1. server.local:/nfs/data -> /mnt/dragonnet
  2. server.local:/nfs/common -> /mnt/shared

Automount Unit Status:
  mnt-dragonnet.automount                 : ACTIVE
  mnt-shared.automount                    : ACTIVE

Currently Mounted:
  server.local:/nfs/data on /mnt/dragonnet type nfs4 (rw,...)
```

**When to Use**:
- Checking current configuration
- Troubleshooting
- Documentation/audit purposes
- Before making changes (understand current state)

---

## Common Scenarios

### Scenario 1: Changing Mount Point Name

**Problem**: Need to rename `/mnt/data` to `/mnt/dragonnet`

```bash
# Option 1: UPDATE mode (keeps other mounts)
./nfs.sh --mode update server.local /nfs data:dragonnet

# Option 2: REMOVE old + ADD new (more explicit)
./nfs.sh --mode remove server.local /nfs data
./nfs.sh --mode add server.local /nfs data:dragonnet
```

### Scenario 2: Server Migration

**Problem**: Moving from `oldserver.local` to `newserver.local`, keeping same structure

```bash
# Option 1: REPLACE mode (clean replacement)
./nfs.sh --mode replace newserver.local /nfs data backup common

# Option 2: UPDATE mode (if some mounts stay on old server)
./nfs.sh --mode update newserver.local /nfs data backup
# common stays on oldserver.local
```

### Scenario 3: Adding Mounts Incrementally

**Problem**: Adding new shares over time

```bash
# Initial setup
./nfs.sh server.local /nfs data

# Add more later (default mode)
./nfs.sh server.local /nfs backup
./nfs.sh server.local /nfs common

# Or add multiple at once
./nfs.sh server.local /nfs cache media docs
```

### Scenario 4: Dev/Test/Prod Environments

**Problem**: Switch between environments

```bash
# Development
./nfs.sh --mode replace dev-server.local /nfs/dev data:dev-data common:dev-shared

# Switch to production (complete replacement)
./nfs.sh --mode replace prod-server.local /nfs/prod data:prod-data common:prod-shared

# Quick environment check
./nfs.sh --mode status | grep "server.local"
```

### Scenario 5: Removing Dead Server

**Problem**: Old server is offline, need to remove its mounts

```bash
# REMOVE mode doesn't require server to be reachable
./nfs.sh --mode remove dead-server.local /nfs data backup

# Verify cleanup
./nfs.sh --mode status
```

### Scenario 6: Testing Configuration

**Problem**: Want to test config without losing current setup

```bash
# Check current state
./nfs.sh --mode status > current-config.txt

# Try new configuration (use replace for clean test)
./nfs.sh --mode replace test-server.local /nfs test-data

# If not working, restore old config
# (manually edit fstab or use backup: /etc/fstab.backup.*)
```

---

## Managed Section Format

The script uses markers in `/etc/fstab` to track its entries:

```fstab
# BEGIN NFS-AUTOMOUNT MANAGED SECTION - DO NOT EDIT
# Last updated: 2025-01-20 14:30:00
# Mode: update
# Command: nfs.sh --mode update server.local /nfs data:dragonnet common
server.local:/nfs/data /mnt/dragonnet nfs4 rw,async,... 0 0
server.local:/nfs/common /mnt/shared nfs4 rw,async,... 0 0
# END NFS-AUTOMOUNT MANAGED SECTION
```

**Important**:
- Only entries within markers are managed by the script
- Manual fstab entries outside this section are preserved
- Each re-run updates the metadata (timestamp, mode, command)
- Markers must not be manually edited

---

## Conflict Detection

The script detects two types of conflicts:

### 1. Mount Point Conflict

**Scenario**: Same mount point, different NFS source

```bash
# Existing: server1:/nfs/data -> /mnt/shared
# New:      server2:/nfs/data -> /mnt/shared
# Conflict: Same mount point!
```

**Resolution**:
- **ADD mode**: Fails with error
- **UPDATE mode**: Removes old, adds new
- **REPLACE mode**: N/A (removes everything)

### 2. NFS Path Conflict

**Scenario**: Same NFS path, different mount point

```bash
# Existing: server:/nfs/data -> /mnt/old-name
# New:      server:/nfs/data -> /mnt/new-name
# Conflict: Same NFS path!
```

**Resolution**:
- **ADD mode**: Fails with error
- **UPDATE mode**: Removes old, adds new
- **REPLACE mode**: N/A (removes everything)

---

## Safety Features

### 1. Automatic Backups

Every modification creates a timestamped backup:

```bash
/etc/fstab.backup.20250120_143000
```

### 2. Atomic Updates

All fstab modifications are atomic:
- Changes written to temp file
- Validated
- Atomically moved to fstab
- If anything fails, original fstab is untouched

### 3. Systemd Integration

Automount units are managed automatically:
- Started/stopped as needed
- Enabled/disabled appropriately
- Reloaded after fstab changes

### 4. Privilege Checking

Script enforces proper privilege usage:
- Must NOT be run directly as root
- Uses sudo for privileged operations
- Checks sudo availability before starting

---

## Troubleshooting

### Issue: "CONFLICT: Mount point conflict"

**Cause**: Trying to use same mount point for different NFS path in ADD mode

**Solutions**:
```bash
# Option 1: Use update mode to resolve automatically
./nfs.sh --mode update server /nfs data:new-name

# Option 2: Remove old entry first
./nfs.sh --mode remove server /nfs data
./nfs.sh --mode add server /nfs data:new-name

# Option 3: Use different mount point name
./nfs.sh --mode add server /nfs data:alternative-name
```

### Issue: Mount test failed

**Cause**: NFS server unreachable or export not available

**Solutions**:
```bash
# 1. Check server connectivity
ping server.local

# 2. Check NFS exports
showmount -e server.local

# 3. Check automount unit status
systemctl status mnt-data.automount

# 4. Check systemd logs
journalctl -u mnt-data.automount -f

# 5. Manual mount test
sudo mount -t nfs4 server.local:/nfs/data /mnt/data
```

### Issue: Automount unit won't start

**Cause**: Conflicting fstab entries or mount point issues

**Solutions**:
```bash
# 1. Check for duplicate fstab entries
grep "server.local:/nfs/data" /etc/fstab

# 2. Clean and reconfigure
./nfs.sh --mode clean
./nfs.sh --mode add server.local /nfs data

# 3. Check mount point permissions
ls -ld /mnt/data

# 4. Reload systemd
sudo systemctl daemon-reload
sudo systemctl restart mnt-data.automount
```

### Issue: Need to recover old configuration

**Cause**: Accidentally removed needed entries

**Solutions**:
```bash
# 1. Find latest backup
ls -lrt /etc/fstab.backup.*

# 2. View backup
cat /etc/fstab.backup.20250120_143000

# 3. Restore if needed
sudo cp /etc/fstab.backup.20250120_143000 /etc/fstab
sudo systemctl daemon-reload
```

---

## Best Practices

### 1. Check Status Before Changes

Always check current state first:

```bash
./nfs.sh --mode status
```

### 2. Use Update Mode for Most Changes

UPDATE mode is safest for changes:

```bash
./nfs.sh --mode update server /nfs data:new-name
```

### 3. Test with Status After Changes

Verify configuration after modifications:

```bash
./nfs.sh --mode add server /nfs data
./nfs.sh --mode status
```

### 4. Document Your Commands

The script logs commands in fstab comments for reference:

```bash
# Command: nfs.sh --mode update server.local /nfs data:dragonnet
```

### 5. Keep Backups

Fstab backups are created automatically, but for critical systems:

```bash
sudo cp /etc/fstab /etc/fstab.manual-backup.$(date +%Y%m%d)
```

### 6. Use Explicit Mount Names for Clarity

Instead of auto-generated names:

```bash
# Less clear
./nfs.sh server /nfs datasets-2024-backup

# More clear
./nfs.sh server /nfs datasets-2024-backup:backup-2024
```

---

## Advanced Usage

### Custom Mount Points with Special Names

```bash
# Nested structure names
./nfs.sh server /nfs project/data:project-data project/logs:project-logs

# Environment-specific names
./nfs.sh server /nfs data:prod-data data:dev-data

# Service-specific names
./nfs.sh server /nfs shared:nextcloud-data shared:jellyfin-media
```

### Managing Multiple Servers

```bash
# Server 1: Production data
./nfs.sh prod-server.local /production data:prod-data config:prod-config

# Server 2: Backup data
./nfs.sh backup-server.local /backups daily:daily-backup weekly:weekly-backup

# Check all managed mounts
./nfs.sh --mode status
```

### Environment Switching Script

```bash
#!/bin/bash
# switch-env.sh - Switch between dev/prod NFS environments

ENV="${1:-dev}"

case "$ENV" in
    dev)
        nfs.sh --mode replace dev-server.local /nfs/dev data:data-dev common:common-dev
        ;;
    prod)
        nfs.sh --mode replace prod-server.local /nfs/prod data:data-prod common:common-prod
        ;;
    *)
        echo "Usage: $0 {dev|prod}"
        exit 1
        ;;
esac

echo "Switched to $ENV environment"
nfs.sh --mode status
```

---

## Migration Guide

### From Manual fstab Entries

If you have existing manual NFS entries:

```bash
# 1. Document current entries
grep nfs /etc/fstab > my-current-nfs.txt

# 2. Remove manual entries from fstab (outside managed section)

# 3. Add via script
./nfs.sh server /nfs data backup common

# 4. Verify
./nfs.sh --mode status
```

### From Old Script Version

If migrating from old version without managed sections:

```bash
# 1. Note current configuration
mount | grep nfs4 > current-mounts.txt

# 2. Clean old entries
# (manually remove old NFS entries from fstab)

# 3. Configure with new script
./nfs.sh server /nfs data backup common

# 4. Verify mounts
./nfs.sh --mode status
```

---

## Performance Notes

The script uses optimized NFS mount options:

```
nfs4 rw,async,rsize=65536,wsize=65536,proto=tcp,vers=4.1,noatime,
actimeo=10,intr,cto,soft,timeo=60,retrans=3,acregmin=0,acregmax=0,
acdirmin=0,acdirmax=0,lookupcache=positive,x-systemd.automount,
x-systemd.idle-timeout=60,_netdev
```

**Key Options**:
- `async`: Async writes for performance
- `rsize/wsize=65536`: Large transfer sizes
- `noatime`: No access time updates
- `soft,timeo=60`: Timeout after 60s (prevents hangs)
- `x-systemd.automount`: Auto-mount on access
- `x-systemd.idle-timeout=60`: Unmount after 60s idle

---

## Summary

| Mode | Use Case | Destructive | Requires Server | Arguments |
|------|----------|-------------|-----------------|-----------|
| add | Add new mounts | No | Yes | Required |
| replace | Complete reconfiguration | Yes (all entries) | Yes | Required |
| update | Smart merge/update | Partial (conflicts) | Yes | Required |
| remove | Remove specific mounts | Partial (matches) | No | Required |
| clean | Remove all managed | Yes (all entries) | No | None |
| status | View configuration | No | No | None |

**Quick Decision Guide**:
- 🟢 **First time setup**: Use `add` (default)
- 🟡 **Changing mount points**: Use `update`
- 🟡 **Adding more mounts**: Use `add` (default)
- 🔴 **Server migration**: Use `replace`
- 🔴 **Major reconfiguration**: Use `replace`
- 🟢 **Remove specific mount**: Use `remove`
- 🔴 **Complete cleanup**: Use `clean`
- 🟢 **Check current state**: Use `status`

