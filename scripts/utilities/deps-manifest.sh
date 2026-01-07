#!/usr/bin/env bash
# Utility: add packages to scripts/install/deps.manifest.toml

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
    REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
MANIFEST_FILE="${MANIFEST_FILE:-$REPO_ROOT/scripts/install/deps.manifest.toml}"

# shellcheck disable=SC1091
source "$REPO_ROOT/scripts/lib/logging.sh"

usage() {
    cat <<EOF
Usage:
    $(basename "$0") add  --platform <arch|debian> --manager <pacman|paru|apt> --group <name> --package <pkg> [--package <pkg> ...]
    $(basename "$0") add  --platform <...> --manager <...> --group <...> <pkg1> <pkg2> ...
    $(basename "$0") add                      # interactive (requires gum + TTY)
    $(basename "$0") list [--platform <...>] [--manager <...>]   # show existing groups

Options:
  --platform            Canonical platform key (arch, debian)
  --manager             Package manager key (pacman, paru, apt)
  --group               Group name under platforms.<platform>.<manager>.<group>
  --package             Package name to append (repeatable)
  --requires-feature    Add/ensure a requires_features entry (repeatable)
  --requires-host       Add/ensure a requires_hosts entry (repeatable)
  --exclude-host        Add/ensure an exclude_hosts entry (repeatable)
  --dry-run             Show what would change (no file write)
  -h, --help            Show help

Notes:
- Uses python3 + tomlkit for TOML edits (yq v4 TOML encoder is limited for arrays/objects).
- De-dupes by checking existing array membership before appending.
Env:
- MANIFEST_FILE: override path to deps.manifest.toml
EOF
}

need_gum_tty() {
    [[ -t 0 && -t 1 ]] || return 1
    command -v gum >/dev/null 2>&1 || return 1
    return 0
}

ensure_manifest_prereqs() {
    if [[ ! -f "$MANIFEST_FILE" ]]; then
        log_error "Deps manifest not found at: $MANIFEST_FILE"
        return 1
    fi

    if ! command -v python3 >/dev/null 2>&1; then
        log_error "python3 is required to edit the deps manifest"
        return 1
    fi

    if ! python3 -c 'import tomlkit' >/dev/null 2>&1; then
        log_error "python3 module 'tomlkit' is required"
        log_error "Install it with: python3 -m pip install --user tomlkit"
        return 1
    fi

    return 0
}

py_list_tree() {
    local platform="${1:-}" manager="${2:-}"

    python3 - "$MANIFEST_FILE" "$platform" "$manager" <<'PY'
import sys
from tomlkit import parse

path = sys.argv[1]
platform = sys.argv[2] if len(sys.argv) > 2 else ""
manager = sys.argv[3] if len(sys.argv) > 3 else ""

with open(path, "r", encoding="utf-8") as f:
    doc = parse(f.read())

platforms = doc.get("platforms") or {}

def keys(obj):
    try:
        return list(obj.keys())
    except Exception:
        return []

platform_list = keys(platforms) if not platform else [platform]
for p in platform_list:
    if p not in platforms:
        continue
    managers = platforms[p]
    manager_list = keys(managers) if not manager else [manager]
    for m in manager_list:
        if m not in managers:
            continue
        groups = managers[m]
        for g in keys(groups):
            print(f"{p}\t{m}\t{g}")
PY
}

py_add_packages() {
    local platform="$1" manager="$2" group="$3" dry_run="$4"
    shift 4

    local requires_features_csv="$1"; shift
    local requires_hosts_csv="$1"; shift
    local exclude_hosts_csv="$1"; shift

    python3 - "$MANIFEST_FILE" "$platform" "$manager" "$group" "$dry_run" "$requires_features_csv" "$requires_hosts_csv" "$exclude_hosts_csv" "$@" <<'PY'
import sys
from tomlkit import parse, dumps, table, array

path = sys.argv[1]
platform = sys.argv[2]
manager = sys.argv[3]
group = sys.argv[4]
dry_run = sys.argv[5].lower() == "true"
req_features = [x for x in (sys.argv[6] or "").split(",") if x]
req_hosts = [x for x in (sys.argv[7] or "").split(",") if x]
ex_hosts = [x for x in (sys.argv[8] or "").split(",") if x]
packages = [x for x in sys.argv[9:] if x]

with open(path, "r", encoding="utf-8") as f:
    doc = parse(f.read())

def ensure_table(parent, key):
    if key in parent and parent[key] is not None:
        return parent[key]
    t = table()
    parent[key] = t
    return t

def ensure_array(parent, key):
    if key in parent and parent[key] is not None:
        arr = parent[key]
        if isinstance(arr, list):
            a = array()
            a.multiline(True)
            for v in arr:
                a.append(v)
            parent[key] = a
            return a
        return arr
    a = array()
    a.multiline(True)
    parent[key] = a
    return a

platforms = ensure_table(doc, "platforms")
plat = ensure_table(platforms, platform)
man = ensure_table(plat, manager)
grp = ensure_table(man, group)

changes = []

def add_unique(arr_obj, value, label):
    values = list(arr_obj)
    if value in values:
        return
    arr_obj.append(value)
    changes.append(f"{label}: {value}")

for feat in req_features:
    add_unique(ensure_array(grp, "requires_features"), feat, "requires_feature")
for h in req_hosts:
    add_unique(ensure_array(grp, "requires_hosts"), h, "requires_host")
for h in ex_hosts:
    add_unique(ensure_array(grp, "exclude_hosts"), h, "exclude_host")

pkgs_arr = ensure_array(grp, "packages")
pkgs_arr.multiline(True)
for pkg in packages:
    add_unique(pkgs_arr, pkg, "package")

if not changes:
    print("No changes")
    sys.exit(0)

if dry_run:
    for c in changes:
        print(f"Would add {c}")
    sys.exit(0)

with open(path, "w", encoding="utf-8") as f:
    f.write(dumps(doc))

for c in changes:
    print(f"Added {c}")
PY
}

list_platforms() {
    ensure_manifest_prereqs
    py_list_tree | awk -F'\t' '{print $1}' | sort -u
}

list_managers() {
    local platform="$1"
    ensure_manifest_prereqs
    py_list_tree "$platform" | awk -F'\t' '{print $2}' | sort -u
}

list_groups() {
    local platform="$1" manager="$2"
    ensure_manifest_prereqs
    py_list_tree "$platform" "$manager" | awk -F'\t' '{print $3}' | sort -u
}

list_tree() {
    local platform="${1:-}" manager="${2:-}"
    ensure_manifest_prereqs
    py_list_tree "$platform" "$manager"
}

interactive_add() {
    need_gum_tty || {
        log_error "Interactive mode requires a TTY and gum"
        usage
        exit 1
    }

    ensure_manifest_prereqs

    local platform manager group pkgs_input

    platform=$(printf "%s\n" arch debian | gum choose --header="Select platform")

    case "$platform" in
        arch) manager=$(printf "%s\n" pacman paru | gum choose --header="Select manager") ;;
        debian) manager=$(printf "%s\n" apt | gum choose --header="Select manager") ;;
        *) log_error "Unsupported platform: $platform"; exit 1 ;;
    esac

    local existing_groups
    existing_groups=$(list_groups "$platform" "$manager" | tr '\n' '\n')
    if [[ -n "$existing_groups" ]]; then
        group=$(printf "%s\n" "$existing_groups" "(new)" | gum choose --header="Select group") || exit 0
        if [[ "$group" == "(new)" ]]; then
            group=$(gum input --header="New group name" --placeholder="e.g., core_cli, dev, fonts, hyprland_base")
        fi
    else
        group=$(gum input --header="Group name" --placeholder="e.g., core_cli, dev, fonts, hyprland_base")
    fi
    [[ -z "$group" ]] && exit 0

    pkgs_input=$(gum input --header="Package(s)" --placeholder="space-separated (e.g., ripgrep fd fzf)")
    [[ -z "$pkgs_input" ]] && exit 0

    # shellcheck disable=SC2206
    local pkgs=( $pkgs_input )

    run_add "$platform" "$manager" "$group" "false" "" "" "" "${pkgs[@]}"
}

run_add() {
    local platform="$1" manager="$2" group="$3" dry_run="$4"
    shift 4

    local requires_features_csv="$1"; shift
    local requires_hosts_csv="$1"; shift
    local exclude_hosts_csv="$1"; shift

    ensure_manifest_prereqs

    py_add_packages "$platform" "$manager" "$group" "$dry_run" "$requires_features_csv" "$requires_hosts_csv" "$exclude_hosts_csv" "$@"

    if [[ "$dry_run" != "true" ]]; then
        log_success "Updated manifest: $MANIFEST_FILE"
    fi
}

main() {
    if [[ $# -eq 0 ]]; then
        interactive_add
        return 0
    fi

    local cmd="${1:-}"; shift || true
    case "$cmd" in
        -h|--help|help)
            usage
            return 0
            ;;
        list)
            local platform="" manager=""
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --platform) platform="$2"; shift 2 ;;
                    --manager) manager="$2"; shift 2 ;;
                    -h|--help) usage; return 0 ;;
                    *) shift ;;
                esac
            done
            list_tree "$platform" "$manager"
            return 0
            ;;
        add)
            ;;
        *)
            # Back-compat: default to add
            set -- "$cmd" "$@"
            cmd="add"
            ;;
    esac

    local platform="" manager="" group="" dry_run="false"
    local -a packages=()
    local -a requires_features=()
    local -a requires_hosts=()
    local -a exclude_hosts=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --platform) platform="$2"; shift 2 ;;
            --manager) manager="$2"; shift 2 ;;
            --group) group="$2"; shift 2 ;;
            --package) packages+=("$2"); shift 2 ;;
            --requires-feature) requires_features+=("$2"); shift 2 ;;
            --requires-host) requires_hosts+=("$2"); shift 2 ;;
            --exclude-host) exclude_hosts+=("$2"); shift 2 ;;
            --dry-run) dry_run="true"; shift ;;
            -h|--help) usage; return 0 ;;
            --) shift; break ;;
            *)
                packages+=("$1")
                shift
                ;;
        esac
    done

    if [[ -z "$platform" && ${#packages[@]} -eq 0 ]]; then
        interactive_add
        return 0
    fi

    if [[ -z "$platform" || -z "$manager" || -z "$group" ]]; then
        log_error "Missing required args: --platform, --manager, --group"
        usage
        return 1
    fi

    if [[ ${#packages[@]} -eq 0 ]]; then
        log_error "No packages provided"
        usage
        return 1
    fi

    local rf_csv rh_csv eh_csv
    rf_csv=$(IFS=','; echo "${requires_features[*]-}")
    rh_csv=$(IFS=','; echo "${requires_hosts[*]-}")
    eh_csv=$(IFS=','; echo "${exclude_hosts[*]-}")

    run_add "$platform" "$manager" "$group" "$dry_run" "$rf_csv" "$rh_csv" "$eh_csv" "${packages[@]}"
}

main "$@"
