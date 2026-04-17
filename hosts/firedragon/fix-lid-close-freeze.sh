#!/usr/bin/env bash
# Retired legacy helper.

set -euo pipefail

printf '%s\n' "hosts/firedragon/fix-lid-close-freeze.sh is retired."
printf '%s\n' "Its mutation surface is now owned by infra/ansible/roles/amd_gpu, infra/ansible/roles/asus_laptop, infra/ansible/roles/tlp, and infra/ansible/roles/hibernation."
printf '%s\n' "Use the Ansible control plane, then run tests/vm/proxmox-validation/firedragon-suspend-verify.sh for read-only validation."
exit 1
