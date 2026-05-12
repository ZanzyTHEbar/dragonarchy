#!/usr/bin/env bash
#
# validate-parity — Check Ansible + chezmoi parity for a host
#
# Usage: ./infra/validate-parity.sh --host <hostname>
#
# Verifies that the declarative control plane (Ansible + chezmoi) is complete
# for the given host. This is a read-only check that does not modify any state.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

HOST_NAME=""

usage() {
    echo "Usage: $0 --host <hostname>" >&2
    exit 2
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --host)
            HOST_NAME="${2:-}"
            shift 2
            ;;
        *)
            usage
            ;;
    esac
done

if [[ -z "${HOST_NAME}" ]]; then
    usage
fi

INVENTORY="${REPO_ROOT}/infra/ansible/inventory/hosts.yml"
HOST_VARS="${REPO_ROOT}/infra/ansible/inventory/host_vars/${HOST_NAME}.yml"

ERRORS=0
WARNINGS=0

error() {
    echo "  [FAIL] $*" >&2
    ERRORS=$((ERRORS + 1))
}

warn() {
    echo "  [WARN] $*" >&2
    WARNINGS=$((WARNINGS + 1))
}

ok() {
    echo "  [OK]   $*"
}

# ---------------------------------------------------------------------------
# Section 1: Ansible inventory validation
# ---------------------------------------------------------------------------

echo "==> Ansible parity check for host '${HOST_NAME}'"

if ! command -v ansible-inventory >/dev/null 2>&1; then
    error "ansible-inventory not found"
    exit 1
fi

if ! ansible-inventory -i "${INVENTORY}" --host "${HOST_NAME}" >/dev/null 2>&1; then
    error "Host '${HOST_NAME}' not found in inventory"
    exit 1
fi

ok "Host '${HOST_NAME}' exists in inventory"

if [[ ! -f "${HOST_VARS}" ]]; then
    warn "No host_vars file: ${HOST_VARS}"
else
    ok "host_vars file exists"
fi

# Parse host variables via ansible-inventory JSON
HOST_JSON=$(ansible-inventory -i "${INVENTORY}" --host "${HOST_NAME}" 2>/dev/null)

# Check capabilities declared
declared_caps=$(echo "${HOST_JSON}" | python3 -c "import sys, json; d=json.load(sys.stdin); caps=d.get('host_capabilities',[]); print('\n'.join(caps))" || true)

if [[ -z "${declared_caps}" ]]; then
    warn "No capabilities declared for host"
else
    ok "Capabilities declared: $(echo ${declared_caps} | tr '\n' ' ')"
fi

# Check GPU stack
gpu_stack=$(echo "${HOST_JSON}" | python3 -c "import sys, json; d=json.load(sys.stdin); gpus=d.get('host_gpu_stack',[]); print('\n'.join(gpus))" || true)

if [[ -n "${gpu_stack}" ]]; then
    ok "GPU stack: $(echo ${gpu_stack} | tr '\n' ' ')"
fi

# ---------------------------------------------------------------------------
# Section 2: Ansible role coverage
# ---------------------------------------------------------------------------

echo ""
echo "==> Ansible role coverage"

# Determine which playbooks apply to this host
SITE_PLAYBOOK="${REPO_ROOT}/infra/ansible/playbooks/site.yml"

if [[ ! -f "${SITE_PLAYBOOK}" ]]; then
    error "site.yml not found"
else
    ok "site.yml exists"
fi

# Check that expected role directories exist
EXPECTED_ROLES=(
    common base packages users
    sddm hyprland
    resolved
)

# Add GPU roles based on GPU stack
for gpu in ${gpu_stack:-}; do
    case "${gpu}" in
        amd) EXPECTED_ROLES+=(amd_gpu) ;;
        nvidia) EXPECTED_ROLES+=(nvidia) ;;
        intel) EXPECTED_ROLES+=(intel_gpu) ;;
    esac
done

# Add capability-based roles
for cap in ${declared_caps:-}; do
    case "${cap}" in
        tlp) EXPECTED_ROLES+=(tlp) ;;
        fingerprint) EXPECTED_ROLES+=(fingerprint) ;;
        asus) EXPECTED_ROLES+=(asus_laptop) ;;
        hibernation) EXPECTED_ROLES+=(hibernation) ;;
        netbird) EXPECTED_ROLES+=(netbird) ;;
        fortinet_vpn) EXPECTED_ROLES+=(openfortivpn) ;;
        aio-cooler) EXPECTED_ROLES+=(aio-cooler) ;;
        v4l2loopback) EXPECTED_ROLES+=(v4l2loopback) ;;
    esac
done

for role in "${EXPECTED_ROLES[@]}"; do
    role_dir="${REPO_ROOT}/infra/ansible/roles/${role}"
    if [[ ! -d "${role_dir}" ]]; then
        error "Missing role: ${role}"
    else
        ok "Role exists: ${role}"
    fi
done

# ---------------------------------------------------------------------------
# Section 3: Chezmoi manifest validation
# ---------------------------------------------------------------------------

echo ""
echo "==> Chezmoi manifest parity"

MANIFEST_DIR="${REPO_ROOT}/infra/chezmoi/manifests"
MANIFEST_COUNT=0

if [[ ! -d "${MANIFEST_DIR}" ]]; then
    error "Manifest directory not found: ${MANIFEST_DIR}"
else
    for manifest in "${MANIFEST_DIR}"/*.manifest; do
        [[ -f "${manifest}" ]] || continue
        MANIFEST_COUNT=$((MANIFEST_COUNT + 1))
        manifest_name=$(basename "${manifest}")
        ok "Manifest: ${manifest_name}"

        # Validate manifest entries point to existing sources
        while IFS='|' read -r mode source_rel dest_rel; do
            [[ -z "${mode}" ]] && continue
            [[ "${mode}" =~ ^# ]] && continue
            [[ "${mode}" == "exclude" ]] && continue

            source_rel="${source_rel//__HOST__/${HOST_NAME}}"

            if [[ -n "${source_rel}" ]]; then
                source_abs="${REPO_ROOT}/${source_rel}"
                if [[ ! -e "${source_abs}" ]]; then
                    if [[ "${mode}" == "required" ]]; then
                        error "Required source missing: ${source_rel}"
                    else
                        warn "Optional source missing: ${source_rel}"
                    fi
                fi
            fi
        done < "${manifest}"
    done
fi

if [[ ${MANIFEST_COUNT} -eq 0 ]]; then
    error "No manifests found"
else
    ok "${MANIFEST_COUNT} manifest(s) validated"
fi

# ---------------------------------------------------------------------------
# Section 4: Legacy retirement check
# ---------------------------------------------------------------------------

echo ""
echo "==> Legacy retirement check"

# Check that host setup.sh has deprecation notice
SETUP_SCRIPT="${REPO_ROOT}/hosts/${HOST_NAME}/setup.sh"
if [[ -f "${SETUP_SCRIPT}" ]]; then
    if grep -q "DEPRECATED" "${SETUP_SCRIPT}"; then
        ok "setup.sh has deprecation notice"
    else
        warn "setup.sh missing deprecation notice"
    fi
else
    ok "No legacy setup.sh (already removed)"
fi

# Check that install.sh is NOT the recommended entrypoint
if [[ -f "${REPO_ROOT}/install.sh" ]]; then
    warn "Legacy install.sh still exists (should be deprecated)"
fi

if [[ -f "${REPO_ROOT}/install" ]]; then
    ok "New ./install entrypoint exists"
else
    error "Missing ./install entrypoint"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo ""
echo "==> Summary for host '${HOST_NAME}'"
echo "    Errors:   ${ERRORS}"
echo "    Warnings: ${WARNINGS}"

if [[ ${ERRORS} -gt 0 ]]; then
    echo "    Result:   FAILED"
    exit 1
elif [[ ${WARNINGS} -gt 0 ]]; then
    echo "    Result:   PASSED WITH WARNINGS"
    exit 0
else
    echo "    Result:   PASSED"
    exit 0
fi
