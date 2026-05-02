#!/usr/bin/env bash
# Emit a resolved package plan from deps.manifest.toml for automation (Ansible, CI).
# Reuses manifest-toml.sh (host/features gating, bundle-free group resolution).
#
# Usage:
#   export-package-plan.sh --platform arch --host firedragon --feature-csv hyprland \
#     --groups core_cli,dev,host_firedragon_laptop [--format json]
#
# Requires: yq v4 (mikefarah), jq (for --format json).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "${REPO_ROOT:-}" ]]; then
	REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/logging.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/manifest-toml.sh"

MANIFEST_FILE="${SCRIPT_DIR}/deps.manifest.toml"
PLATFORM=""
HOST_NAME=""
FEATURE_CSV=""
GROUPS_CSV=""
FORMAT="json"

tier_for_manager() {
	case "$1" in
	pacman | apt) echo "repo" ;;
	paru) echo "aur" ;;
	script) echo "script" ;;
	*) echo "unknown" ;;
	esac
}

normalize_arch_pkg() {
	local p="$1"
	case "$p" in
	powerprofilesctl) echo "power-profiles-daemon" ;;
	*) echo "$p" ;;
	esac
}

usage() {
	cat <<'EOF'
Usage: export-package-plan.sh --platform <arch|debian> --groups <comma-separated> \
  [--host <name>] [--feature-csv <csv>] [--manifest <path>] [--format json]

Outputs JSON with resolved groups, flat lists by manager tier, and ansible_install hints.
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	--platform)
		PLATFORM="${2:-}"
		shift 2
		;;
	--host)
		HOST_NAME="${2:-}"
		shift 2
		;;
	--feature-csv)
		FEATURE_CSV="${2:-}"
		shift 2
		;;
	--groups)
		GROUPS_CSV="${2:-}"
		shift 2
		;;
	--manifest)
		MANIFEST_FILE="${2:-}"
		shift 2
		;;
	--format)
		FORMAT="${2:-}"
		shift 2
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		log_error "Unknown argument: $1"
		usage
		exit 1
		;;
	esac
done

if [[ -z "$PLATFORM" || -z "$GROUPS_CSV" ]]; then
	log_error "--platform and --groups are required"
	usage
	exit 1
fi

if [[ ! -f "$MANIFEST_FILE" ]]; then
	log_error "Manifest not found: $MANIFEST_FILE"
	exit 1
fi

if [[ "$FORMAT" != "json" ]]; then
	log_error "Only --format json is supported"
	exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
	log_error "'jq' is required for JSON output"
	exit 1
fi

manifest_ensure_yq "$PLATFORM" >/dev/null 2>&1 || true
if ! manifest_yq_resolve_bin >/dev/null 2>&1; then
	log_error "yq v4 (mikefarah) is required"
	exit 1
fi

IFS=',' read -r -a REQUESTED_GROUPS <<<"${GROUPS_CSV//[[:space:]]/}"

# Discover managers defined for this platform in the manifest.
mapfile -t MANAGERS < <(manifest_yq_query "$MANIFEST_FILE" ".platforms.${PLATFORM} | keys | .[]" | sort)
if [[ ${#MANAGERS[@]} -eq 0 ]]; then
	log_error "No managers found for platform '$PLATFORM' in manifest"
	exit 1
fi

# shellcheck disable=SC2034
declare -a JSON_GROUPS=()
declare -A PACMAN_PKGS=()
declare -A APT_PKGS=()
declare -A PARU_PKGS=()
declare -A SCRIPT_PKGS=()
declare -a UNRESOLVED_GROUPS=()

for logical_group in "${REQUESTED_GROUPS[@]}"; do
	[[ -z "$logical_group" ]] && continue
	found_any="false"
	for manager in "${MANAGERS[@]}"; do
		[[ -z "$manager" || "$manager" == "null" ]] && continue
		exists=$(manifest_yq_query "$MANIFEST_FILE" ".platforms.${PLATFORM}.${manager}.${logical_group} | type")
		[[ -z "$exists" || "$exists" == "null" || "$exists" == "!!null" ]] && continue

		if ! manifest_group_enabled "$MANIFEST_FILE" "$PLATFORM" "$manager" "$logical_group" "$HOST_NAME" "$FEATURE_CSV"; then
			continue
		fi

		found_any="true"
		tier=$(tier_for_manager "$manager")
		mapfile -t pkgs < <(manifest_group_packages "$MANIFEST_FILE" "$PLATFORM" "$manager" "$logical_group" "$HOST_NAME" "$FEATURE_CSV")
		normalized=()
		for p in "${pkgs[@]}"; do
			[[ -z "$p" || "$p" == "null" ]] && continue
			if [[ "$PLATFORM" == "arch" ]]; then
				p=$(normalize_arch_pkg "$p")
			fi
			normalized+=("$p")
		done

		if [[ ${#normalized[@]} -eq 0 ]]; then
			packages_json='[]'
		else
			packages_json="$(jq -n '$ARGS.positional' --args "${normalized[@]}")"
		fi
		entry_json=$(jq -n \
			--arg manager "$manager" \
			--arg group "$logical_group" \
			--arg tier "$tier" \
			--argjson packages "$packages_json" \
			'{manager: $manager, group: $group, tier: $tier, packages: $packages}')

		JSON_GROUPS+=("$entry_json")

		for p in "${normalized[@]}"; do
			case "$manager" in
			pacman) PACMAN_PKGS["$p"]=1 ;;
			apt) APT_PKGS["$p"]=1 ;;
			paru) PARU_PKGS["$p"]=1 ;;
			script) SCRIPT_PKGS["$p"]=1 ;;
			esac
		done
	done
	if [[ "$found_any" == "false" ]]; then
		UNRESOLVED_GROUPS+=("$logical_group")
	fi
done

if [[ ${#UNRESOLVED_GROUPS[@]} -gt 0 ]]; then
	log_error "Requested manifest group(s) missing or disabled for platform=$PLATFORM host=${HOST_NAME:-<unset>} features=${FEATURE_CSV:-<none>}: ${UNRESOLVED_GROUPS[*]}"
	exit 1
fi

assoc_keys_to_json_array() {
	local -n _arr="$1"
	if [[ ${#_arr[@]} -eq 0 ]]; then
		echo '[]'
		return
	fi
	mapfile -t sorted < <(printf '%s\n' "${!_arr[@]}" | sort -u)
	jq -n '$ARGS.positional' --args "${sorted[@]}"
}

pacman_list=$(assoc_keys_to_json_array PACMAN_PKGS)
apt_list=$(assoc_keys_to_json_array APT_PKGS)
paru_list=$(assoc_keys_to_json_array PARU_PKGS)
script_list=$(assoc_keys_to_json_array SCRIPT_PKGS)

groups_json=$(printf '%s\n' "${JSON_GROUPS[@]}" | jq -s '.')

jq -n \
	--arg manifest "$MANIFEST_FILE" \
	--arg platform "$PLATFORM" \
	--arg host "${HOST_NAME:-}" \
	--arg feature_csv "${FEATURE_CSV:-}" \
	--arg groups_csv "$GROUPS_CSV" \
	--argjson groups "$groups_json" \
	--argjson pacman "$pacman_list" \
	--argjson apt "$apt_list" \
	--argjson paru "$paru_list" \
	--argjson script "$script_list" \
	'{
  manifest: $manifest,
  platform: $platform,
  host: $host,
  feature_csv: $feature_csv,
  requested_groups: ($groups_csv | split(",") | map(gsub("^ +| +$";"")) | map(select(length > 0))),
  groups: $groups,
  by_manager: {
    pacman: $pacman,
    apt: $apt,
    paru: $paru,
    script: $script
  },
  ansible_install: {
    pacman: $pacman,
    apt: $apt
  },
  pending: {
    paru: $paru,
    script: $script
  }
}'
