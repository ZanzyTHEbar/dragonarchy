#!/usr/bin/env bash
# Retired legacy helper.

set -euo pipefail

printf '%s\n' "hosts/firedragon/fix-acpi-boot.sh is retired."
printf '%s\n' "ACPI boot parameters are now owned by infra/ansible/roles/asus_laptop."
printf '%s\n' "Use the Ansible control plane and tests/vm/proxmox-validation/firedragon-suspend-verify.sh instead."
exit 1
