#!/usr/bin/env bats

setup() {
  ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  TEST_ROOT="$(mktemp -d "$BATS_TEST_TMPDIR/public-update.XXXXXX")"
  export HOME="$TEST_ROOT/home" CALLS="$TEST_ROOT/calls" FETCHES="$TEST_ROOT/fetches"
  export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_ALLOW_PROTOCOL=file
  export GIT_AUTHOR_NAME=Fixture GIT_AUTHOR_EMAIL=fixture@example.invalid
  export GIT_COMMITTER_NAME=Fixture GIT_COMMITTER_EMAIL=fixture@example.invalid
  unset DOTFILES_INVENTORY
  REAL_GIT="$(command -v git)"
  export REAL_GIT
  REPO="$TEST_ROOT/checkout with spaces"
  mkdir -p "$HOME" "$TEST_ROOT/bin" "$REPO/scripts/install" "$REPO/scripts/theme-manager" "$REPO/infra/ansible/inventory"
  cp "$ROOT/scripts/install/update.sh" "$REPO/scripts/install/"
  cp "$ROOT/scripts/theme-manager/theme-update" "$REPO/scripts/theme-manager/"
  cp "$ROOT/scripts/dragon-cli" "$REPO/scripts/"
  mkdir -p "$REPO/scripts/lib"
  cp "$ROOT/scripts/lib/"*.sh "$REPO/scripts/lib/"
  cat >"$REPO/install" <<'EOF'
#!/usr/bin/env bash
host= user= dry=false
for ((i=1; i<=$#; i++)); do
  arg="${!i}"
  case "$arg" in
    --help|-h) echo 'Installer help'; exit 0;;
    --dry-run) dry=true;;
    --host) ((i+=1)); host="${!i}";;
    --user) ((i+=1)); user="${!i}";;
  esac
done
[[ -n "$host" && -n "$user" ]] || exit 2
if $dry; then echo 'Validated plan'; exit "${VALIDATE_STATUS:-0}"; fi
printf '%s\n' stale "$@" >>"$CALLS"
exit "${APPLY_STATUS:-0}"
EOF
  chmod +x "$REPO/install" "$REPO/scripts/install/update.sh" "$REPO/scripts/theme-manager/theme-update" "$REPO/scripts/dragon-cli"
  echo 'all: {}' >"$REPO/infra/ansible/inventory/hosts.yml"
  "$REAL_GIT" init -q -b main "$REPO"
  "$REAL_GIT" -C "$REPO" add .
  "$REAL_GIT" -C "$REPO" commit -qm initial
  "$REAL_GIT" clone -q --bare "$REPO" "$TEST_ROOT/remote.git"
  "$REAL_GIT" -C "$REPO" remote add origin "$TEST_ROOT/remote.git"
  "$REAL_GIT" -C "$REPO" fetch -q origin
  "$REAL_GIT" -C "$REPO" branch --set-upstream-to=origin/main main >/dev/null
  "$REAL_GIT" clone -q "$TEST_ROOT/remote.git" "$TEST_ROOT/publisher"
  cat >"$TEST_ROOT/bin/git" <<'EOF'
#!/usr/bin/env bash
for arg in "$@"; do
  if [[ "$arg" == fetch ]]; then
    echo fetch >>"$FETCHES"
    [[ "${FETCH_STATUS:-0}" == 0 ]] || exit "$FETCH_STATUS"
    if [[ -n "${FETCH_DIRT:-}" ]]; then echo dirt >"$FETCH_DIRT"; fi
    if [[ -n "${FETCH_BRANCH:-}" ]]; then "$REAL_GIT" -C "$FETCH_BRANCH" checkout -qb during-fetch; fi
    if [[ -n "${FETCH_HEAD_CHANGE:-}" ]]; then "$REAL_GIT" -C "$FETCH_HEAD_CHANGE" commit -q --allow-empty -m concurrent; fi
  fi
done
for arg in "$@"; do
  [[ "$arg" != merge || "${MERGE_STATUS:-0}" == 0 ]] || exit "$MERGE_STATUS"
done
exec "$REAL_GIT" "$@"
EOF
  chmod +x "$TEST_ROOT/bin/git"
  export PATH="$TEST_ROOT/bin:$PATH"
  cd "$TEST_ROOT"
}

teardown() { rm -rf "$TEST_ROOT"; }

publish() {
  "$REAL_GIT" -C "$TEST_ROOT/publisher" add .
  "$REAL_GIT" -C "$TEST_ROOT/publisher" commit -qm refresh
  "$REAL_GIT" -C "$TEST_ROOT/publisher" push -q origin main
}

update() { run "$REPO/scripts/install/update.sh" --host fixture --user testuser "$@"; }
no_apply() { [ ! -e "$CALLS" ]; }
no_fetch() { [ ! -e "$FETCHES" ]; }

@test "refresh fetches exactly once and executes refreshed absolute installer with intact argv" {
  sed -i s/stale/refreshed/ "$TEST_ROOT/publisher/install"
  publish
  update --user-only --home '/home/a b' --source-dir '/home/a b/.local/share/chezmoi'
  [ "$status" -eq 0 ]
  [ "$(cat "$FETCHES")" = fetch ]
  [ "$(head -1 "$CALLS")" = refreshed ]
  [ "$(cat "$CALLS")" = $'refreshed\n--update\n--host\nfixture\n--user\ntestuser\n--user-only\n--home\n/home/a b\n--source-dir\n/home/a b/.local/share/chezmoi' ]
}

@test "help dry-run missing selections and invalid tuple never fetch or apply" {
  for option in --help --dry-run; do
    update "$option"
    [ "$status" -eq 0 ]; no_fetch; no_apply
  done
  run "$REPO/scripts/install/update.sh"
  [ "$status" -ne 0 ]; no_fetch; no_apply
  run "$REPO/scripts/install/update.sh" --host fixture
  [ "$status" -ne 0 ]; no_fetch; no_apply
  export VALIDATE_STATUS=23
  update
  [ "$status" -eq 23 ]; no_fetch; no_apply
}

@test "dirty tracked staged and untracked checkouts refuse before fetch" {
  for kind in tracked staged untracked; do
    if [[ "$kind" == untracked ]]; then echo dirt >"$REPO/untracked"; else echo dirt >>"$REPO/install"; fi
    [[ "$kind" != staged ]] || "$REAL_GIT" -C "$REPO" add install
    update
    [ "$status" -ne 0 ]; no_fetch; no_apply
    "$REAL_GIT" -C "$REPO" reset -q --hard HEAD
    rm -f "$REPO/untracked"
  done
}

@test "detached missing upstream and in-progress operations refuse without fetch" {
  "$REAL_GIT" -C "$REPO" checkout -q --detach
  update
  [ "$status" -ne 0 ]; no_fetch; no_apply
  "$REAL_GIT" -C "$REPO" checkout -q main
  "$REAL_GIT" -C "$REPO" branch --unset-upstream
  update
  [ "$status" -ne 0 ]; no_fetch; no_apply
  "$REAL_GIT" -C "$REPO" branch --set-upstream-to=origin/main main >/dev/null
  for state in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD rebase-merge rebase-apply sequencer; do
    touch "$REPO/.git/$state"
    update
    [ "$status" -ne 0 ]; no_fetch; no_apply
    rm "$REPO/.git/$state"
  done
}

@test "ahead and diverged unpublished heads never apply" {
  "$REAL_GIT" -C "$REPO" commit -q --allow-empty -m unpublished
  update
  [ "$status" -ne 0 ]; no_apply
  echo remote >"$TEST_ROOT/publisher/remote-file"
  publish
  update
  [ "$status" -ne 0 ]; no_apply
}

@test "fetch failure propagates without apply" {
  export FETCH_STATUS=37
  update
  [ "$status" -eq 37 ]; no_apply
  [ "$(cat "$FETCHES")" = fetch ]
}

@test "merge failure propagates without apply or reset" {
  echo remote >"$TEST_ROOT/publisher/remote-file"
  publish
  export MERGE_STATUS=39
  update
  [ "$status" -eq 39 ]; no_apply
  [ ! -f "$REPO/remote-file" ]
  [ "$(cat "$FETCHES")" = fetch ]
}

@test "fast-forward refuses to overwrite an ignored local file" {
  printf 'private-local\n' >"$REPO/private-file"
  printf 'private-file\n' >>"$REPO/.git/info/exclude"
  printf 'upstream\n' >"$TEST_ROOT/publisher/private-file"
  publish
  before="$("$REAL_GIT" -C "$REPO" rev-parse HEAD)"
  update
  [ "$status" -ne 0 ]; no_apply
  [ "$(cat "$REPO/private-file")" = private-local ]
  [ "$("$REAL_GIT" -C "$REPO" rev-parse HEAD)" = "$before" ]
}

@test "inventory changes stop after refresh without rolling back" {
  echo '# changed group input' >"$TEST_ROOT/publisher/infra/ansible/inventory/group_vars.yml"
  publish
  update
  [ "$status" -ne 0 ]; no_apply
  [[ "$output" == *review* && "$output" == *rerun* ]]
  [ -f "$REPO/infra/ansible/inventory/group_vars.yml" ]
}

@test "external inventory override cannot refresh" {
  export DOTFILES_INVENTORY="$TEST_ROOT/external.yml"
  update
  [ "$status" -ne 0 ]; no_fetch; no_apply
}

@test "concurrent dirt branch or head changes during fetch stop before merge and apply" {
  echo remote >"$TEST_ROOT/publisher/remote-file"
  publish
  export FETCH_DIRT="$REPO/untracked"
  update
  [ "$status" -ne 0 ]; no_apply
  [ ! -f "$REPO/remote-file" ]
  rm "$REPO/untracked"; unset FETCH_DIRT
  export FETCH_BRANCH="$REPO"
  update
  [ "$status" -ne 0 ]; no_apply
  [ ! -f "$REPO/remote-file" ]
  unset FETCH_BRANCH
  export FETCH_HEAD_CHANGE="$REPO"
  update
  [ "$status" -ne 0 ]; no_apply
  [ ! -f "$REPO/remote-file" ]
}

@test "direct CLI symlink and worktree invocations resolve their own checkout and propagate failure" {
  export APPLY_STATUS=41
  ln -s 'checkout with spaces/scripts/install/update.sh' "$TEST_ROOT/updater-link"
  ln -s updater-link "$TEST_ROOT/updater"
  run "$TEST_ROOT/updater" --host fixture --user testuser --system-only
  [ "$status" -eq 41 ]
  grep -qx -- --system-only "$CALLS"
  rm "$CALLS"
  ln -s "$REPO/scripts/dragon-cli" "$TEST_ROOT/dragon"
  run "$TEST_ROOT/dragon" update --host fixture --user testuser --user-only
  [ "$status" -eq 41 ]
  grep -qx -- --user-only "$CALLS"
  rm "$CALLS"
  "$REAL_GIT" -C "$REPO" worktree add -q -b linked "$TEST_ROOT/linked checkout"
  "$REAL_GIT" -C "$TEST_ROOT/linked checkout" branch --set-upstream-to=origin/main linked >/dev/null
  run "$TEST_ROOT/linked checkout/scripts/install/update.sh" --host fixture --user testuser
  [ "$status" -eq 41 ]
}

@test "theme delegation is user-only rejects system scope and leaves runtime sentinels unchanged" {
  mkdir -p "$HOME/.config/current" "$HOME/.local/state"
  echo generated >"$HOME/.config/generated"
  echo history >"$HOME/.local/state/theme-history"
  ln -s ../generated "$HOME/.config/current/theme"
  ln -s /background/sentinel "$HOME/.config/current/background"
  before="$(find "$HOME" -type f -exec sha256sum {} +; find "$HOME" -type l -printf '%p %l\n')"
  mkdir -p "$TEST_ROOT/publisher/packages/themes"
  echo refreshed-asset >"$TEST_ROOT/publisher/packages/themes/fixture"
  publish
  run "$REPO/scripts/dragon-cli" theme update --host fixture --user testuser
  [ "$status" -eq 0 ]
  grep -qx -- --user-only "$CALLS"
  [ "$(cat "$REPO/packages/themes/fixture")" = refreshed-asset ]
  [ "$before" = "$(find "$HOME" -type f -exec sha256sum {} +; find "$HOME" -type l -printf '%p %l\n')" ]
  rm "$CALLS" "$FETCHES"
  ln -s "$REPO/scripts/theme-manager/theme-update" "$TEST_ROOT/theme-update"
  run "$TEST_ROOT/theme-update" --host fixture --user testuser --dry-run
  [ "$status" -eq 0 ]; no_fetch; no_apply
  run "$REPO/scripts/theme-manager/theme-update" --host fixture --user testuser --system-only
  [ "$status" -ne 0 ]; no_fetch; no_apply
}

@test "public migration creation route fails clearly" {
  run "$REPO/scripts/dragon-cli" utilities add-migration
  [ "$status" -ne 0 ]
  [[ "$output" == *retired* ]]
  no_fetch; no_apply
}

@test "interactive update requires explicit selections and never acknowledges a failed update" {
  cat >"$TEST_ROOT/bin/gum" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$HOME/gum-log"
case "$1" in
  choose)
    count=0
    [[ ! -f "$HOME/choices" ]] || count=$(cat "$HOME/choices")
    echo "$((count+1))" >"$HOME/choices"
    if [[ "$count" == 0 ]]; then echo Update; else echo Exit; fi
    ;;
  input)
    if [[ "$*" == *host* ]]; then printf '%s' "${PROMPT_HOST:-}"; else printf '%s' "${PROMPT_USER:-}"; fi
    ;;
esac
EOF
  chmod +x "$TEST_ROOT/bin/gum"
  export APPLY_STATUS=44 TERM=xterm
  for selection in empty-host empty-user valid; do
    export PROMPT_HOST=fixture PROMPT_USER=testuser
    [[ "$selection" != empty-host ]] || PROMPT_HOST=' '
    [[ "$selection" != empty-user ]] || PROMPT_USER=''
    rm -f "$HOME/choices" "$HOME/gum-log" "$CALLS" "$FETCHES"
    run python3 - "$REPO/scripts/dragon-cli" <<'EOF'
import os, pty, subprocess, sys
master, slave = pty.openpty()
try:
    proc = subprocess.Popen([sys.argv[1]], stdin=slave, stdout=slave, stderr=slave)
    proc.wait(timeout=10)
    assert proc.returncode == 0, proc.returncode
finally:
    os.close(master)
    os.close(slave)
EOF
    [ "$status" -eq 0 ]
    ! grep -q 'Done!' "$HOME/gum-log"
    if [[ "$selection" == valid ]]; then
      grep -qx fixture "$CALLS"
      grep -qx testuser "$CALLS"
    else
      no_fetch; no_apply
    fi
  done
}
