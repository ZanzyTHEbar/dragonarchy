# Secure Boot (Limine + sbctl) — Goldendragon

This host uses the **Limine** boot loader. Secure Boot is managed with **sbctl**.

> [!IMPORTANT]
> Secure Boot key enrollment modifies UEFI variables. If you enroll the wrong keys or enable Secure Boot without signing the boot loader, the machine may not boot until you fix keys in firmware.

## Why Limine is different

Limine can verify hashes of the kernel/initramfs it boots. If you sign kernel images in-place (e.g., via `sbctl-batch-sign`), you can **change the file hash** and trip Limine’s checksum verification.

For Limine setups like CachyOS, you generally **only need to sign Limine’s EFI binary**, not the kernel images.

## One-time Setup

### 1) Reboot into firmware and enter “Setup Mode”

From a running system:

```bash
systemctl reboot --firmware-setup
```

In BIOS/UEFI, set Secure Boot to **Setup Mode** (or clear existing keys / reset to setup mode).

### 2) Run the goldendragon helper

```bash
cd ~/dotfiles/hosts/goldendragon
sudo bash ./setup-secure-boot.sh --yes
```

This will:
- Install `sbctl`
- Create custom Secure Boot keys (if missing)
- Enroll keys (`--microsoft` by default)
- Sign Limine (via `limine-enroll-config` when available, otherwise via `sbctl sign -s`)
- Run `limine-update` (or `limine-mkinitcpio`) to refresh Limine

### 3) Enable Secure Boot in firmware

Reboot back into firmware and **enable Secure Boot**.

## Verification

```bash
sbctl status
bootctl status
```

You should see Secure Boot enabled (user mode) and sbctl reporting enrolled keys.

## Troubleshooting

- **Not in Setup Mode**: If `sbctl status` shows Setup Mode is not enabled and there is no Owner GUID, reboot to firmware and clear keys / enable Setup Mode, then retry.
- **Limine updates break boot**: Ensure Limine’s EFI binary is tracked in sbctl’s database (the helper uses `sbctl sign -s` so pacman hooks can re-sign on updates).
- **Do not batch-sign kernels**: On Limine, avoid `sbctl-batch-sign` unless you know exactly how your Limine checksum configuration is handled.

