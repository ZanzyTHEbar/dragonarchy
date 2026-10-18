#!/usr/bin/env bash
# Refresh this checkout, then delegate the selected target to the installer.

set -euo pipefail

SOURCE="${BASH_SOURCE[0]}"
while [[ -h "$SOURCE" ]]; do
    DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ "$SOURCE" == /* ]] || SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"

fail() { printf 'Update refused: %s\n' "$*" >&2; exit 1; }

DRY_RUN=false
for arg in "$@"; do
    case "$arg" in
        -h|--help)
            cat <<'EOF'
Usage: update.sh --host <inventory host> --user <managed user> [installer options]

Validate the explicit target, refresh this clean checkout from its configured
upstream (one fetch, fast-forward only), then run the refreshed install --update.
--dry-run validates the current checkout only; it does not fetch or write.
--system-only / --user-only select installer scope. Other target options, including
--home, --source-dir, --connection and --target, are forwarded unchanged.
Inventory changes stop apply after refresh: review the changes and rerun.
No migrations, Stow, stash, reset, or live theme/background reselection.
EOF
            exit 0
            ;;
        --dry-run) DRY_RUN=true ;;
    esac
done

# Public refresh is bound to repository inventory, not an external/dynamic source.
[[ ! -v DOTFILES_INVENTORY ]] || fail 'DOTFILES_INVENTORY is not supported by public refresh; use install --update for custom inventory.'
export ANSIBLE_CONFIG="$REPO_ROOT/infra/ansible/ansible.cfg"
cd "$REPO_ROOT/infra/ansible"
"$REPO_ROOT/install" --update "$@" --dry-run
$DRY_RUN && exit 0

[[ "$(git -C "$REPO_ROOT" rev-parse --show-toplevel)" == "$REPO_ROOT" ]] || fail 'Script is not at the root of its own checkout.'
cd "$REPO_ROOT"

require_clean() {
    local status state state_path
    status="$(git status --porcelain --untracked-files=all --ignore-submodules=none)"
    [[ -z "$status" ]] || fail 'Checkout must be clean, including staged and untracked files. Commit or move your edits yourself.'
    for state in MERGE_HEAD rebase-merge rebase-apply CHERRY_PICK_HEAD REVERT_HEAD sequencer; do
        state_path="$(git rev-parse --git-path "$state")"
        [[ ! -e "$state_path" ]] || fail "Git operation in progress ($state)."
    done
}

require_clean
BRANCH="$(git symbolic-ref -q HEAD)" || fail 'An attached branch is required.'
HEAD_BEFORE="$(git rev-parse HEAD)"
UPSTREAM="$(git rev-parse --symbolic-full-name '@{upstream}')" || fail 'Configure a branch upstream first.'
REMOTE="$(git config --get "branch.${BRANCH#refs/heads/}.remote")" || fail 'Configure a branch remote first.'
MERGE_REF="$(git config --get "branch.${BRANCH#refs/heads/}.merge")" || fail 'Configure an upstream branch first.'
[[ "$REMOTE" != . && "$MERGE_REF" == refs/heads/* ]] || fail 'Upstream must be a branch on a configured remote.'
git remote get-url -- "$REMOTE" >/dev/null
git merge-base --is-ancestor HEAD "$UPSTREAM" || fail 'Local branch is ahead or diverged; publish or reconcile it explicitly.'

# Fetch only the selected upstream, regardless of broad configured refspecs.
git -c fetch.recurseSubmodules=false fetch --no-tags --no-recurse-submodules -- "$REMOTE" "$MERGE_REF"
FETCHED_HEAD="$(git rev-parse FETCH_HEAD)"
[[ "$(git symbolic-ref -q HEAD)" == "$BRANCH" && "$(git rev-parse HEAD)" == "$HEAD_BEFORE" ]] || fail 'Local branch or HEAD changed during fetch.'
require_clean
git merge-base --is-ancestor HEAD "$FETCHED_HEAD" || fail 'Local branch is ahead or diverged from fetched upstream; reconcile it explicitly.'
git -c merge.autoStash=false -c rebase.autoStash=false merge --ff-only --no-autostash --no-overwrite-ignore "$FETCHED_HEAD"
require_clean

# Conservative: all Ansible inputs (including vars, plugins and config), plus
# root vars/config and the tuple resolver. Never infer identity from human logs.
if ! git diff --quiet "$HEAD_BEFORE" HEAD -- infra/ansible ansible.cfg group_vars host_vars scripts/lib/target-tuple.py; then
    fail 'Inventory inputs changed during refresh; review the refreshed checkout and rerun. No target was applied.'
fi

cd "$REPO_ROOT/infra/ansible"
exec "$REPO_ROOT/install" --update "$@"
