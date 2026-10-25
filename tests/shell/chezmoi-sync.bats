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
  chmod 0755 "$FIXTURE/hosts/fixture/dotfiles/settings.conf"
  printf '%s\n' \
    'optional|hosts/fixture/dotfiles/settings.conf|dot_config/tool/settings.conf' \
    'required|packages/fixture/tree|dot_config/tool' >"$MANIFEST"
  sync_source
  [ "$(cat "$SOURCE/dot_config/tool/executable_settings.conf")" = host ]
  [ ! -e "$SOURCE/dot_config/tool/settings.conf" ]
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

@test "rollback journal failure remains retryable" {
  run python3 - "$BATS_TEST_DIRNAME/../../infra/chezmoi/lib" "$BATS_TEST_TMPDIR" <<'PY'
import errno
from pathlib import Path
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, sys.argv[1])
from sync_engine import Transaction
for topology in ('parked', 'promoted', 'prepark'):
    root = Path(sys.argv[2]) / topology
    tx = Transaction(root)
    tx.status, tx.old = 'prepared', ['owned']
    tx.write('prepared', tx.old, ['new'])
    if topology != 'parked':
        root.mkdir()
        (root / 'owned').write_text('original' if topology == 'prepark' else 'new')
    if topology != 'promoted':
        tx.stage.mkdir()
    if topology != 'prepark':
        tx.backup.mkdir()
        (tx.backup / 'owned').write_text('original')
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

@test "reads a Bash-compatible NUL journal and preserves newline filenames" {
  printf 'stale\n' >"$SOURCE/dot_config/old.conf"
  printf '%s\0' chezmoi-sync-state-v1 complete dot_config/old.conf >"$SOURCE.chezmoi-sync-state"
  mkdir "$FIXTURE/packages/fixture/tree"
  name=$'line\nbreak'
  printf 'newline\n' >"$FIXTURE/packages/fixture/tree/$name"
  printf 'required|packages/fixture/tree|dot_config/tool\n' >"$MANIFEST"
  sync_source
  [ ! -e "$SOURCE/dot_config/old.conf" ]
  cmp "$FIXTURE/packages/fixture/tree/$name" "$SOURCE/dot_config/tool/$name"
  printf '%s\0' chezmoi-sync-state-v1 complete dot_config/tool "dot_config/tool/$name" >"$BATS_TEST_TMPDIR/expected-state"
  cmp "$BATS_TEST_TMPDIR/expected-state" "$SOURCE.chezmoi-sync-state"
}

@test "rejects CR manifest records before creating lifecycle state" {
  printf 'required|packages/fixture/base.conf|dot_config/base.conf\r\n' >"$MANIFEST"
  run env -i HOME="$BATS_TEST_TMPDIR/home" PATH=/usr/bin:/bin \
    bash "$FIXTURE/infra/chezmoi/bin/chezmoi-sync" --host fixture --source-dir "$SOURCE"
  [ "$status" -ne 0 ]
  [[ "$output" == *"contains CR"* ]]
  [ ! -e "$SOURCE.chezmoi-sync-state" ]
}

@test "first promotion of an absent source recovers at each promotion boundary" {
  for point in promote:after-prepare promote:after-root finalize:before-backup-delete; do
    target="$BATS_TEST_TMPDIR/${point//:/-}"
    run env -i HOME="$BATS_TEST_TMPDIR/home" PATH=/usr/bin:/bin CHEZMOI_SYNC_FAILPOINT="$point" \
      bash "$FIXTURE/infra/chezmoi/bin/chezmoi-sync" --host fixture --source-dir "$target"
    [ "$status" -ne 0 ]
    run env -i HOME="$BATS_TEST_TMPDIR/home" PATH=/usr/bin:/bin \
      bash "$FIXTURE/infra/chezmoi/bin/chezmoi-sync" --host fixture --source-dir "$target"
    [ "$status" -eq 0 ]
    cmp "$FIXTURE/packages/fixture/base.conf" "$target/dot_config/base.conf"
    [ ! -e "$target.chezmoi-sync-stage" ]
    [ ! -e "$target.chezmoi-sync-backup" ]
  done
}
