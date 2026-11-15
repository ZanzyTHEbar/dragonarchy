#!/usr/bin/env bats

setup() {
  umask 022
  local root
  root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  FIXTURE="$BATS_TEST_TMPDIR/repository"
  SOURCE="$BATS_TEST_TMPDIR/source"
  MANIFEST="$FIXTURE/infra/chezmoi/manifests/devtools-core.manifest"
  mkdir -p "$FIXTURE/infra/chezmoi/bin" "$(dirname "$MANIFEST")" \
    "$FIXTURE/packages/fixture" "$SOURCE/dot_config" "$BATS_TEST_TMPDIR/home"
  cp "$root/infra/chezmoi/bin/chezmoi-sync" "$FIXTURE/infra/chezmoi/bin/chezmoi-sync"
  cp -R "$root/infra/chezmoi/lib" "$FIXTURE/infra/chezmoi/lib"
  printf '{"inventory_hostname":"fixture","host_desktop_stack":"none"}\n' >"$FIXTURE/infra/chezmoi/host-selection.json"
  touch "$FIXTURE/infra/chezmoi/manifests/git-ssh.manifest" "$FIXTURE/infra/chezmoi/manifests/session-zsh.manifest"
  printf 'owned\n' >"$FIXTURE/packages/fixture/base.conf"
  printf 'required|packages/fixture/base.conf|dot_config/base.conf\n' >"$MANIFEST"
}

@test "optional host file overrides a generic required package directory child" {
  mkdir -p "$FIXTURE/hosts/fixture/dotfiles" "$FIXTURE/packages/fixture/tree"
  printf 'package\n' >"$FIXTURE/packages/fixture/tree/settings.conf"
  printf 'host\n' >"$FIXTURE/hosts/fixture/dotfiles/settings.conf"
  chmod 0750 "$FIXTURE/packages/fixture/tree"
  chmod 0755 "$FIXTURE/hosts/fixture/dotfiles/settings.conf"
  printf '%s\n' \
    'optional|hosts/fixture/dotfiles/settings.conf|dot_config/tool/settings.conf' \
    'required|packages/fixture/tree|dot_config/tool' >"$MANIFEST"
  sync_source
  [ "$(cat "$SOURCE/dot_config/tool/executable_settings.conf")" = host ]
  [ ! -e "$SOURCE/dot_config/tool/settings.conf" ]
  [ "$(stat -c %a "$SOURCE/dot_config/tool")" = 750 ]
  cp "$SOURCE.chezmoi-sync-state" "$BATS_TEST_TMPDIR/first-state"
  sync_source
  [ "$(stat -c %a "$SOURCE/dot_config/tool")" = 750 ]
  [ "$(cat "$SOURCE/dot_config/tool/executable_settings.conf")" = host ]
  cmp "$SOURCE.chezmoi-sync-state" "$BATS_TEST_TMPDIR/first-state"
}

@test "rejects inverse host parent and package child overlay" {
  mkdir -p "$FIXTURE/hosts/fixture/dotfiles/tree"
  printf '%s\n' \
    'optional|hosts/fixture/dotfiles/tree|dot_config/tool' \
    'required|packages/fixture/base.conf|dot_config/tool/base.conf' >"$MANIFEST"
  run env -i HOME="$BATS_TEST_TMPDIR/home" PATH=/usr/bin:/bin \
    bash "$FIXTURE/infra/chezmoi/bin/chezmoi-sync" --host fixture --source-dir "$SOURCE"
  [ "$status" -ne 0 ]
  [[ "$output" == *"parent/child destination conflict"* ]]
}

@test "rejects directory host child overlay" {
  mkdir -p "$FIXTURE/hosts/fixture/dotfiles/tree" "$FIXTURE/packages/fixture/tree"
  printf '%s\n' \
    'required|packages/fixture/tree|dot_config/tool' \
    'optional|hosts/fixture/dotfiles/tree|dot_config/tool/child' >"$MANIFEST"
  run env -i HOME="$BATS_TEST_TMPDIR/home" PATH=/usr/bin:/bin \
    bash "$FIXTURE/infra/chezmoi/bin/chezmoi-sync" --host fixture --source-dir "$SOURCE"
  [ "$status" -ne 0 ]
  [[ "$output" == *"parent/child destination conflict"* ]]
}

sync_source() {
  run env -i HOME="$BATS_TEST_TMPDIR/home" PATH=/usr/bin:/bin \
    bash "$FIXTURE/infra/chezmoi/bin/chezmoi-sync" --host fixture --source-dir "$SOURCE"
  [ "$status" -eq 0 ]
}

@test "first sync preserves unowned aliases while declared output updates" {
  printf 'private\n' >"$SOURCE/dot_config/private_base.conf"
  chmod 0600 "$SOURCE/dot_config/private_base.conf"
  mkdir "$SOURCE/dot_config/executable_base.conf"
  printf 'nested\n' >"$SOURCE/dot_config/executable_base.conf/sentinel"
  printf 'outside\n' >"$BATS_TEST_TMPDIR/outside"
  ln -s "$BATS_TEST_TMPDIR/outside" "$SOURCE/dot_config/symlink_base.conf"

  sync_source
  cmp "$FIXTURE/packages/fixture/base.conf" "$SOURCE/dot_config/base.conf"
  [ "$(cat "$SOURCE/dot_config/private_base.conf")" = private ]
  printf 'updated\n' >"$FIXTURE/packages/fixture/base.conf"
  sync_source
  cmp "$FIXTURE/packages/fixture/base.conf" "$SOURCE/dot_config/base.conf"
  [ "$(cat "$SOURCE/dot_config/private_base.conf")" = private ]
  [ "$(stat -c %a "$SOURCE/dot_config/private_base.conf")" = 600 ]
  [ "$(cat "$SOURCE/dot_config/executable_base.conf/sentinel")" = nested ]
  [ "$(readlink "$SOURCE/dot_config/symlink_base.conf")" = "$BATS_TEST_TMPDIR/outside" ]
  [ "$(cat "$BATS_TEST_TMPDIR/outside")" = outside ]
}

@test "source sync preserves an unowned hardlink and the completed journal" {
  sync_source
  mkdir -p "$SOURCE/personal/nested"
  printf 'personal\n' >"$BATS_TEST_TMPDIR/outside-hardlink"
  chmod 0640 "$BATS_TEST_TMPDIR/outside-hardlink"
  ln "$BATS_TEST_TMPDIR/outside-hardlink" "$SOURCE/personal/nested/linked"
  before="$(stat -c '%d:%i:%h:%a' "$BATS_TEST_TMPDIR/outside-hardlink")"
  cp "$SOURCE.chezmoi-sync-state" "$BATS_TEST_TMPDIR/state-before"
  printf 'new desired content\n' >"$FIXTURE/packages/fixture/base.conf"

  run env -i HOME="$BATS_TEST_TMPDIR/home" PATH=/usr/bin:/bin \
    bash "$FIXTURE/infra/chezmoi/bin/chezmoi-sync" --host fixture --source-dir "$SOURCE"
  [ "$status" -ne 0 ]
  [[ "$output" == *"$SOURCE/personal/nested/linked"* ]]
  [[ "$output" == *"hardlinked"* ]]
  [ "$(stat -c '%d:%i:%h:%a' "$BATS_TEST_TMPDIR/outside-hardlink")" = "$before" ]
  [ "$(stat -c '%d:%i:%h:%a' "$SOURCE/personal/nested/linked")" = "$before" ]
  [ "$(cat "$SOURCE/personal/nested/linked")" = personal ]
  [ "$(cat "$SOURCE/dot_config/base.conf")" = owned ]
  cmp "$SOURCE.chezmoi-sync-state" "$BATS_TEST_TMPDIR/state-before"
  [ ! -e "$SOURCE.chezmoi-sync-stage" ]
  [ ! -e "$SOURCE.chezmoi-sync-backup" ]
}

@test "v2 source sync preserves a personal edit during update and removal" {
  sync_source
  printf 'personal source edit\n' >"$SOURCE/dot_config/base.conf"
  cp "$SOURCE.chezmoi-sync-state" "$BATS_TEST_TMPDIR/state-before"
  printf 'upstream update\n' >"$FIXTURE/packages/fixture/base.conf"
  for action in update removal; do
    if [ "$action" = removal ]; then : >"$MANIFEST"; fi
    run env -i HOME="$BATS_TEST_TMPDIR/home" PATH=/usr/bin:/bin \
      bash "$FIXTURE/infra/chezmoi/bin/chezmoi-sync" --host fixture --source-dir "$SOURCE"
    [ "$status" -ne 0 ]
    [[ "$output" == *"differs from recorded evidence"* ]]
    [ "$(cat "$SOURCE/dot_config/base.conf")" = 'personal source edit' ]
    cmp "$SOURCE.chezmoi-sync-state" "$BATS_TEST_TMPDIR/state-before"
    [ ! -e "$SOURCE.chezmoi-sync-stage" ]
    [ ! -e "$SOURCE.chezmoi-sync-backup" ]
  done
}

@test "v2 sync refuses replacing an owned directory before staging" {
  mkdir "$FIXTURE/packages/fixture/tree"
  printf 'initial\n' >"$FIXTURE/packages/fixture/tree/settings.conf"
  printf 'required|packages/fixture/tree|dot_config/tool\n' >"$MANIFEST"
  sync_source
  [ "$(head -c 21 "$SOURCE.chezmoi-sync-state")" = 'chezmoi-sync-state-v2' ]
  printf 'normal update\n' >"$FIXTURE/packages/fixture/tree/settings.conf"
  sync_source
  [ "$(cat "$SOURCE/dot_config/tool/settings.conf")" = 'normal update' ]
  printf 'unowned\n' >"$SOURCE/dot_config/personal.conf"
  directory_before="$(stat -c '%d:%i:%a' "$SOURCE/dot_config/tool")"
  child_before="$(stat -c '%d:%i:%a' "$SOURCE/dot_config/tool/settings.conf")"
  cp "$SOURCE.chezmoi-sync-state" "$BATS_TEST_TMPDIR/state-before"
  printf 'required|packages/fixture/base.conf|dot_config/tool\n' >"$MANIFEST"

  run env -i HOME="$BATS_TEST_TMPDIR/home" PATH=/usr/bin:/bin \
    bash "$FIXTURE/infra/chezmoi/bin/chezmoi-sync" --host fixture --source-dir "$SOURCE"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Owned source directory cannot be replaced by a file"* ]]
  [[ "$output" == *"$SOURCE/dot_config/tool"* ]]
  [ "$(cat "$SOURCE/dot_config/tool/settings.conf")" = 'normal update' ]
  [ "$(cat "$SOURCE/dot_config/personal.conf")" = unowned ]
  [ "$(stat -c '%d:%i:%a' "$SOURCE/dot_config/tool")" = "$directory_before" ]
  [ "$(stat -c '%d:%i:%a' "$SOURCE/dot_config/tool/settings.conf")" = "$child_before" ]
  cmp "$SOURCE.chezmoi-sync-state" "$BATS_TEST_TMPDIR/state-before"
  [ ! -e "$SOURCE.chezmoi-sync-stage" ]
  [ ! -e "$SOURCE.chezmoi-sync-backup" ]
}

@test "source sync refuses an unowned collision and retains shared user directories" {
  mkdir -p "$FIXTURE/packages/fixture/tree" "$SOURCE/dot_config/tool"
  printf 'managed\n' >"$FIXTURE/packages/fixture/tree/settings.conf"
  printf 'personal\n' >"$SOURCE/dot_config/tool/settings.conf"
  chmod 0700 "$SOURCE/dot_config/tool"
  printf 'required|packages/fixture/tree|dot_config/tool\n' >"$MANIFEST"

  run env -i HOME="$BATS_TEST_TMPDIR/home" PATH=/usr/bin:/bin \
    bash "$FIXTURE/infra/chezmoi/bin/chezmoi-sync" --host fixture --source-dir "$SOURCE"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unowned source path conflicts with manifest"* ]]
  [ "$(cat "$SOURCE/dot_config/tool/settings.conf")" = personal ]
  [ ! -e "$SOURCE.chezmoi-sync-state" ]
  [ ! -e "$SOURCE.chezmoi-sync-stage" ]

  mv "$SOURCE/dot_config/tool/settings.conf" "$SOURCE/dot_config/tool/personal.conf"
  sync_source
  printf 'updated\n' >"$FIXTURE/packages/fixture/tree/settings.conf"
  sync_source
  [ "$(cat "$SOURCE/dot_config/tool/settings.conf")" = updated ]
  [ "$(cat "$SOURCE/dot_config/tool/personal.conf")" = personal ]
  [ "$(stat -c %a "$SOURCE/dot_config/tool")" = 700 ]

  printf 'another managed file\n' >"$FIXTURE/packages/fixture/tree/extra.conf"
  ln -s personal.conf "$SOURCE/dot_config/tool/extra.conf"
  cp "$SOURCE.chezmoi-sync-state" "$BATS_TEST_TMPDIR/state-before"
  run env -i HOME="$BATS_TEST_TMPDIR/home" PATH=/usr/bin:/bin \
    bash "$FIXTURE/infra/chezmoi/bin/chezmoi-sync" --host fixture --source-dir "$SOURCE"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unowned source path conflicts with manifest"* ]]
  [ "$(readlink "$SOURCE/dot_config/tool/extra.conf")" = personal.conf ]
  [ "$(cat "$SOURCE/dot_config/tool/personal.conf")" = personal ]
  [ "$(cat "$SOURCE/dot_config/tool/settings.conf")" = updated ]
  cmp "$SOURCE.chezmoi-sync-state" "$BATS_TEST_TMPDIR/state-before"
  [ ! -e "$SOURCE.chezmoi-sync-stage" ]
}

@test "untracked transaction directories are preserved on initial and repeat sync" {
  mkdir "$SOURCE.chezmoi-sync-stage"
  printf 'personal staging data\n' >"$SOURCE.chezmoi-sync-stage/personal"
  run env -i HOME="$BATS_TEST_TMPDIR/home" PATH=/usr/bin:/bin \
    bash "$FIXTURE/infra/chezmoi/bin/chezmoi-sync" --host fixture --source-dir "$SOURCE"
  [ "$status" -ne 0 ]
  [ "$(cat "$SOURCE.chezmoi-sync-stage/personal")" = 'personal staging data' ]
  [ ! -e "$SOURCE.chezmoi-sync-state" ]
  [ ! -e "$SOURCE/dot_config/base.conf" ]

  mv "$SOURCE.chezmoi-sync-stage" "$BATS_TEST_TMPDIR/reviewed-stage"
  sync_source
  mkdir "$SOURCE.chezmoi-sync-stage"
  printf 'other staging data\n' >"$SOURCE.chezmoi-sync-stage/personal"
  cp "$SOURCE.chezmoi-sync-state" "$BATS_TEST_TMPDIR/state-before"
  run env -i HOME="$BATS_TEST_TMPDIR/home" PATH=/usr/bin:/bin \
    bash "$FIXTURE/infra/chezmoi/bin/chezmoi-sync" --host fixture --source-dir "$SOURCE"
  [ "$status" -ne 0 ]
  [ "$(cat "$SOURCE.chezmoi-sync-stage/personal")" = 'other staging data' ]
  cmp "$SOURCE.chezmoi-sync-state" "$BATS_TEST_TMPDIR/state-before"
  cmp "$FIXTURE/packages/fixture/base.conf" "$SOURCE/dot_config/base.conf"

  mv "$SOURCE.chezmoi-sync-stage" "$BATS_TEST_TMPDIR/second-reviewed-stage"
  mkdir "$SOURCE.chezmoi-sync-backup"
  printf 'personal backup data\n' >"$SOURCE.chezmoi-sync-backup/personal"
  run env -i HOME="$BATS_TEST_TMPDIR/home" PATH=/usr/bin:/bin \
    bash "$FIXTURE/infra/chezmoi/bin/chezmoi-sync" --host fixture --source-dir "$SOURCE"
  [ "$status" -ne 0 ]
  [ "$(cat "$SOURCE.chezmoi-sync-backup/personal")" = 'personal backup data' ]
  cmp "$SOURCE.chezmoi-sync-state" "$BATS_TEST_TMPDIR/state-before"
  cmp "$FIXTURE/packages/fixture/base.conf" "$SOURCE/dot_config/base.conf"
}

@test "removed mappings prune recorded output but preserve unowned neighbors" {
  printf 'unowned\n' >"$SOURCE/dot_config/unowned.conf"
  sync_source
  [ -f "$SOURCE/dot_config/base.conf" ]
  printf 'required|packages/fixture/base.conf|dot_config/replacement.conf\n' >"$MANIFEST"
  sync_source
  [ ! -e "$SOURCE/dot_config/base.conf" ]
  cmp "$FIXTURE/packages/fixture/base.conf" "$SOURCE/dot_config/replacement.conf"
  [ "$(cat "$SOURCE/dot_config/unowned.conf")" = unowned ]
}

@test "exclusions prune only recorded ownership and preserve unowned descendants" {
  mkdir -p "$FIXTURE/packages/fixture/runtime"
  printf 'owned\n' >"$FIXTURE/packages/fixture/runtime/old.conf"
  printf 'required|packages/fixture/runtime|dot_config/runtime\n' >"$MANIFEST"
  sync_source
  printf 'personal\n' >"$SOURCE/dot_config/runtime/personal.conf"
  printf 'exclude||dot_config/runtime\n' >>"$MANIFEST"
  sync_source
  [ ! -e "$SOURCE/dot_config/runtime/old.conf" ]
  [ "$(cat "$SOURCE/dot_config/runtime/personal.conf")" = personal ]
}

@test "unambiguous finalization journal failure remains retryable" {
  run python3 - "$BATS_TEST_DIRNAME/../../infra/chezmoi/lib" "$BATS_TEST_TMPDIR" <<'PY'
import errno
from pathlib import Path
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, sys.argv[1])
from sync_engine import Transaction
for topology in ('finalizing', 'staging'):
    root = Path(sys.argv[2]) / topology
    tx = Transaction(root)
    tx.status, tx.old = topology, ['owned']
    tx.write(topology, tx.old)
    root.mkdir()
    (root / 'owned').write_text('original')
    def no_space(*args):
        raise OSError(errno.ENOSPC, 'injected journal failure')
    tx.write = no_space
    try:
        tx.recover()
    except OSError as error:
        assert error.errno == errno.ENOSPC
    else:
        raise AssertionError('expected injected write failure')
    retry = Transaction(root)
    retry.read()
    retry.recover()
    assert (root / 'owned').read_text() == 'original'
    assert not retry.stage.exists() and not retry.backup.exists()
    assert retry.status == 'complete'
PY
  [ "$status" -eq 0 ]
}

@test "interrupted promoted source preserves edits on recovery and retry" {
  sync_source
  printf 'personal\n' >"$SOURCE/personal"
  printf 'updated\n' >"$FIXTURE/packages/fixture/base.conf"
  run env -i HOME="$BATS_TEST_TMPDIR/home" PATH=/usr/bin:/bin CHEZMOI_SYNC_FAILPOINT=promote:after-root \
    bash "$FIXTURE/infra/chezmoi/bin/chezmoi-sync" --host fixture --source-dir "$SOURCE"
  [ "$status" -ne 0 ]
  printf 'personal edit\n' >"$SOURCE/dot_config/base.conf"
  printf 'new personal file\n' >"$SOURCE/new-personal"
  cp "$SOURCE.chezmoi-sync-state" "$BATS_TEST_TMPDIR/interrupted-state"
  rm "$FIXTURE/packages/fixture/base.conf"
  for mode in recover retry; do
    if [ "$mode" = recover ]; then
      run env -i HOME="$BATS_TEST_TMPDIR/home" PATH=/usr/bin:/bin \
        bash "$FIXTURE/infra/chezmoi/bin/chezmoi-sync" --host fixture --source-dir "$SOURCE" --recover-only
    else
      run env -i HOME="$BATS_TEST_TMPDIR/home" PATH=/usr/bin:/bin \
        bash "$FIXTURE/infra/chezmoi/bin/chezmoi-sync" --host fixture --source-dir "$SOURCE"
    fi
    [ "$status" -ne 0 ]
    [[ "$output" == *"needs inspection"* ]]
    [[ "$output" == *"$SOURCE.chezmoi-sync-backup"* ]]
    [ "$(cat "$SOURCE/dot_config/base.conf")" = 'personal edit' ]
    [ "$(cat "$SOURCE/new-personal")" = 'new personal file' ]
    [ "$(cat "$SOURCE/personal")" = personal ]
    [ "$(cat "$SOURCE.chezmoi-sync-backup/dot_config/base.conf")" = owned ]
    cmp "$SOURCE.chezmoi-sync-state" "$BATS_TEST_TMPDIR/interrupted-state"
    [ ! -e "$SOURCE.chezmoi-sync-stage" ]
  done
}

@test "sync restores unowned parent directory modes after updates and pruning" {
  chmod 0555 "$SOURCE/dot_config"
  sync_source
  [ "$(stat -c %a "$SOURCE/dot_config")" = 555 ]
  printf 'required|packages/fixture/base.conf|dot_config/replacement.conf\n' >"$MANIFEST"
  sync_source
  [ "$(stat -c %a "$SOURCE/dot_config")" = 555 ]
  [ ! -e "$SOURCE/dot_config/base.conf" ]
  chmod 0755 "$SOURCE/dot_config"
}

@test "native source encoding preserves literal names attributes bytes and link text" {
  tree="$FIXTURE/packages/fixture/tree"
  mkdir -p "$tree/.nested" "$tree/private-dir"
  printf 'literal template\n' >"$tree/.nested/file.tmpl"
  printf 'reserved\n' >"$tree/private_name"
  printf 'readonly\n' >"$tree/readonly-file"
  : >"$tree/empty-tool"
  chmod 0700 "$tree/private-dir"
  chmod 0400 "$tree/readonly-file"
  chmod 0755 "$tree/empty-tool"
  ln -s .nested/file.tmpl "$tree/link"
  printf 'required|packages/fixture/tree|dot_config/tool\n' >"$MANIFEST"
  sync_source
  cmp "$tree/.nested/file.tmpl" "$SOURCE/dot_config/tool/dot_nested/literal_file.tmpl.tmpl"
  cmp "$tree/private_name" "$SOURCE/dot_config/tool/literal_private_name"
  cmp "$tree/readonly-file" "$SOURCE/dot_config/tool/private_readonly_readonly-file"
  [ "$(stat -c %a "$SOURCE/dot_config/tool/private_readonly_readonly-file")" = 400 ]
  [ "$(stat -c %a "$SOURCE/dot_config/tool/private_private-dir")" = 700 ]
  [ ! -s "$SOURCE/dot_config/tool/empty_executable_empty-tool" ]
  [ "$(stat -c %a "$SOURCE/dot_config/tool/empty_executable_empty-tool")" = 755 ]
  [ ! -L "$SOURCE/dot_config/tool/symlink_link" ]
  [ "$(cat "$SOURCE/dot_config/tool/symlink_link")" = .nested/file.tmpl ]
}

@test "v1 NUL journal refuses stale paths and retains equal newline entries" {
  printf 'stale\n' >"$SOURCE/dot_config/old.conf"
  printf '%s\0' chezmoi-sync-state-v1 complete dot_config/old.conf >"$SOURCE.chezmoi-sync-state"
  mkdir "$FIXTURE/packages/fixture/tree"
  name=$'line\nbreak'
  printf 'newline\n' >"$FIXTURE/packages/fixture/tree/$name"
  printf 'required|packages/fixture/tree|dot_config/tool\n' >"$MANIFEST"
  cp "$SOURCE.chezmoi-sync-state" "$BATS_TEST_TMPDIR/stale-state"
  run env -i HOME="$BATS_TEST_TMPDIR/home" PATH=/usr/bin:/bin \
    bash "$FIXTURE/infra/chezmoi/bin/chezmoi-sync" --host fixture --source-dir "$SOURCE"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unverified v1 source path is stale"* ]]
  [ "$(cat "$SOURCE/dot_config/old.conf")" = stale ]
  cmp "$BATS_TEST_TMPDIR/stale-state" "$SOURCE.chezmoi-sync-state"
  [ ! -e "$SOURCE.chezmoi-sync-stage" ]

  target="$BATS_TEST_TMPDIR/v1-equal"
  mkdir -p "$target/dot_config/tool"
  cp "$FIXTURE/packages/fixture/tree/$name" "$target/dot_config/tool/$name"
  printf '%s\0' chezmoi-sync-state-v1 complete dot_config/tool "dot_config/tool/$name" >"$target.chezmoi-sync-state"
  cp "$target.chezmoi-sync-state" "$BATS_TEST_TMPDIR/expected-state"
  run env -i HOME="$BATS_TEST_TMPDIR/home" PATH=/usr/bin:/bin \
    bash "$FIXTURE/infra/chezmoi/bin/chezmoi-sync" --host fixture --source-dir "$target" --recover-only
  [ "$status" -eq 0 ]
  cmp "$BATS_TEST_TMPDIR/expected-state" "$target.chezmoi-sync-state"
  run env -i HOME="$BATS_TEST_TMPDIR/home" PATH=/usr/bin:/bin \
    bash "$FIXTURE/infra/chezmoi/bin/chezmoi-sync" --host fixture --source-dir "$target"
  [ "$status" -eq 0 ]
  cmp "$FIXTURE/packages/fixture/tree/$name" "$target/dot_config/tool/$name"
  cmp "$BATS_TEST_TMPDIR/expected-state" "$target.chezmoi-sync-state"
}

@test "rejects CR manifest records before creating lifecycle state" {
  printf 'required|packages/fixture/base.conf|dot_config/base.conf\r\n' >"$MANIFEST"
  run env -i HOME="$BATS_TEST_TMPDIR/home" PATH=/usr/bin:/bin \
    bash "$FIXTURE/infra/chezmoi/bin/chezmoi-sync" --host fixture --source-dir "$SOURCE"
  [ "$status" -ne 0 ]
  [[ "$output" == *"contains CR"* ]]
  [ ! -e "$SOURCE.chezmoi-sync-state" ]
}

@test "first promotion preserves ambiguous interrupted trees and completes unambiguous finalization" {
  for point in copy:1 promote:after-prepare promote:after-root; do
    target="$BATS_TEST_TMPDIR/${point//:/-}"
    run env -i HOME="$BATS_TEST_TMPDIR/home" PATH=/usr/bin:/bin CHEZMOI_SYNC_FAILPOINT="$point" \
      bash "$FIXTURE/infra/chezmoi/bin/chezmoi-sync" --host fixture --source-dir "$target"
    [ "$status" -ne 0 ]
    cp "$target.chezmoi-sync-state" "$BATS_TEST_TMPDIR/state-${point//:/-}"
    if [ -d "$target" ]; then tree="$target"; else tree="$target.chezmoi-sync-stage"; fi
    printf 'personal\n' >"$tree/personal"
    run env -i HOME="$BATS_TEST_TMPDIR/home" PATH=/usr/bin:/bin \
      bash "$FIXTURE/infra/chezmoi/bin/chezmoi-sync" --host fixture --source-dir "$target"
    [ "$status" -ne 0 ]
    [[ "$output" == *"needs inspection"* ]]
    [ "$(cat "$tree/personal")" = personal ]
    cmp "$target.chezmoi-sync-state" "$BATS_TEST_TMPDIR/state-${point//:/-}"
    [ ! -e "$target.chezmoi-sync-backup" ]
  done
  target="$BATS_TEST_TMPDIR/finalized-new"
  run env -i HOME="$BATS_TEST_TMPDIR/home" PATH=/usr/bin:/bin CHEZMOI_SYNC_FAILPOINT=finalize:before-backup-delete \
    bash "$FIXTURE/infra/chezmoi/bin/chezmoi-sync" --host fixture --source-dir "$target"
  [ "$status" -ne 0 ]
  mv "$FIXTURE/packages/fixture/base.conf" "$BATS_TEST_TMPDIR/base.conf"
  run env -i HOME="$BATS_TEST_TMPDIR/home" PATH=/usr/bin:/bin \
    bash "$FIXTURE/infra/chezmoi/bin/chezmoi-sync" --host fixture --source-dir "$target"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Required source missing"* ]]
  cmp "$BATS_TEST_TMPDIR/base.conf" "$target/dot_config/base.conf"
  digest="$(sha256sum "$BATS_TEST_TMPDIR/base.conf" | cut -d' ' -f1)"
  printf '%s\0' chezmoi-sync-state-v2 complete dot_config/base.conf f 644 "$digest" >"$BATS_TEST_TMPDIR/completed-state"
  cmp "$BATS_TEST_TMPDIR/completed-state" "$target.chezmoi-sync-state"
  mv "$BATS_TEST_TMPDIR/base.conf" "$FIXTURE/packages/fixture/base.conf"
  run env -i HOME="$BATS_TEST_TMPDIR/home" PATH=/usr/bin:/bin \
    bash "$FIXTURE/infra/chezmoi/bin/chezmoi-sync" --host fixture --source-dir "$target"
  [ "$status" -eq 0 ]
  cmp "$FIXTURE/packages/fixture/base.conf" "$target/dot_config/base.conf"
  [ ! -e "$target.chezmoi-sync-stage" ]
  [ ! -e "$target.chezmoi-sync-backup" ]

  target="$BATS_TEST_TMPDIR/finalized-existing"
  mkdir "$target"
  printf 'original\n' >"$target/personal"
  run env -i HOME="$BATS_TEST_TMPDIR/home" PATH=/usr/bin:/bin CHEZMOI_SYNC_FAILPOINT=finalize:before-backup-delete \
    bash "$FIXTURE/infra/chezmoi/bin/chezmoi-sync" --host fixture --source-dir "$target"
  [ "$status" -ne 0 ]
  printf 'backup edit\n' >"$target.chezmoi-sync-backup/personal"
  cp "$target.chezmoi-sync-state" "$BATS_TEST_TMPDIR/finalizing-state"
  run env -i HOME="$BATS_TEST_TMPDIR/home" PATH=/usr/bin:/bin \
    bash "$FIXTURE/infra/chezmoi/bin/chezmoi-sync" --host fixture --source-dir "$target" --recover-only
  [ "$status" -ne 0 ]
  [[ "$output" == *"needs inspection"* ]]
  [ "$(cat "$target.chezmoi-sync-backup/personal")" = 'backup edit' ]
  [ "$(cat "$target/personal")" = original ]
  cmp "$target.chezmoi-sync-state" "$BATS_TEST_TMPDIR/finalizing-state"
}
