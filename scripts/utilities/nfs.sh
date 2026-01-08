#!/bin/bash

# NFS Systemd Automount Configuration Script
# Dynamically configures NFS mounts with systemd automount for specified host, base path, and datasets
# Supports multiple operation modes for safe re-configuration

## Usage: ./nfs.sh [--mode MODE] <nfs_server_host> <nfs_server_base> <dataset1[:mountpoint1]> [dataset2[:mountpoint2] ...]
## 
## Modes:
##   --mode add      (default) Skip existing entries, add only new ones
##   --mode replace  Remove ALL managed entries, add new configuration (complete replacement)
##   --mode update   Smart merge: remove conflicts, add new, keep non-conflicting
##   --mode remove   Remove only entries matching the provided configuration
##   --mode clean    Remove all managed entries (no server/dataset args needed)
##   --mode status   Show current managed configuration (no changes made)
##
## Examples:
##   Basic usage (auto-generate mount points):
##     ./nfs.sh 192.168.1.100 /mnt/nfs datasets/dataset1 datasets/dataset2
##     -> Mounts to /mnt/dataset1 and /mnt/dataset2
##
##   Custom mount points:
##     ./nfs.sh dragonserver.local mainpool/nfsroot common data:dragonnet
##     -> Mounts common to /mnt/common and data to /mnt/dragonnet
##
##   Replace entire configuration:
##     ./nfs.sh --mode replace newserver.local /data shared:dragonnet
##     -> Removes all old entries, adds new ones
##
##   Update with smart merge:
##     ./nfs.sh --mode update server.local /nfs data:newname common
##     -> Updates data mount point, adds common, keeps other entries
##
##   Remove specific entries:
##     ./nfs.sh --mode remove server.local /nfs data
##     -> Removes only the data entry
##
##   Clean all managed entries:
##     ./nfs.sh --mode clean
##     -> Removes all NFS entries managed by this script
##
## This script uses managed section markers in /etc/fstab for safe re-configuration
## All operations are atomic and create backups before modifications
## The automount units will be managed and started automatically

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Get script directory and source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091  # Runtime-resolved path to logging library
source "${SCRIPT_DIR}/../lib/logging.sh"

# Variables
readonly FSTAB="/etc/fstab"
readonly MOUNT_POINT="/mnt"
readonly MANAGED_SECTION_BEGIN="# BEGIN NFS-AUTOMOUNT MANAGED SECTION - DO NOT EDIT"
readonly MANAGED_SECTION_END="# END NFS-AUTOMOUNT MANAGED SECTION"

# Operation mode (add, replace, update, remove, clean, status)
OPERATION_MODE="add"

# Parse --mode flag if present
if [[ "${1:-}" == "--mode" ]]; then
    OPERATION_MODE="${2:-add}"
    shift 2
fi

# Validate operation mode
case "$OPERATION_MODE" in
    add|replace|update|remove|clean|status)
        # Valid modes
        ;;
    *)
        log_error "Invalid mode: $OPERATION_MODE"
        log_error "Valid modes: add, replace, update, remove, clean, status"
        exit 1
        ;;
esac

# Parse server/dataset arguments (not required for clean/status modes)
NFS_SERVER_HOST="${1:-}"
NFS_SERVER_BASE="${2:-}"
shift 2 2>/dev/null || true
declare -a NFS_SERVER_DATASETS=("$@")
declare -a FSTAB_ENTRIES=()
declare -a AUTOMOUNT_UNITS=()

# NFS mount options optimized for performance and reliability
#
# Notes:
# - `x-systemd.automount` ensures mounts happen on-demand.
# - `nofail` prevents boot from being held hostage by unreachable servers.
# - `x-systemd.mount-timeout` / `x-systemd.device-timeout` reduce worst-case hangs.
readonly NFS_OPTIONS="nfs4 rw,async,rsize=65536,wsize=65536,proto=tcp,vers=4.1,noatime,actimeo=10,cto,soft,timeo=60,retrans=3,acregmin=0,acregmax=0,acdirmin=0,acdirmax=0,lookupcache=positive,nofail,x-systemd.automount,x-systemd.idle-timeout=60,x-systemd.mount-timeout=5s,x-systemd.device-timeout=5s,_netdev 0 0"

# Logging functions
check_privileges() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root. Use sudo when needed."
        exit 1
    fi
    
    if ! sudo -n true 2>/dev/null; then
        log_error "This script requires sudo privileges. Please run with sudo access."
        exit 1
    fi
}

# Function to check if NFS utilities are installed
check_dependencies() {
    local missing_deps=()
    
    for cmd in mount.nfs4 systemctl; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_error "Please install nfs-utils and systemd"
        exit 1
    fi
}

# Function to check if the NFS server is reachable
check_nfs_server() {
    log_info "Checking NFS server connectivity..."
    
    if ! ping -c 1 -W 5 "$NFS_SERVER_HOST" &> /dev/null; then
        log_error "Cannot reach NFS server: $NFS_SERVER_HOST"
        log_error "Please check network connectivity and server availability"
        exit 1
    fi

    log_info "Checking NFS server exports..."
    
    if ! showmount -e "$NFS_SERVER_HOST" &> /dev/null; then
        log_error "No NFS exports found on server: $NFS_SERVER_HOST"
        log_error "Please verify NFS server configuration and exports"
        exit 1
    fi
    
    log_success "NFS server $NFS_SERVER_HOST is reachable"
}

# Function to check if specific NFS entry exists in fstab
check_fstab_entry() {
    local nfs_path="$1"
    local mount_point="$2"
    
    if grep -q "^${nfs_path}[[:space:]]\+${mount_point}[[:space:]]" "$FSTAB"; then
        return 0
    else
        return 1
    fi
}

# Function to check if managed section exists
has_managed_section() {
    grep -q "^${MANAGED_SECTION_BEGIN}" "$FSTAB" 2>/dev/null
}

# Function to extract managed section from fstab
get_managed_section() {
    if ! has_managed_section; then
        return 0
    fi
    
    sed -n "/^${MANAGED_SECTION_BEGIN}/,/^${MANAGED_SECTION_END}/p" "$FSTAB"
}

# Function to extract managed entries (without markers/comments)
get_managed_entries() {
    if ! has_managed_section; then
        return 0
    fi
    
    get_managed_section | grep -v "^#" | grep -v "^[[:space:]]*$" || true
}

# Function to parse an fstab entry into components
parse_fstab_entry() {
    local entry="$1"
    local nfs_path mount_point
    
    nfs_path=$(echo "$entry" | awk '{print $1}')
    mount_point=$(echo "$entry" | awk '{print $2}')
    
    echo "${nfs_path}|${mount_point}"
}

# Function to get all mount points from managed entries
get_managed_mount_points() {
    get_managed_entries | awk '{print $2}' || true
}

# Function to get all NFS paths from managed entries
get_managed_nfs_paths() {
    get_managed_entries | awk '{print $1}' || true
}

# Function to detect conflicts in new entries
detect_conflicts() {
    local -a conflicts=()
    local existing_mount_points existing_nfs_paths
    
    existing_mount_points=$(get_managed_mount_points)
    existing_nfs_paths=$(get_managed_nfs_paths)
    
    for new_entry in "${FSTAB_ENTRIES[@]}"; do
        local parsed new_nfs_path new_mount_point
        parsed=$(parse_fstab_entry "$new_entry")
        new_nfs_path="${parsed%%|*}"
        new_mount_point="${parsed#*|}"
        
        # Check for mount point conflicts
        while IFS= read -r existing_mp; do
            if [[ "$new_mount_point" == "$existing_mp" ]]; then
                # Check if it's the exact same entry
                local matching_entry
                matching_entry=$(get_managed_entries | grep "[[:space:]]${existing_mp}[[:space:]]" | awk '{print $1}')
                
                if [[ "$new_nfs_path" != "$matching_entry" ]]; then
                    conflicts+=("Mount point conflict: $new_mount_point (existing: $matching_entry, new: $new_nfs_path)")
                fi
            fi
        done <<< "$existing_mount_points"
    done
    
    if [[ ${#conflicts[@]} -gt 0 ]]; then
        for conflict in "${conflicts[@]}"; do
            log_error "CONFLICT: $conflict"
        done
        return 1
    fi
    
    return 0
}

# Function to remove managed section from fstab
remove_managed_section() {
    if ! has_managed_section; then
        log_info "No managed section found in fstab"
        return 0
    fi
    
    log_info "Removing managed section from fstab..."
    
    # Create temp file without managed section
    local temp_fstab
    temp_fstab=$(mktemp)
    
    # Copy everything except the managed section
    sed "/^${MANAGED_SECTION_BEGIN}/,/^${MANAGED_SECTION_END}/d" "$FSTAB" > "$temp_fstab"
    
    # Replace fstab atomically
    sudo cp "$temp_fstab" "$FSTAB"
    rm "$temp_fstab"
    
    log_success "Managed section removed from fstab"
}

# Function to stop and disable automount units
stop_automount_units() {
    local -a units_to_stop=("$@")
    
    if [[ ${#units_to_stop[@]} -eq 0 ]]; then
        return 0
    fi
    
    log_info "Stopping automount units..."
    
    for unit in "${units_to_stop[@]}"; do
        if systemctl is-active --quiet "$unit" 2>/dev/null; then
            log_info "Stopping $unit..."
            sudo systemctl stop "$unit" 2>/dev/null || true
        fi
        
        if systemctl is-enabled --quiet "$unit" 2>/dev/null; then
            log_info "Disabling $unit..."
            sudo systemctl disable "$unit" 2>/dev/null || true
        fi
    done
    
    log_success "Automount units stopped"
}

# Function to extract automount units from managed section
get_managed_automount_units() {
    local -a units=()
    
    while IFS= read -r mount_point; do
        if [[ -n "$mount_point" ]]; then
            local safe_name
            safe_name=$(echo "$mount_point" | sed 's|^/||' | tr '/' '-')
            units+=("${safe_name}.automount")
        fi
    done <<< "$(get_managed_mount_points)"
    
    printf "%s\n" "${units[@]}" 2>/dev/null || true
}

# Function to remove entries matching the new configuration
remove_matching_entries() {
    if ! has_managed_section; then
        log_info "No managed entries to remove"
        return 0
    fi
    
    log_info "Removing matching entries from managed section..."
    
    local temp_fstab temp_section
    temp_fstab=$(mktemp)
    temp_section=$(mktemp)
    
    # Extract current managed entries
    get_managed_entries > "$temp_section"
    
    # Remove entries that match new configuration
    for new_entry in "${FSTAB_ENTRIES[@]}"; do
        local parsed new_nfs_path new_mount_point
        parsed=$(parse_fstab_entry "$new_entry")
        new_nfs_path="${parsed%%|*}"
        new_mount_point="${parsed#*|}"
        
        # Remove entries with matching NFS path OR mount point
        sed -i "\|^${new_nfs_path}[[:space:]]|d" "$temp_section"
        sed -i "\|[[:space:]]${new_mount_point}[[:space:]]|d" "$temp_section"
    done
    
    # Rebuild fstab
    # Copy everything before managed section
    sed "/^${MANAGED_SECTION_BEGIN}/,/^${MANAGED_SECTION_END}/d" "$FSTAB" > "$temp_fstab"
    
    # Add managed section if there are remaining entries
    if [[ -s "$temp_section" ]]; then
        {
            echo "$MANAGED_SECTION_BEGIN"
            echo "# Last updated: $(date '+%Y-%m-%d %H:%M:%S')"
            cat "$temp_section"
            echo "$MANAGED_SECTION_END"
        } >> "$temp_fstab"
    fi
    
    # Replace fstab atomically
    sudo cp "$temp_fstab" "$FSTAB"
    rm "$temp_fstab" "$temp_section"
    
    log_success "Matching entries removed"
}

# Function to create mount point directories
create_mount_points() {
    log_info "Creating mount point directories..."
    
    for entry in "${FSTAB_ENTRIES[@]}"; do
        local mount_point
        mount_point=$(echo "$entry" | awk '{print $2}')
        
        if [[ ! -d "$mount_point" ]]; then
            sudo mkdir -p "$mount_point"
            log_success "Created mount point: $mount_point"
        else
            log_info "Mount point already exists: $mount_point"
        fi
    done
}

# Function to backup fstab
backup_fstab() {
    local backup_file
    backup_file="/etc/fstab.backup.$(date +%Y%m%d_%H%M%S)"
    log_info "Creating fstab backup: $backup_file"
    sudo cp "$FSTAB" "$backup_file"
    log_success "Fstab backed up successfully"
}

# Function to parse dataset:mountpoint syntax
parse_dataset_entry() {
    local entry="$1"
    local dataset mount_name
    
    if [[ "$entry" == *":"* ]]; then
        # Custom mount point specified (dataset:mountpoint)
        dataset="${entry%%:*}"
        mount_name="${entry#*:}"
    else
        # Auto-generate mount point from dataset name
        dataset="$entry"
        mount_name=$(echo "$dataset" | tr '/' '-' | sed 's/[^a-zA-Z0-9-]//g')
    fi
    
    # Return both values via echo (caller will capture)
    echo "$dataset|$mount_name"
}

# Function to generate fstab entries and automount units
generate_entries() {
    log_info "Processing ${#NFS_SERVER_DATASETS[@]} dataset(s)..."
    
    for entry in "${NFS_SERVER_DATASETS[@]}"; do
        local parsed dataset mount_name safe_mount_name
        
        # Parse the entry to get dataset and mount point
        parsed=$(parse_dataset_entry "$entry")
        dataset="${parsed%%|*}"
        mount_name="${parsed#*|}"
        
        # Ensure mount name is safe for systemd unit names
        safe_mount_name=$(echo "$mount_name" | tr '/' '-' | sed 's/[^a-zA-Z0-9-]//g')
        
        log_info "Dataset: $dataset -> Mount point: /mnt/$safe_mount_name"
        
        FSTAB_ENTRIES+=("$NFS_SERVER_HOST:$NFS_SERVER_BASE/$dataset $MOUNT_POINT/$safe_mount_name $NFS_OPTIONS")
        AUTOMOUNT_UNITS+=("mnt-${safe_mount_name}.automount")
    done
    
    log_info "Generated ${#FSTAB_ENTRIES[@]} fstab entry/entries"
}

# Function to add NFS entries to managed section in fstab
add_fstab_entries() {
    backup_fstab
    
    log_info "Managing NFS entries in $FSTAB (mode: $OPERATION_MODE)..."
    log_info "Total entries to process: ${#FSTAB_ENTRIES[@]}"
    
    local temp_fstab temp_section
    temp_fstab=$(mktemp)
    temp_section=$(mktemp)
    
    # Handle different operation modes
    case "$OPERATION_MODE" in
        add)
            # ADD mode: Keep existing managed entries, add new ones (skip duplicates)
            log_info "ADD mode: Merging with existing entries..."
            
            # Start with existing managed entries
            get_managed_entries > "$temp_section" || true
            
            # Add new entries if they don't already exist
            for entry in "${FSTAB_ENTRIES[@]}"; do
                local parsed nfs_path mount_point
                parsed=$(parse_fstab_entry "$entry")
                nfs_path="${parsed%%|*}"
                mount_point="${parsed#*|}"
                
                # Check if this exact entry already exists
                if grep -q "^${nfs_path}[[:space:]].*[[:space:]]${mount_point}[[:space:]]" "$temp_section" 2>/dev/null; then
                    log_info "Entry already exists: $nfs_path -> $mount_point"
                else
                    log_info "Adding new entry: $nfs_path -> $mount_point"
                    echo "$entry" >> "$temp_section"
                fi
            done
            ;;
            
        replace)
            # REPLACE mode: Discard all existing, use only new entries
            log_info "REPLACE mode: Removing all existing entries..."
            
            # Stop all existing automount units first
            local -a existing_units
            mapfile -t existing_units < <(get_managed_automount_units)
            stop_automount_units "${existing_units[@]}"
            
            # Use only new entries
            printf "%s\n" "${FSTAB_ENTRIES[@]}" > "$temp_section"
            ;;
            
        update)
            # UPDATE mode: Smart merge - remove conflicts, keep non-conflicting
            log_info "UPDATE mode: Smart merge with conflict resolution..."
            
            # Start with existing entries
            get_managed_entries > "$temp_section" || true
            
            # Remove entries that conflict with new configuration
            for new_entry in "${FSTAB_ENTRIES[@]}"; do
                local parsed new_nfs_path new_mount_point
                parsed=$(parse_fstab_entry "$new_entry")
                new_nfs_path="${parsed%%|*}"
                new_mount_point="${parsed#*|}"
                
                # Remove any existing entries with same mount point OR same NFS path
                sed -i "\|^${new_nfs_path}[[:space:]]|d" "$temp_section" 2>/dev/null || true
                sed -i "\|[[:space:]]${new_mount_point}[[:space:]]|d" "$temp_section" 2>/dev/null || true
            done
            
            # Add all new entries
            printf "%s\n" "${FSTAB_ENTRIES[@]}" >> "$temp_section"
            ;;
            
        remove)
            # REMOVE mode: handled by remove_matching_entries, this shouldn't be called
            log_error "Internal error: add_fstab_entries called in remove mode"
            return 1
            ;;
            
        *)
            log_error "Unknown operation mode: $OPERATION_MODE"
            return 1
            ;;
    esac
    
    # Rebuild fstab with managed section
    # Copy everything except old managed section
    sed "/^${MANAGED_SECTION_BEGIN}/,/^${MANAGED_SECTION_END}/d" "$FSTAB" > "$temp_fstab"
    
    # Add new managed section
    {
        echo "$MANAGED_SECTION_BEGIN"
        echo "# Last updated: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "# Mode: $OPERATION_MODE"
        echo "# Command: nfs.sh --mode $OPERATION_MODE $NFS_SERVER_HOST $NFS_SERVER_BASE ${NFS_SERVER_DATASETS[*]}"
        cat "$temp_section"
        echo "$MANAGED_SECTION_END"
    } >> "$temp_fstab"
    
    # Replace fstab atomically
    sudo cp "$temp_fstab" "$FSTAB"
    rm "$temp_fstab" "$temp_section"
    
    log_info "Reloading systemd daemon..."
    sudo systemctl daemon-reload
    
    log_success "Fstab updated successfully"
}

# Function to manage automount units
manage_automount() {
    local unit="$1"
    
    log_info "Managing automount unit: $unit"
    
    if systemctl is-active --quiet "$unit"; then
        log_info "$unit is already active"
        return 0
    fi
    
    if systemctl is-enabled --quiet "$unit" 2>/dev/null; then
        log_info "$unit is enabled, starting..."
    else
        log_info "Enabling $unit..."
        sudo systemctl enable "$unit"
    fi
    
    log_info "Starting $unit..."
    if sudo systemctl start "$unit"; then
        log_success "$unit started successfully"
    else
        log_error "Failed to start $unit"
        return 1
    fi
}

# Function to manage all automount units
manage_all_automounts() {
    log_info "Managing automount units..."
    
    local failed_units=()
    
    for unit in "${AUTOMOUNT_UNITS[@]}"; do
        if ! manage_automount "$unit"; then
            failed_units+=("$unit")
        fi
    done
    
    if [[ ${#failed_units[@]} -gt 0 ]]; then
        log_error "Failed to start the following units: ${failed_units[*]}"
        exit 1
    fi
    
    log_success "All automount units are active"
}

# Function to test mounts
test_mounts() {
    log_info "Testing NFS mounts..."
    
    local failed_mounts=()
    
    for entry in "${FSTAB_ENTRIES[@]}"; do
        local mount_point
        mount_point=$(echo "$entry" | awk '{print $2}')
        
        log_info "Testing access to: $mount_point"
        
        if timeout 10 ls "$mount_point" &> /dev/null; then
            log_success "Mount test successful: $mount_point"
        else
            log_error "Mount test failed: $mount_point"
            failed_mounts+=("$mount_point")
        fi
    done
    
    if [[ ${#failed_mounts[@]} -gt 0 ]]; then
        log_error "Failed to access the following mounts: ${failed_mounts[*]}"
        log_error "Please check NFS server configuration and network connectivity"
        return 1
    fi
    
    log_success "All mount tests passed"
}

# Function to show status
show_status() {
    log_info "Current NFS mount status:"
    echo
    
    if [[ ${#AUTOMOUNT_UNITS[@]} -gt 0 ]]; then
        for unit in "${AUTOMOUNT_UNITS[@]}"; do
            printf "%-30s: " "$unit"
            if systemctl is-active --quiet "$unit" 2>/dev/null; then
                echo "ACTIVE"
            else
                echo "INACTIVE"
            fi
        done
    else
        log_info "No automount units configured"
    fi
    
    echo
    log_info "Current mounts:"
    mount | grep nfs4 | grep "$MOUNT_POINT" 2>/dev/null || log_info "No NFS mounts currently active"
}

# Function to show detailed managed configuration
show_managed_status() {
    log_info "=== NFS Automount Managed Configuration ==="
    echo
    
    if ! has_managed_section; then
        log_info "No managed configuration found."
        log_info "Run with --mode add to create your first configuration."
        return 0
    fi
    
    log_info "Managed Section in $FSTAB:"
    echo "----------------------------------------"
    get_managed_section | sed 's/^/  /'
    echo "----------------------------------------"
    echo
    
    log_info "Parsed Entries:"
    local entry_num=0
    while IFS= read -r entry; do
        if [[ -n "$entry" ]]; then
            entry_num=$((entry_num + 1))
            local parsed nfs_path mount_point
            parsed=$(parse_fstab_entry "$entry")
            nfs_path="${parsed%%|*}"
            mount_point="${parsed#*|}"
            
            printf "  %d. %s -> %s\n" "$entry_num" "$nfs_path" "$mount_point"
        fi
    done <<< "$(get_managed_entries)"
    
    if [[ $entry_num -eq 0 ]]; then
        log_info "  (No entries found)"
    fi
    
    echo
    log_info "Automount Unit Status:"
    
    local -a units
    mapfile -t units < <(get_managed_automount_units)
    
    if [[ ${#units[@]} -eq 0 ]]; then
        log_info "  No automount units configured"
    else
        for unit in "${units[@]}"; do
            local status="UNKNOWN"
            if systemctl is-active --quiet "$unit" 2>/dev/null; then
                status="ACTIVE"
            elif systemctl is-enabled --quiet "$unit" 2>/dev/null; then
                status="ENABLED (not started)"
            else
                status="INACTIVE"
            fi
            printf "  %-40s: %s\n" "$unit" "$status"
        done
    fi
    
    echo
    log_info "Currently Mounted:"
    if mount | grep nfs4 | grep "$MOUNT_POINT" > /dev/null 2>&1; then
        mount | grep nfs4 | grep "$MOUNT_POINT" | while IFS= read -r mount_line; do
            echo "  $mount_line"
        done
    else
        log_info "  (No NFS mounts currently active)"
    fi
}

# Main function
main() {
    # Handle status and clean modes (don't require server/dataset args)
    if [[ "$OPERATION_MODE" == "status" ]]; then
        show_managed_status
        exit 0
    fi
    
    if [[ "$OPERATION_MODE" == "clean" ]]; then
        log_info "Starting cleanup of all managed NFS entries..."
        
        check_privileges
        check_dependencies
        
        if ! has_managed_section; then
            log_info "No managed configuration found. Nothing to clean."
            exit 0
        fi
        
        # Stop all managed automount units
        log_info "Stopping all managed automount units..."
        local -a units
        mapfile -t units < <(get_managed_automount_units)
        stop_automount_units "${units[@]}"
        
        # Remove managed section
        backup_fstab
        remove_managed_section
        
        sudo systemctl daemon-reload
        
        log_success "All managed NFS entries have been removed"
        exit 0
    fi
    
    # All other modes require server and dataset arguments
    if [[ -z "$NFS_SERVER_HOST" ]] || [[ -z "$NFS_SERVER_BASE" ]] || [[ ${#NFS_SERVER_DATASETS[@]} -eq 0 ]]; then
        log_error "Missing required arguments for mode: $OPERATION_MODE"
        log_error ""
        log_error "Usage: $0 [--mode MODE] <host> <base_path> <dataset1[:mountpoint1]> [dataset2[:mountpoint2] ...]"
        log_error ""
        log_error "Modes:"
        log_error "  add      (default) Skip existing entries, add only new ones"
        log_error "  replace  Remove ALL managed entries, add new configuration"
        log_error "  update   Smart merge: remove conflicts, add new, keep non-conflicting"
        log_error "  remove   Remove only entries matching the provided configuration"
        log_error "  clean    Remove all managed entries (no args needed)"
        log_error "  status   Show current managed configuration (no args needed)"
        log_error ""
        log_error "Examples:"
        log_error "  $0 server.local /nfs/root data backup"
        log_error "  $0 --mode replace server.local /nfs/root data:dragonnet"
        log_error "  $0 --mode update server.local /nfs/root data:newname common"
        log_error "  $0 --mode remove server.local /nfs/root data"
        log_error "  $0 --mode clean"
        log_error "  $0 --mode status"
        exit 1
    fi
    
    log_info "Starting NFS systemd automount configuration..."
    log_info "Mode: $OPERATION_MODE"
    log_info "Server: $NFS_SERVER_HOST"
    log_info "Base path: $NFS_SERVER_BASE"
    log_info "Datasets: ${NFS_SERVER_DATASETS[*]}"
    echo
    
    # Generate dynamic fstab entries and automount units
    generate_entries
    echo
    
    # Pre-flight checks
    check_privileges
    check_dependencies
    
    # Only check NFS server for non-remove modes
    if [[ "$OPERATION_MODE" != "remove" ]]; then
        check_nfs_server
    fi
    
    # Handle REMOVE mode specially
    if [[ "$OPERATION_MODE" == "remove" ]]; then
        log_info "REMOVE mode: Removing matching entries..."
        
        if ! has_managed_section; then
            log_info "No managed configuration found. Nothing to remove."
            exit 0
        fi
        
        # Stop matching automount units
        stop_automount_units "${AUTOMOUNT_UNITS[@]}"
        
        # Remove matching entries
        backup_fstab
        remove_matching_entries
        
        sudo systemctl daemon-reload
        
        log_success "Matching NFS entries have been removed"
        show_managed_status
        exit 0
    fi
    
    # For add/replace/update modes, detect conflicts in update mode
    if [[ "$OPERATION_MODE" == "update" ]]; then
        log_info "Checking for conflicts..."
        # Note: conflicts are resolved automatically in update mode, just informational
        if ! detect_conflicts; then
            log_info "Conflicts detected - will be resolved during update"
        fi
    fi
    
    # For add mode, check for conflicts and abort if found
    if [[ "$OPERATION_MODE" == "add" ]]; then
        if ! detect_conflicts; then
            log_error "Cannot proceed with ADD mode due to conflicts"
            log_error "Use --mode update to resolve conflicts automatically"
            log_error "Or use --mode replace to completely replace the configuration"
            exit 1
        fi
    fi
    
    # Setup
    create_mount_points
    add_fstab_entries
    manage_all_automounts
    
    # Test and status
    echo
    if test_mounts; then
        echo
        show_status
        echo
        log_success "NFS automount configuration completed successfully!"
        log_info "Run '$0 --mode status' to view detailed configuration anytime"
    else
        log_error "Configuration completed but mount tests failed"
        echo
        show_status
        exit 1
    fi
}

# Run main function
main "$@"
