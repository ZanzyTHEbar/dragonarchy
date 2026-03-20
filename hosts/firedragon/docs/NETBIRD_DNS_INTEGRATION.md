# NetBird VPN + Custom DNS - Added to FireDragon

## What Was Added

NetBird VPN and custom DNS configuration from dragon have been integrated into firedragon for consistent networking across both hosts.

## Changes Made

### 1. Updated `firedragon/setup.sh`

The `setup_networking()` function already had the NetBird installation, but I clarified the log messages:

```bash
# Install NetBird for secure networking
log_info "Installing NetBird VPN..."
bash "$HOME/dotfiles/scripts/utilities/netbird-install.sh"

# Copy host-specific system configs (DNS)
log_info "Copying host-specific system configs (DNS)..."
sudo cp -rT "$HOME/dotfiles/hosts/firedragon/etc/" /etc/

# Apply DNS changes
log_info "Restarting systemd-resolved to apply DNS changes..."
sudo systemctl restart systemd-resolved

log_success "Networking configured (NetBird VPN + Custom DNS)"
```

### 2. Updated DNS Configuration

**`firedragon/etc/systemd/resolved.conf.d/dns.conf`**

```ini
[Resolve]
DNS=192.168.0.218 1.1.1.1 8.8.8.8
```

**What this does:**
- Prefers the home DNS server first
- Keeps public resolvers available in the same ordered list
- Avoids hard-pinning all lookups to the home network when the laptop is away

### 3. Added a NetworkManager DNS Dispatcher on FireDragon

**`firedragon/etc/NetworkManager/dispatcher.d/50-home-dns`**

- Watches `wlan0` for DHCP updates
- If DHCP already advertises `192.168.0.218`, it rewrites the active link DNS to:

```text
192.168.0.218 1.1.1.1 8.8.8.8
```

- Drops router DNS from the active link so local names like `pi.hole` stop flapping between the home resolver and the router
- Reverts cleanly on other networks so off-network behavior stays portable

### 4. Added NetBird Aliases

**Both `firedragon.zsh` and `dragon.zsh` now have:**

```bash
# NetBird VPN aliases
alias netbird-status='netbird status'
alias netbird-up='netbird up'
alias netbird-down='netbird down'
alias netbird-list='netbird list'
alias nb='netbird status'  # Quick status check
```

## Networking Configuration - Both Hosts

### Custom DNS Server

Both hosts now prefer the same DNS order:

```ini
DNS=192.168.0.218 1.1.1.1 8.8.8.8
```

FireDragon additionally uses a NetworkManager dispatcher to strip router DNS from `wlan0` when the home resolver is already being advertised by DHCP.

### NetBird VPN

NetBird provides secure mesh networking between devices:
- Zero-configuration VPN mesh
- Peer-to-peer connections when possible
- Encrypted communication
- Easy device management

## Usage

### NetBird Commands

After setup, use these aliases on both hosts:

```bash
nb                  # Quick status check
netbird-status      # Show NetBird connection status
netbird-up          # Connect to NetBird network
netbird-down        # Disconnect from NetBird network
netbird-list        # List all devices in network
```

### Check DNS Configuration

```bash
# View current DNS settings
resolvectl status

# Test DNS resolution
dig google.com
nslookup google.com

# Check which DNS server is being used
resolvectl query google.com
```

## Installation

### On FireDragon:

If you've already run the firedragon setup:

```bash
# Just apply the DNS change
sudo cp ~/dotfiles/hosts/firedragon/etc/systemd/resolved.conf.d/dns.conf /etc/systemd/resolved.conf.d/
sudo install -m 755 ~/dotfiles/hosts/firedragon/etc/NetworkManager/dispatcher.d/50-home-dns /etc/NetworkManager/dispatcher.d/50-home-dns
sudo systemctl restart systemd-resolved
nmcli connection reload
nmcli device reapply wlan0

# Source updated zsh config
source ~/.config/zsh/functions/firedragon.zsh

# Or open new terminal
```

If running fresh setup:

```bash
cd ~/dotfiles
bash hosts/firedragon/setup.sh
# NetBird and DNS will be configured automatically
```

### On Dragon:

```bash
cd ~/dotfiles
bash hosts/dragon/setup.sh
# NetBird and DNS are already part of the setup
```

## Verification

### Verify DNS is Working

```bash
# Check resolved status
resolvectl status

# Confirm wlan0 did not keep the router DNS
nmcli device show wlan0

# Verify local names resolve through resolved
resolvectl query pi.hole

# Verify the home DNS server answers directly
dig @192.168.0.218 pi.hole
```

### Verify NetBird is Connected

```bash
nb  # or netbird-status

# Should show:
# Management: Connected
# Signal: Connected
# Relays: Connected (if needed)
# NetBird IP: 100.x.x.x
```

### Test Connectivity

```bash
# From firedragon, ping dragon (if both on NetBird):
ping dragon.netbird  # Or use NetBird IP

# Check DNS resolution
dig @192.168.0.218 google.com
```

### Vivaldi Sync Triage After DNS Is Stable

If websites and `pi.hole` resolve correctly but Vivaldi still refuses to sign in or Sync shows retries, inspect:

```text
vivaldi://sync-internals
vivaldi://settings/sync/
```

Repeated `HTTP error (500)` entries there usually indicate a Vivaldi sync backend issue rather than a local DNS failure.

## Benefits

### Unified Networking

Both hosts now have:
- ✅ Same custom DNS configuration
- ✅ NetBird VPN for secure mesh networking
- ✅ Consistent command aliases
- ✅ Easy device-to-device communication

### Use Cases

**Custom DNS (192.168.0.218):**
- Ad blocking (if configured on DNS server)
- Local network name resolution
- Custom domain handling
- Privacy (no ISP DNS tracking)

**NetBird VPN:**
- Secure access to dragon from firedragon (and vice versa)
- Access home network while traveling (firedragon)
- Encrypted peer-to-peer communication
- No port forwarding needed

## Network Topology

```
Internet
    ↓
[Custom DNS: 192.168.0.218]
    ↓
    ├─── Dragon (Desktop)
    │    - Static/wired connection
    │    - NetBird client
    │    - AMD workstation GPU
    │
    └─── FireDragon (Laptop)
         - WiFi connection
         - NetBird client
         - AMD mobile GPU
         - Mobile access via NetBird when away
```

## Configuration Files

### FireDragon
```
hosts/firedragon/
├── setup.sh                                        ← Installs NetBird + DNS
├── etc/systemd/resolved.conf.d/dns.conf            ← DNS config (updated)
└── .config/zsh/functions/firedragon.zsh            ← NetBird aliases (stowed)
```

### Dragon
```
hosts/dragon/
├── setup.sh                                    ← Installs NetBird + DNS
├── etc/systemd/resolved.conf.d/dns.conf        ← DNS config (existing)
└── dragon.zsh                                  ← NetBird aliases (added)
```

## Troubleshooting

### DNS Not Working

```bash
# Check resolved status
systemctl status systemd-resolved

# Check DNS config
cat /etc/systemd/resolved.conf.d/dns.conf

# Check what NetworkManager handed wlan0
nmcli device show wlan0

# Check resolved path for a local name
resolvectl query pi.hole

# Restart resolved
sudo systemctl restart systemd-resolved

# Reload NetworkManager connections and reapply the active Wi-Fi profile
nmcli connection reload
nmcli device reapply wlan0

# Test DNS
dig @192.168.0.218 pi.hole
```

### NetBird Not Connecting

```bash
# Check NetBird status
netbird-status

# Check NetBird service
systemctl status netbird

# View NetBird logs
journalctl -u netbird -f

# Restart NetBird
sudo systemctl restart netbird
```

### Can't Reach Custom DNS Server

```bash
# Ping DNS server
ping 192.168.0.218

# Check if on correct network
ip route
```

## Summary

✅ **FireDragon now has:**
- NetBird VPN (already had, clarified in setup)
- Home-first DNS with public fallback
- A NetworkManager dispatcher that strips router DNS on home Wi-Fi
- NetBird command aliases (added)

✅ **Dragon now has:**
- NetBird command aliases (added)
- Home-first DNS with public fallback

Both hosts now have **consistent networking configuration** for secure communication and custom DNS resolution! 🌐

