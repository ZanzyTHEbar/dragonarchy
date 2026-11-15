#!/bin/bash
# Compatibility refusal only: installed units are not capability declarations.
set -euo pipefail
printf '%s\n' \
  'System service activation belongs to the canonical Ansible site playbook.' \
  'Printing follows the selected package plan; Bluetooth requires a declared capability.' \
  'Docker uses the declared native service policy; network and power owners require explicit configuration.' \
  'No legacy enable/mask/stop fallback is permitted; use the managed install route.' >&2
exit 1
