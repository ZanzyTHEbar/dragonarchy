#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHEZMOI_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${CHEZMOI_ROOT}/../.." && pwd)"

HOST_NAME=""
TARGET_HOME="${HOME}"
EXECUTE=false
OUTPUT_PATH=""
BACKUP_ROOT=""
declare -a MANIFEST_PATHS=()

usage() {
  echo "Usage: $0 --host <hostname> [--manifest <path>]... [--home <path>] [--output <path>] [--backup-root <path>] [--execute]" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)
      HOST_NAME="${2:-}"
      shift 2
      ;;
    --manifest)
      MANIFEST_PATHS+=("${2:-}")
      shift 2
      ;;
    --home)
      TARGET_HOME="${2:-}"
      shift 2
      ;;
    --output)
      OUTPUT_PATH="${2:-}"
      shift 2
      ;;
    --backup-root)
      BACKUP_ROOT="${2:-}"
      shift 2
      ;;
    --execute)
      EXECUTE=true
      shift
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

if [[ -z "${HOST_NAME}" ]]; then
  usage
  exit 2
fi

if [[ ${#MANIFEST_PATHS[@]} -eq 0 ]]; then
  MANIFEST_PATHS=(
    "${CHEZMOI_ROOT}/manifests/session-core.manifest"
    "${CHEZMOI_ROOT}/manifests/session-shell.manifest"
    "${CHEZMOI_ROOT}/manifests/session-zsh.manifest"
    "${CHEZMOI_ROOT}/manifests/devtools-core.manifest"
    "${CHEZMOI_ROOT}/manifests/git-ssh.manifest"
  )
fi

if [[ -z "${OUTPUT_PATH}" ]]; then
  OUTPUT_PATH="${CHEZMOI_ROOT}/generated/${HOST_NAME}"
fi

if [[ -z "${BACKUP_ROOT}" ]]; then
  ts="$(date +%Y%m%d-%H%M%S)"
  BACKUP_ROOT="${TARGET_HOME}/.local/state/dotfiles/backups/${ts}/chezmoi-cutover/${HOST_NAME}"
fi

for manifest_path in "${MANIFEST_PATHS[@]}"; do
  if [[ ! -f "${manifest_path}" ]]; then
    echo "Manifest not found: ${manifest_path}" >&2
    exit 1
  fi
done

dest_to_home_rel() {
  local dest_rel="$1"
  dest_rel="${dest_rel//__HOST__/${HOST_NAME}}"

  local first_segment="${dest_rel%%/*}"
  local remainder=""
  if [[ "${dest_rel}" == */* ]]; then
    remainder="/${dest_rel#*/}"
  fi

  case "${first_segment}" in
    dot_*)
      printf '.%s%s\n' "${first_segment#dot_}" "${remainder}"
      ;;
    *)
      printf '%s\n' "${dest_rel}"
      ;;
  esac
}

regex_escape() {
  python - "$1" <<'PY'
import re
import sys
print(re.escape(sys.argv[1]))
PY
}

declare -A package_paths=()
declare -A host_paths=()
declare -a migrated_paths=()
blocked_paths=0
common_runtime_ignore_flags=(
  "--ignore=^\\.config/btop/themes/current\\.theme$"
  "--ignore=^\\.config/walker/themes/current/style\\.css$"
  "--ignore=^\\.config/kitty/colors\\.conf$"
  "--ignore=^\\.config/gtk-3\\.0/(gtk\\.css|settings\\.ini)$"
  "--ignore=^\\.config/gtk-4\\.0/(gtk\\.css|settings\\.ini)$"
  "--ignore=^\\.config/hypr/config/keyboard\\.local\\.conf$"
  "--ignore=^\\.config/hypr/colors-theme\\.conf$"
  "--ignore=^\\.config/swaync/style\\.css$"
  "--ignore=^\\.config/clipse/theme\\.toml$"
  "--ignore=^\\.config/wlogout/wlogout\\.css$"
)

while IFS='|' read -r mode source_rel dest_rel; do
  [[ -z "${mode}" ]] && continue
  [[ "${mode}" =~ ^# ]] && continue
  [[ "${mode}" == "exclude" ]] && continue

  source_rel="${source_rel//__HOST__/${HOST_NAME}}"
  dest_rel="${dest_rel//__HOST__/${HOST_NAME}}"
  home_rel="$(dest_to_home_rel "${dest_rel}")"

  migrated_paths+=("${home_rel}")

  case "${source_rel}" in
    packages/*)
      package_name="${source_rel#packages/}"
      package_name="${package_name%%/*}"
      package_paths["${package_name}"]+="${home_rel}"$'\n'
      ;;
    hosts/*/dotfiles/*)
      host_name="${source_rel#hosts/}"
      host_name="${host_name%%/*}"
      host_paths["${host_name}"]+="${home_rel}"$'\n'
      ;;
  esac
done < <(
  for manifest_path in "${MANIFEST_PATHS[@]}"; do
    cat "${manifest_path}"
  done
)

build_cmd=("${CHEZMOI_ROOT}/migration-scripts/build-source.sh" --host "${HOST_NAME}")
verify_cmd=("${CHEZMOI_ROOT}/migration-scripts/verify-generated-source.sh" --host "${HOST_NAME}")
for manifest_path in "${MANIFEST_PATHS[@]}"; do
  build_cmd+=(--manifest "${manifest_path}")
  verify_cmd+=(--manifest "${manifest_path}")
done
build_cmd+=(--output "${OUTPUT_PATH}")
verify_cmd+=(--output "${OUTPUT_PATH}")

declare -a package_commands=()
for package_name in $(printf '%s\n' "${!package_paths[@]}" | sort); do
  cmd=(stow --restow -d "${REPO_ROOT}/packages" -t "${TARGET_HOME}")
  case "${package_name}" in
    zsh|hyprland|kitty|gtk-3.0|gtk-4.0|wlogout)
      cmd=(stow --no-folding --restow -d "${REPO_ROOT}/packages" -t "${TARGET_HOME}")
      ;;
  esac
  cmd+=("${common_runtime_ignore_flags[@]}")
  while IFS= read -r path; do
    [[ -z "${path}" ]] && continue
    escaped="$(regex_escape "${path}")"
    cmd+=("--ignore=^${escaped}(/|$)")
  done < <(printf '%s' "${package_paths[${package_name}]}" | sort -u)
  cmd+=("${package_name}")
  package_commands+=("$(printf '%q ' "${cmd[@]}")")
done

declare -a host_commands=()
for host_name in $(printf '%s\n' "${!host_paths[@]}" | sort); do
  cmd=(stow --no-folding --restow -t "${TARGET_HOME}")
  while IFS= read -r path; do
    [[ -z "${path}" ]] && continue
    escaped="$(regex_escape "${path}")"
    cmd+=("--ignore=^${escaped}(/|$)")
  done < <(printf '%s' "${host_paths[${host_name}]}" | sort -u)
  cmd+=(.)
  host_commands+=("cd $(printf '%q' "${REPO_ROOT}/hosts/${host_name}/dotfiles") && $(printf '%q ' "${cmd[@]}")")
done

is_repo_symlink() {
  local path="$1"
  [[ -L "${path}" ]] || return 1

  local resolved
  resolved="$(readlink -f "${path}" 2>/dev/null || true)"
  [[ -n "${resolved}" && "${resolved}" == "${REPO_ROOT}"/* ]]
}

path_has_blockers() {
  local path="$1"

  if [[ ! -e "${path}" && ! -L "${path}" ]]; then
    return 1
  fi

  if [[ -L "${path}" ]]; then
    if is_repo_symlink "${path}"; then
      return 1
    fi
    return 0
  fi

  if [[ -f "${path}" ]]; then
    return 0
  fi

  if [[ -d "${path}" ]]; then
    while IFS= read -r entry; do
      if ! is_repo_symlink "${entry}"; then
        return 0
      fi
    done < <(find "${path}" -type l -print)
    return 1
  fi

  return 0
}

repo_managed_targets() {
  local path="$1"

  if [[ ! -e "${path}" && ! -L "${path}" ]]; then
    return 0
  fi

  if [[ -L "${path}" ]]; then
    if is_repo_symlink "${path}"; then
      printf '%s\n' "${path}"
    fi
    return 0
  fi

  if [[ -d "${path}" ]]; then
    while IFS= read -r entry; do
      if is_repo_symlink "${entry}"; then
        printf '%s\n' "${entry}"
      fi
    done < <(find "${path}" -type l -print)
  fi
}

print_header() {
  if [[ "${EXECUTE}" == "true" ]]; then
    echo "Executing chezmoi cutover for host '${HOST_NAME}'"
  else
    echo "Dry-run chezmoi cutover for host '${HOST_NAME}'"
  fi
  echo "Target home: ${TARGET_HOME}"
  echo "Generated source: ${OUTPUT_PATH}"
  echo "Backup root: ${BACKUP_ROOT}"
}

remove_path() {
  local home_rel="$1"
  local target_path="${TARGET_HOME}/${home_rel}"
  local removable_target=""
  declare -a removable_targets=()

  if [[ ! -e "${target_path}" && ! -L "${target_path}" ]]; then
    echo "SKIP ${target_path} (absent)"
    return 0
  fi

  if path_has_blockers "${target_path}"; then
    echo "BLOCKED ${target_path} (not repo-managed)" >&2
    blocked_paths=$((blocked_paths + 1))
    if [[ "${EXECUTE}" == "true" ]]; then
      return 1
    fi
    return 0
  fi

  while IFS= read -r removable_target; do
    [[ -n "${removable_target}" ]] || continue
    removable_targets+=("${removable_target}")
  done < <(repo_managed_targets "${target_path}")

  if [[ ${#removable_targets[@]} -eq 0 ]]; then
    echo "SKIP ${target_path} (no repo-managed entries)"
    return 0
  fi

  if [[ "${EXECUTE}" == "true" ]]; then
    for removable_target in "${removable_targets[@]}"; do
      local backup_rel="${removable_target#${TARGET_HOME}/}"
      mkdir -p "${BACKUP_ROOT}/$(dirname "${backup_rel}")"
      cp -a "${removable_target}" "${BACKUP_ROOT}/${backup_rel}"
      rm -rf "${removable_target}"
    done
    if [[ -d "${target_path}" ]]; then
      find "${target_path}" -mindepth 1 -depth -type d -empty -delete
    fi
    echo "REMOVED ${target_path}"
    return 0
  fi

  echo "WOULD_REMOVE ${target_path}"
}

run_command() {
  local cmd="$1"
  if [[ "${EXECUTE}" == "true" ]]; then
    eval "${cmd}"
    return 0
  fi

  echo "WOULD_RUN ${cmd}"
}

print_header

if [[ "${EXECUTE}" == "true" ]]; then
  if ! command -v stow >/dev/null 2>&1; then
    echo "stow is required for --execute but is not installed." >&2
    exit 1
  fi

  if ! command -v chezmoi >/dev/null 2>&1; then
    echo "chezmoi is required for --execute but is not installed." >&2
    exit 1
  fi
fi

echo
echo "Step 1: build generated source"
run_command "$(printf '%q ' "${build_cmd[@]}")"
echo
echo "Step 2: verify generated source"
run_command "$(printf '%q ' "${verify_cmd[@]}")"
echo
echo "Step 3: remove repo-managed Stow targets for migrated paths"
for home_rel in $(printf '%s\n' "${migrated_paths[@]}" | sort -u); do
  remove_path "${home_rel}"
done
echo
echo "Step 4: restow package carve-outs"
for cmd in "${package_commands[@]}"; do
  run_command "${cmd}"
done
echo
echo "Step 5: restow host carve-outs"
for cmd in "${host_commands[@]}"; do
  run_command "${cmd}"
done
echo
echo "Step 6: chezmoi diff and apply"
chezmoi_common_flags=(
  --source "${OUTPUT_PATH}"
  --destination "${TARGET_HOME}"
)
chezmoi_diff_cmd="chezmoi $(printf '%q ' "${chezmoi_common_flags[@]}") diff"
chezmoi_apply_cmd="chezmoi $(printf '%q ' "${chezmoi_common_flags[@]}") apply --force"

run_command "${chezmoi_diff_cmd}"
run_command "${chezmoi_apply_cmd}"

if [[ "${blocked_paths}" -ne 0 ]]; then
  echo
  echo "Dry-run detected ${blocked_paths} blocked path(s)." >&2
  if [[ "${EXECUTE}" == "true" ]]; then
    exit 1
  fi
fi
