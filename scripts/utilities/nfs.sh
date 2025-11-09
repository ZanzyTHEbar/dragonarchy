#!/bin/bash

# NFS Systemd Automount Configuration Script
# Dynamically configures NFS mounts with systemd automount for specified host, base path, and datasets

## Usage: ./nfs.sh <nfs_server_host> <nfs_server_base> <dataset1> [dataset2 ...]
## Example: ./nfs.sh 192.168.1.100 /mnt/nfs datasets/dataset1 datasets/dataset2
## This will configure NFS mounts for the datasets dataset1 and dataset2 on the server 192.168.1.100 at the base path /mnt/nfs
## The datasets will be mounted to /mnt/datasets/dataset1 and /mnt/datasets/dataset2 respectively
## The fstab entry will be added to /etc/fstab and the automount unit will be created and started
## The mount points will be created if they do not exist
## The fstab backup will be created before adding the entries
## The automount units will be managed and started

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Get script directory and source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091  # Runtime-resolved path to logging library
source "${SCRIPT_DIR}/../lib/logging.sh"

# Variables
readonly FSTAB="/etc/fstab"
readonly MOUNT_POINT="/mnt"
NFS_SERVER_HOST="$1"
NFS_SERVER_BASE="$2"
shift 2
declare -a NFS_SERVER_DATASETS=("$@")
declare -a FSTAB_ENTRIES=()
declare -a AUTOMOUNT_UNITS=()

# NFS mount options optimized for performance and reliability
readonly NFS_OPTIONS="nfs4 rw,async,rsize=65536,wsize=65536,proto=tcp,vers=4.1,noatime,actimeo=10,intr,cto,soft,timeo=60,retrans=3,x-systemd.automount,x-systemd.idle-timeout=60,_netdev 0 0"

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

# Function to generate fstab entries and automount units
generate_entries() {
    for dataset in "${NFS_SERVER_DATASETS[@]}"; do
        local safe_dataset
        safe_dataset=$(echo "$dataset" | tr '/' '-' | sed 's/[^a-zA-Z0-9-]//g')
        FSTAB_ENTRIES+=("$NFS_SERVER_HOST:$NFS_SERVER_BASE/$dataset $MOUNT_POINT/$safe_dataset $NFS_OPTIONS")
        AUTOMOUNT_UNITS+=("mnt-${safe_dataset}.automount")
    done
}

# Function to add NFS entries to fstab
add_fstab_entries() {
    local entries_added=0
    
    backup_fstab
    
    log_info "Checking and adding NFS entries to $FSTAB..."
    
    for entry in "${FSTAB_ENTRIES[@]}"; do
        local nfs_path mount_point
        nfs_path=$(echo "$entry" | awk '{print $1}')
        mount_point=$(echo "$entry" | awk '{print $2}')
        
        if check_fstab_entry "$nfs_path" "$mount_point"; then
            log_info "Entry already exists: $nfs_path -> $mount_point"
        else
            log_info "Adding entry: $nfs_path -> $mount_point"
            echo "$entry" | sudo tee -a "$FSTAB" > /dev/null
            ((entries_added++))
            log_success "Added NFS entry: $nfs_path -> $mount_point"
        fi
    done
    
    if [[ $entries_added -gt 0 ]]; then
        log_info "Reloading systemd daemon..."
        sudo systemctl daemon-reload
        log_success "Added $entries_added new fstab entries"
    else
        log_info "No new entries needed"
    fi
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
    
    for unit in "${AUTOMOUNT_UNITS[@]}"; do
        printf "%-30s: " "$unit"
        if systemctl is-active --quiet "$unit"; then
            echo "ACTIVE"
        else
            echo "INACTIVE"
        fi
    done
    
    echo
    log_info "Current mounts:"
    mount | grep nfs4 | grep "$MOUNT_POINT" || log_info "No NFS mounts currently active"
}

# Main function
main() {
    if [[ ${#NFS_SERVER_DATASETS[@]} -eq 0 ]]; then
        log_error "No datasets provided. Usage: $0 <host> <base_path> <dataset1> [dataset2 ...]"
        exit 1
    fi
    
    log_info "Starting NFS systemd automount configuration..."
    
    # Generate dynamic fstab entries and automount units
    generate_entries
    
    # Pre-flight checks
    check_privileges
    check_dependencies
    check_nfs_server
    
    # Setup
    create_mount_points
    add_fstab_entries
    manage_all_automounts
    
    # Test and status
    if test_mounts; then
        show_status
        log_success "NFS automount configuration completed successfully!"
    else
        log_error "Configuration completed but mount tests failed"
        show_status
        exit 1
    fi
}

# Run main function
main "$@"
