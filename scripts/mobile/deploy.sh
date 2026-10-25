#!/usr/bin/env bash
# Reserved entry point. Use validate.sh --render-only for isolated rendering.
set -euo pipefail

# Refuse all operations until the real staging-only planner replaces this scaffold.
echo "Deployment disabled: approved-revision checks, target verification and scoped apply are not implemented." >&2
exit 1
