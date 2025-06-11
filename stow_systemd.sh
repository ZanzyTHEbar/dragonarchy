#!/bin/bash

# Variables
FSTAB="/etc/fstab"
MOUNT_POINT="/mnt/nfs"
NFS_SERVER="192.168.0.191:/mainpool/nfsroot"
FSTAB_ENTRY="$NFS_SERVER $MOUNT_POINT nfs4 rw,async,rsize=65536,wsize=65536,proto=tcp,vers=4.1,noatime,actimeo=60,intr,cto,soft,timeo=200,retrans=3,x-systemd.automount,x-systemd.idle-timeout=60,_netdev 0 0"
AUTOMOUNT_UNIT="mnt-nfs.automount"

# Function to check if the NFS entry exists in fstab
check_fstab_entry() {
    if grep -q "^$NFS_SERVER" "$FSTAB"; then
        echo "NFS entry found in $FSTAB."
        return 0
    else
        echo "NFS entry not found in $FSTAB."
        return 1
    fi
}

# Function to add NFS entry to fstab
add_fstab_entry() {
    echo "Adding NFS entry to $FSTAB..."
    echo "$FSTAB_ENTRY" | sudo tee -a "$FSTAB" > /dev/null
    if [ $? -eq 0 ]; then
        echo "NFS entry added successfully."
        sudo systemctl daemon-reload
    else
        echo "Failed to add NFS entry."
        exit 1
    fi
}

# Function to check and start automount service
manage_automount() {
    if systemctl is-active --quiet "$AUTOMOUNT_UNIT"; then
        echo "$AUTOMOUNT_UNIT is already active."
    else
        echo "$AUTOMOUNT_UNIT is not active. Starting it..."
        sudo systemctl start "$AUTOMOUNT_UNIT"
        if [ $? -eq 0 ]; then
            echo "$AUTOMOUNT_UNIT started successfully."
        else
            echo "Failed to start $AUTOMOUNT_UNIT."
            exit 1
        fi
    fi
}

# Main logic
echo "Checking NFS mount configuration..."

if check_fstab_entry; then
    manage_automount
else
    add_fstab_entry
    manage_automount
fi

echo "NFS mount configuration check complete."
