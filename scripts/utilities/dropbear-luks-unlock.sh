#!/bin/bash
#
# Dropbear & Netbird Initramfs Setup for Remote LUKS Unlock
#
# This script configures a Debian-based system to allow remote unlocking
# of LUKS-encrypted partitions via SSH over a Netbird VPN.
# It installs Dropbear SSH into the initramfs and configures Netbird
# to connect before the LUKS passphrase prompt.

set -euo pipefail

# --- Header and Logging ---
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "\n${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# --- Functions ---

check_privileges() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root or with sudo."
        exit 1
    fi
}

check_dependencies() {
    log_info "Checking for required dependencies..."
    local missing_deps=()
    local deps=("dropbear-initramfs" "netbird" "gum")

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            # Special case for dropbear-initramfs which doesn't have a binary in PATH
            if [[ "$dep" == "dropbear-initramfs" ]] && [[ ! -f /etc/init.d/dropbear ]]; then
                 missing_deps+=("dropbear-initramfs (package)")
            elif [[ "$dep" != "dropbear-initramfs" ]]; then
                missing_deps+=("$dep")
            fi
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_info "Please install them first. On Debian/Ubuntu: sudo apt install dropbear-initramfs netbird gum"
        exit 1
    fi

    if [[ ! -f /etc/debian_version ]]; then
        log_warning "This script is designed for Debian-based systems. Your mileage may vary."
    fi

    log_success "All dependencies are satisfied."
}

select_public_key() {
    log_info "Select the SSH public key for remote unlocking."
    
    local ssh_dir="$HOME/.ssh"
    # If run with sudo, $HOME might be /root. Check user's home dir.
    if [[ -n "${SUDO_USER}" ]]; then
        ssh_dir=$(eval echo ~${SUDO_USER})/.ssh
    fi

    local pub_keys=("$ssh_dir"/*.pub)

    if [[ ! -f "${pub_keys[0]}" ]]; then
        log_error "No SSH public keys found in $ssh_dir"
        log_info "Please generate an SSH key pair first."
        exit 1
    fi

    selected_key_path=$(gum choose "${pub_keys[@]}")
    if [[ -z "$selected_key_path" ]]; then
        log_error "No key selected. Exiting."
        exit 1
    fi
    
    selected_key=$(cat "$selected_key_path")
    log_success "Using public key from: $selected_key_path"
}

configure_dropbear() {
    log_info "Configuring Dropbear..."
    
    # Add public key to authorized_keys
    local authorized_keys_file="/etc/dropbear/initramfs/authorized_keys"
    mkdir -p "$(dirname "$authorized_keys_file")"
    
    if grep -qF "$selected_key" "$authorized_keys_file" &>/dev/null; then
        log_warning "Key already exists in $authorized_keys_file. Skipping."
    else
        echo "$selected_key" >> "$authorized_keys_file"
        log_success "Added public key to Dropbear authorized_keys."
    fi
    
    chmod 600 "$authorized_keys_file"

    # Configure Dropbear options
    local dropbear_config="/etc/dropbear/initramfs/dropbear.conf"
    if ! grep -q "DROPBEAR_OPTIONS" "$dropbear_config"; then
        echo 'DROPBEAR_OPTIONS="-I 180 -j -k -p 2222 -s"' >> "$dropbear_config"
        log_success "Set default Dropbear options in $dropbear_config."
        log_warning "Default port set to 2222. Adjust if needed."
    else
        log_info "Dropbear options already configured."
    fi
}

configure_netbird_initramfs() {
    log_info "Configuring Netbird for initramfs..."

    read -p "Please enter your Netbird Setup Key (press Enter to skip if already configured): " netbird_setup_key
    
    # Create initramfs hook for Netbird
    local hook_file="/etc/initramfs-tools/hooks/netbird_luks_unlock"
    log_info "Creating initramfs hook: $hook_file"
    
    cat > "$hook_file" << 'EOF'
#!/bin/sh
set -e
PREREQ=""
prereqs() { echo "$PREREQ"; }
case "$1" in
    prereqs)
        prereqs
        exit 0
    ;;
esac

. /usr/share/initramfs-tools/hook-functions

# Copy Netbird binary and assets
copy_exec /usr/bin/netbird /bin
copy_exec /usr/bin/wg /bin
copy_exec /usr/bin/ip /bin
copy_exec /usr/bin/resolvectl /bin

# Copy Netbird configuration
mkdir -p "${DESTDIR}/etc/netbird"
if [ -f /etc/netbird/config.json ]; then
    cp /etc/netbird/config.json "${DESTDIR}/etc/netbird/"
fi
# Copy Netbird state
mkdir -p "${DESTDIR}/var/lib/netbird"
if [ -f /var/lib/netbird/config.json ]; then
    cp /var/lib/netbird/config.json "${DESTDIR}/var/lib/netbird/"
fi

# Copy DNS config
mkdir -p "${DESTDIR}/etc/"
cp /etc/resolv.conf "${DESTDIR}/etc/"

EOF

    chmod +x "$hook_file"

    # Create init-premount script to start Netbird
    local premount_script="/etc/initramfs-tools/scripts/init-premount/netbird_start"
    log_info "Creating init-premount script: $premount_script"
    
    cat > "$premount_script" << EOF
#!/bin/sh
set -e
PREREQ=""
prereqs() { echo "$PREREQ"; }
case "\$1" in
    prereqs)
        prereqs
        exit 0
    ;;
esac

echo "Starting network for remote LUKS unlock..."

# Bring up the main network interface
# This is a best guess, may need manual adjustment for your system
IFACE=\$(ip -o -4 route show to default | awk '{print \$5}' | head -n1)
if [ -z "\$IFACE" ]; then
    echo "Could not determine default network interface. Trying eth0."
    IFACE="eth0"
fi

echo "Bringing up interface \$IFACE..."
ip link set \$IFACE up
dhclient \$IFACE

echo "Waiting for network..."
sleep 5

echo "Starting Netbird..."
# Use setup key if provided, otherwise assume it's configured
if [ -f /etc/netbird_setup_key ]; then
    SETUP_KEY=\$(cat /etc/netbird_setup_key)
    /bin/netbird up --setup-key "\$SETUP_KEY" > /netbird.log 2>&1 &
else
    /bin/netbird up > /netbird.log 2>&1 &
fi

echo "Waiting for Netbird to connect..."
sleep 15 # Give Netbird time to establish connection

echo "Netbird started. You can now SSH to unlock."

EOF
    
    chmod +x "$premount_script"

    if [[ -n "$netbird_setup_key" ]]; then
        local key_file="/etc/netbird_setup_key"
        log_info "Storing Netbird setup key for initramfs."
        # This temp file will be picked up by the hook script
        echo "$netbird_setup_key" > "$key_file"
        # We need to ensure this key file gets into the initramfs
        # The easiest way is to add it to the hook itself.
        echo "echo \"$netbird_setup_key\" > \"\${DESTDIR}/etc/netbird_setup_key\"" >> "$hook_file"
        log_success "Netbird setup key configured for next boot."
    else
        log_warning "No Netbird setup key provided. Assuming device is already enrolled."
        log_warning "If connection fails, re-run this script and provide a setup key."
    fi
}

update_initramfs() {
    log_info "Updating initramfs. This may take a few moments..."
    if update-initramfs -u; then
        log_success "Initramfs updated successfully."
    else
        log_error "Failed to update initramfs. Please check the output for errors."
        exit 1
    fi
}


# --- Main Logic ---
main() {
    check_privileges
    check_dependencies
    
    select_public_key
    configure_dropbear
    configure_netbird_initramfs
    update_initramfs
    
    # Cleanup setup key file from rootfs
    if [ -f /etc/netbird_setup_key ]; then
        rm /etc/netbird_setup_key
    fi
    
    log_success "Setup complete!"
    echo
    log_info "Please reboot your machine to apply the changes."
    log_info "After reboot, you can unlock it by running:"
    log_warning "ssh root@<NETBIRD_IP> -p 2222"
    log_info "Once connected, run 'cryptroot-unlock' to enter your LUKS passphrase."
}

main "$@"
