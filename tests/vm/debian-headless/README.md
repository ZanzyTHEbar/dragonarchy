# Debian VM E2E

This directory documents the systemd-aware Debian VM smoke lane.

The actual harness lives in `scripts/ci/debian-vm-e2e.sh`.

What it verifies:

- boots a real Debian cloud image under QEMU
- waits for cloud-init and systemd
- copies the current repo into the guest over SSH
- runs `./install.sh --host headless --headless --bundle minimal --no-secrets`
- reruns the same install to verify idempotency
- runs `./scripts/install/first-run.sh --headless`
- runs `./scripts/install/validate.sh --host headless --json`

What it does not yet prove:

- Hyprland / desktop login behavior
- hardware-specific host traits
- bootloader / initramfs behavior unless `--with-system-config` is used manually
