#!/usr/bin/env bash
# validate.sh — Validate mobile configuration
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

if [[ $# -gt 1 || ( $# -eq 1 && "$1" != --render-only ) ]]; then
    echo "Usage: $0 [--render-only]; full validation requires OWL_JAR from Omalauncher v0.8.1" >&2
    exit 2
fi

temp_root="${TMPDIR:-/tmp}"
[[ -d /tmp/opencode && -z "${TMPDIR:-}" ]] && temp_root=/tmp/opencode
stage="$(mktemp -d "${temp_root}/dragonarchy-mobile-check.XXXXXX")"
trap 'rm -rf -- "$stage"' EXIT
bash "${REPO_ROOT}/infra/chezmoi/bin/chezmoi-sync" \
    --host poco-x3-pro --profile mobile --source-dir "${stage}/source"

echo "PASS: manifest preflight and isolated source rendering (not a deployment)."
if [[ "${1:-}" == --render-only ]]; then
    echo "SKIPPED: OWL compilation, device previews and integration checks."
    exit 0
fi
if [[ -z "${OWL_JAR:-}" || ! -f "${OWL_JAR}" ]]; then
    echo "BLOCKED: set OWL_JAR to the pinned upstream owl.jar; widgets are not yet validated." >&2
    exit 1
fi
java -jar "${OWL_JAR}" check \
    "${REPO_ROOT}/hosts/poco-x3-pro/dotfiles/.config/omalauncher/widgets/"*.owl
