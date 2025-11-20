# Dragon Host - Audio Configuration

This directory contains **host-specific** audio configurations for the dragon workstation.

## Hardware

- **Audio Interface**: Audient iD22 (14-channel professional interface)
- **Connection**: USB
- **Purpose**: Desktop audio + professional audio work

## Configuration Files

### `20-stereo-audient.conf`
Creates a stereo proxy sink for simplified desktop audio routing:
- **Virtual Sink**: `audient-stereo-proxy`
- **Target**: Audient iD22 Front-Left/Front-Right channels
- **Purpose**: Simplifies audio routing for games, browsers, desktop apps

### `90-audient-defaults.conf`
Sets default audio devices:
- **Default Sink**: `audient-stereo-proxy`
- **Default Source**: Audient iD22 microphone input

## Installation

These configs are automatically installed during dragon host setup:

```bash
cd ~/dotfiles
./install.sh --host dragon
```

The setup script:
1. Detects if Audient iD22 is connected
2. Copies configs to `~/.config/pipewire/pipewire.conf.d/`
3. Restarts PipeWire services
4. Verifies proxy creation and routing

## Why Host-Specific?

The Audient iD22 is:
- ✅ Permanently installed on dragon workstation
- ❌ NOT available on other hosts (firedragon laptop, etc.)

Making this host-specific ensures:
- Other hosts don't try to route to non-existent hardware
- Laptop can use built-in audio or different interfaces
- Each host has appropriate audio configuration

## Usage on Other Hosts

If you want to use the Audient iD22 on another host (e.g., firedragon laptop when docked):

### Option 1: Manual Temporary Setup
```bash
# Copy configs when iD22 is connected
cp ~/dotfiles/hosts/dragon/pipewire/*.conf ~/.config/pipewire/pipewire.conf.d/
systemctl --user restart pipewire
```

### Option 2: Create Conditional Setup
Add to that host's `setup.sh`:
```bash
# Only setup if iD22 is connected
if pactl list cards | grep -q "Audient_iD22"; then
    log_info "Audient iD22 detected, configuring audio..."
    # Copy configs
fi
```

## Adapting for Different Interfaces

To use a different audio interface on this host:

1. **Find device name**:
   ```bash
   pactl list sinks short
   ```

2. **Edit `20-stereo-audient.conf`**:
   - Update `node.target` to your device
   - Rename file to match (e.g., `20-stereo-focusrite.conf`)

3. **Edit `90-audient-defaults.conf`**:
   - Update sink/source names

4. **Re-run setup**:
   ```bash
   cd ~/dotfiles/hosts/dragon && ./setup.sh --reset
   ```

## Technical Details

### Stereo Proxy Architecture
```
Applications → audient-stereo-proxy → Loopback Module → iD22 FL/FR → Speakers
```

### Benefits
- Desktop apps see simple stereo output
- Prevents 14-channel confusion
- Gaming "just works" without per-game audio config
- Professional tools can still access all 14 channels directly

## Related Documentation

- **Main Audio Guide**: [`../../docs/AUDIO_CONFIGURATION.md`](../../docs/AUDIO_CONFIGURATION.md)
- **Dragon Setup Script**: [`../setup.sh`](../setup.sh)
- **Audio Setup Utility**: [`../../scripts/utilities/audio-setup.sh`](../../scripts/utilities/audio-setup.sh)

