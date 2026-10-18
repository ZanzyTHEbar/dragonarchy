#!/usr/bin/env bats

setup() {
  REPOSITORY_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  INSTALL="$REPOSITORY_ROOT/install"
  WRAPPER="$REPOSITORY_ROOT/infra/ansible/run-playbook.sh"
  TEST_ROOT="$(mktemp -d)"
  MOCK_DIR="$TEST_ROOT/bin"
  SYNC_COMMAND="$MOCK_DIR/chezmoi-sync"
  TARGET_HOME="$TEST_ROOT/home"
  TARGET_SOURCE="$TARGET_HOME/.local/share/chezmoi"
  TMP_ROOT="${TMPDIR:-/tmp}"
  REMOTE_TUPLE="dotfiles_target_profile=remote-host dotfiles_target_user=remoteuser dotfiles_target_home=/remote/microdragon/home/remoteuser dotfiles_target_source=/remote/microdragon/home/remoteuser/.local/share/chezmoi dotfiles_target_connection=ssh"
  LOG="$TEST_ROOT/commands.log"
  mkdir -p "$MOCK_DIR" "$TARGET_HOME"

  cat >"$MOCK_DIR/ansible-inventory" <<'EOF'
#!/usr/bin/env bash
if [[ "${INVENTORY_MODE:-}" == unknown ]]; then
  exit 1
fi
case "${INVENTORY_MODE:-remote}" in
  local)
    profile=local-profile; connection=local; user=localuser; home="${FIXTURE_HOME}"; source="${FIXTURE_SOURCE}"
    platform_mode=local; local_policy=required; container_policy=forbidden; remote_policy=forbidden; container_identity=not-applicable; ansible_connection=local
    users='[{"name":"localuser","home":"'"${FIXTURE_HOME}"'","chezmoi_source":"'"${FIXTURE_SOURCE}"'","groups":["sudo"]}]'
    ;;
  container)
    profile=container; connection=local; user=coder; home="${FIXTURE_HOME}"; source="${FIXTURE_SOURCE}"
    platform_mode=local; local_policy=required; container_policy=required; remote_policy=forbidden; container_identity=declared-local-container; ansible_connection=local
    users='[{"name":"coder","home":"'"${FIXTURE_HOME}"'","chezmoi_source":"'"${FIXTURE_SOURCE}"'","groups":["sudo"]}]'
    ;;
  root)
    profile=local-profile; connection=local; user=root; home=/root; source=/root/.local/share/chezmoi
    platform_mode=local; local_policy=required; container_policy=forbidden; remote_policy=forbidden; container_identity=not-applicable; ansible_connection=local
    users='[{"name":"root","groups":["sudo"],"home":"/root","chezmoi_source":"/root/.local/share/chezmoi"}]'
    ;;
  ambiguous)
    profile=local-profile; connection=local; user=one; home="${FIXTURE_HOME}"; source="${FIXTURE_SOURCE}"
    platform_mode=local; local_policy=required; container_policy=forbidden; remote_policy=forbidden; container_identity=not-applicable; ansible_connection=local
    users='[{"name":"one","home":"'"${FIXTURE_HOME}"'","chezmoi_source":"'"${FIXTURE_SOURCE}"'","groups":["sudo"]},{"name":"two","home":"'"${FIXTURE_HOME}"'","chezmoi_source":"'"${FIXTURE_SOURCE}"'","groups":["sudo"]}]'
    ;;
  duplicate)
    profile=local-profile; connection=local; user=one; home="${FIXTURE_HOME}"; source="${FIXTURE_SOURCE}"
    platform_mode=local; local_policy=required; container_policy=forbidden; remote_policy=forbidden; container_identity=not-applicable; ansible_connection=local
    users='[{"name":"one","home":"'"${FIXTURE_HOME}"'","chezmoi_source":"'"${FIXTURE_SOURCE}"'","groups":["sudo"]},{"name":"one","home":"'"${FIXTURE_HOME}"'","chezmoi_source":"'"${FIXTURE_SOURCE}"'","groups":["sudo"]}]'
    ;;
  missing-profile)
    profile=; connection=local; user=localuser; home="${FIXTURE_HOME}"; source="${FIXTURE_SOURCE}"
    platform_mode=local; local_policy=required; container_policy=forbidden; remote_policy=forbidden; container_identity=not-applicable; ansible_connection=local
    users='[{"name":"localuser","home":"'"${FIXTURE_HOME}"'","chezmoi_source":"'"${FIXTURE_SOURCE}"'","groups":["sudo"]}]'
    ;;
  missing-connection)
    profile=remote-host; connection=; user=remoteuser; home=/remote/microdragon/home/remoteuser; source=/remote/microdragon/home/remoteuser/.local/share/chezmoi
    platform_mode=remote-ssh; local_policy=forbidden; container_policy=forbidden; remote_policy=required; container_identity=not-applicable; ansible_connection=ssh
    users='[{"name":"remoteuser","groups":["sudo"],"home":"/remote/microdragon/home/remoteuser","chezmoi_source":"/remote/microdragon/home/remoteuser/.local/share/chezmoi"}]'
    ;;
  missing-source)
    profile=local-profile; connection=local; user=localuser; home="${FIXTURE_HOME}"; source=
    platform_mode=local; local_policy=required; container_policy=forbidden; remote_policy=forbidden; container_identity=not-applicable; ansible_connection=local
    users='[{"name":"localuser","home":"'"${FIXTURE_HOME}"'","chezmoi_source":"","groups":["sudo"]}]'
    ;;
  policy-drift)
    profile=remote-host; connection=ssh; user=remoteuser; home=/remote/microdragon/home/remoteuser; source=/remote/microdragon/home/remoteuser/.local/share/chezmoi
    platform_mode=remote-ssh; local_policy=required; container_policy=forbidden; remote_policy=required; container_identity=not-applicable; ansible_connection=ssh
    users='[{"name":"remoteuser","groups":["sudo"],"home":"/remote/microdragon/home/remoteuser","chezmoi_source":"/remote/microdragon/home/remoteuser/.local/share/chezmoi"}]'
    ;;
  dot-path)
    profile=remote-host; connection=ssh; user=remoteuser; home=/tmp/../root; source=/tmp/../root/.local/share/chezmoi
    platform_mode=remote-ssh; local_policy=forbidden; container_policy=forbidden; remote_policy=required; container_identity=not-applicable; ansible_connection=ssh
    users='[{"name":"remoteuser","groups":["sudo"],"home":"/tmp/../root","chezmoi_source":"/tmp/../root/.local/share/chezmoi"}]'
    ;;
  repeated-slash)
    profile=remote-host; connection=ssh; user=remoteuser; home=/remote//microdragon/home/remoteuser; source=/remote//microdragon/home/remoteuser/.local/share/chezmoi
    platform_mode=remote-ssh; local_policy=forbidden; container_policy=forbidden; remote_policy=required; container_identity=not-applicable; ansible_connection=ssh
    users='[{"name":"remoteuser","groups":["sudo"],"home":"/remote//microdragon/home/remoteuser","chezmoi_source":"/remote//microdragon/home/remoteuser/.local/share/chezmoi"}]'
    ;;
  trailing-slash)
    profile=remote-host; connection=ssh; user=remoteuser; home=/remote/microdragon/home/remoteuser/; source=/remote/microdragon/home/remoteuser/.local/share/chezmoi/
    platform_mode=remote-ssh; local_policy=forbidden; container_policy=forbidden; remote_policy=required; container_identity=not-applicable; ansible_connection=ssh
    users='[{"name":"remoteuser","groups":["sudo"],"home":"/remote/microdragon/home/remoteuser/","chezmoi_source":"/remote/microdragon/home/remoteuser/.local/share/chezmoi/"}]'
    ;;
  symlink-home|symlink-source)
    profile=remote-host; connection=ssh; user=remoteuser; home="${FIXTURE_HOME}"; source="${FIXTURE_SOURCE}"
    platform_mode=remote-ssh; local_policy=forbidden; container_policy=forbidden; remote_policy=required; container_identity=not-applicable; ansible_connection=ssh
    users='[{"name":"remoteuser","groups":["sudo"],"home":"'"${FIXTURE_HOME}"'","chezmoi_source":"'"${FIXTURE_SOURCE}"'"}]'
    ;;
  *)
    profile=remote-host; connection=ssh; user=remoteuser; home=/remote/microdragon/home/remoteuser; source=/remote/microdragon/home/remoteuser/.local/share/chezmoi
    platform_mode=remote-ssh; local_policy=forbidden; container_policy=forbidden; remote_policy=required; container_identity=not-applicable; ansible_connection=ssh
    users='[{"name":"remoteuser","groups":["sudo"],"home":"/remote/microdragon/home/remoteuser","chezmoi_source":"/remote/microdragon/home/remoteuser/.local/share/chezmoi"}]'
    ;;
esac
printf '{"target_profile":"%s","target_connection":"%s","target_home":"%s","target_source":"%s","platform_connection_mode":"%s","platform_local_connection_policy":"%s","platform_container_policy":"%s","platform_remote_connection_policy":"%s","platform_container_identity":"%s","platform_controller_home_policy":"forbidden","platform_unsupported_combination_policy":"reject","platform_generic_family_fallback":"forbidden","ansible_connection":"%s","managed_users":%s}\n' "$profile" "$connection" "$home" "$source" "$platform_mode" "$local_policy" "$container_policy" "$remote_policy" "$container_identity" "$ansible_connection" "$users"
EOF
  chmod +x "$MOCK_DIR/ansible-inventory"

  cat >"$MOCK_DIR/ansible-playbook" <<'EOF'
#!/usr/bin/env bash
printf 'ansible-playbook' >>"${COMMAND_LOG}"
printf ' %q' "$@" >>"${COMMAND_LOG}"
printf '\n' >>"${COMMAND_LOG}"
for arg in "$@"; do
  if [[ "$arg" == */sync.json ]]; then
    cp "$arg" "${COMMAND_LOG}.payload"
    exit "${REMOTE_SYNC_STATUS:-0}"
  fi
done
EOF
  chmod +x "$MOCK_DIR/ansible-playbook"

  cat >"$MOCK_DIR/ansible" <<'EOF'
#!/usr/bin/env bash
printf 'ansible' >>"${COMMAND_LOG}"
printf ' %q' "$@" >>"${COMMAND_LOG}"
printf '\n' >>"${COMMAND_LOG}"
if [[ "${REMOTE_PATH_STATUS:-0}" != 0 ]]; then
  echo 'target_home resolves through a symlink' >&2
  exit "$REMOTE_PATH_STATUS"
fi
EOF
  chmod +x "$MOCK_DIR/ansible"

  cat >"$MOCK_DIR/chezmoi" <<'EOF'
#!/usr/bin/env bash
if [[ "${CHEZMOI_MODE:-}" == fail ]]; then
  exit 42
fi
printf 'chezmoi' >>"${COMMAND_LOG}"
printf ' %q' "$@" >>"${COMMAND_LOG}"
printf '\n' >>"${COMMAND_LOG}"
EOF
  chmod +x "$MOCK_DIR/chezmoi"

  cat >"$SYNC_COMMAND" <<'EOF'
#!/usr/bin/env bash
printf 'chezmoi-sync' >>"${COMMAND_LOG}"
printf ' %q' "$@" >>"${COMMAND_LOG}"
printf '\n' >>"${COMMAND_LOG}"
while [[ $# -gt 0 ]]; do
  if [[ "$1" == --source-dir ]]; then
    printf '%s' "$2" >"${COMMAND_LOG}.validation"
    [[ "${SYNC_STATUS:-0}" == 0 ]] || exit "$SYNC_STATUS"
    mkdir -p "$2"
    printf 'isolated fixture\n' >"$2/dot_fixture"
    break
  fi
  shift
done
EOF
  chmod +x "$SYNC_COMMAND"

  export COMMAND_LOG="$LOG"
}

teardown() {
  [[ -d "${TEST_ROOT:-}" ]] && rm -rf "$TEST_ROOT"
}

run_install() {
  local mode="$1"
  local host="$2"
  local user="${3:-}"
  shift 3 || true
  local operation=--user-only
  local option
  for option in "$@"; do
    [[ "$option" == --system-only ]] && operation=--system-only
  done
  local args=(--host "$host" "$operation")
  [[ -n "$user" ]] && args+=(--user "$user")
  for option in "$@"; do
    [[ "$option" != --system-only && "$option" != --user-only ]] && args+=("$option")
  done
  run env HOME="$TARGET_HOME" FIXTURE_HOME="$TARGET_HOME" FIXTURE_SOURCE="$TARGET_SOURCE" \
    INVENTORY_MODE="$mode" CHEZMOI_MODE="${CHEZMOI_MODE:-}" DOTFILES_CHEZMOI_SYNC="$SYNC_COMMAND" \
    PATH="$MOCK_DIR:$PATH" "$INSTALL" "${args[@]}"
}

@test "requires an explicit host for managed target binding" {
  run env HOME="$TARGET_HOME" PATH="$MOCK_DIR:$PATH" "$INSTALL" --user localuser --user-only

  [ "$status" -ne 0 ]
  [ ! -s "$LOG" ]
  [[ "$output" == *"--host"* ]]
}

@test "rejects an explicitly empty connection before inventory resolution" {
  run_install local local-profile localuser --connection "" --system-only

  [ "$status" -eq 2 ]
  [ ! -s "$LOG" ]
  [[ "$output" == *"--connection requires a non-empty value"* ]]
}

@test "rejects empty target tuple values before inventory resolution" {
  for option in --target --home --source-dir; do
    run_install local local-profile localuser "$option" "" --system-only

    [ "$status" -eq 2 ]
    [ ! -s "$LOG" ]
    [[ "$output" == *"${option} requires a non-empty value"* ]]
  done
}

@test "rejects noncanonical remote inventory paths before mutation" {
  run_install dot-path microdragon remoteuser --system-only

  [ "$status" -ne 0 ]
  [ ! -s "$LOG" ]
  [[ "$output" == *"dot path components"* ]]
}

@test "rejects repeated slash and trailing slash inventory paths" {
  for mode in repeated-slash trailing-slash; do
    run_install "$mode" microdragon remoteuser --system-only

    [ "$status" -ne 0 ]
    [ ! -s "$LOG" ]
    [[ "$output" == *"lexically canonical"* ]]
  done
}

@test "SSH paths ignore controller symlinks and require the target filesystem check" {
  real_home="$TEST_ROOT/real-home"
  mkdir -p "$real_home"
  rm -rf "$TARGET_HOME"
  ln -s "$real_home" "$TARGET_HOME"

  run_install symlink-home microdragon remoteuser --system-only
  [ "$status" -eq 0 ]
  [[ "$(<"$LOG")" == *"ansible.builtin.script"*"check-paths"* ]]

  : >"$LOG"
  REMOTE_PATH_STATUS=42 run_install symlink-home microdragon remoteuser --system-only
  [ "$status" -eq 42 ]
  [[ "$(<"$LOG")" != *"ansible-playbook"* ]]

  rm -f "$TARGET_HOME"
  mkdir -p "$TARGET_HOME/.local/share" "$TEST_ROOT/real-source"
  ln -s "$TEST_ROOT/real-source" "$TARGET_SOURCE"

  : >"$LOG"
  REMOTE_PATH_STATUS=42 run_install symlink-source microdragon remoteuser --system-only
  [ "$status" -eq 42 ]
  [[ "$(<"$LOG")" != *"ansible-playbook"* ]]
  [[ "$output" == *"resolves through a symlink"* ]]
}

@test "rejects missing host and user values before inventory resolution" {
  run env HOME="$TARGET_HOME" PATH="$MOCK_DIR:$PATH" "$INSTALL" --host --user localuser --user-only
  [ "$status" -eq 2 ]
  [ ! -s "$LOG" ]
  [[ "$output" == *"--host requires a non-empty value"* ]]

  run env HOME="$TARGET_HOME" PATH="$MOCK_DIR:$PATH" "$INSTALL" --host
  [ "$status" -eq 2 ]
  [ ! -s "$LOG" ]
  [[ "$output" == *"--host requires a non-empty value"* ]]

  run env HOME="$TARGET_HOME" PATH="$MOCK_DIR:$PATH" "$INSTALL" --host local-profile --user --user-only
  [ "$status" -eq 2 ]
  [ ! -s "$LOG" ]
  [[ "$output" == *"--user requires a non-empty value"* ]]

  run env HOME="$TARGET_HOME" PATH="$MOCK_DIR:$PATH" "$INSTALL" --host local-profile --user
  [ "$status" -eq 2 ]
  [ ! -s "$LOG" ]
  [[ "$output" == *"--user requires a non-empty value"* ]]
}

@test "binds a local profile to one user home source and local connection" {
  run_install local local-profile localuser --target local-profile --connection local --system-only

  [ "$status" -eq 0 ]
  [[ "$(<"$LOG")" == *"ansible-playbook"* && "$(<"$LOG")" == *"--connection local"* ]]
  [[ "$(<"$LOG")" == *"dotfiles_target_profile=local-profile"* ]]
  [[ "$(<"$LOG")" == *"dotfiles_target_user=localuser"* ]]
  [[ "$(<"$LOG")" == *"dotfiles_target_home=$TARGET_HOME"* ]]
  [[ "$(<"$LOG")" == *"dotfiles_target_source=$TARGET_SOURCE"* ]]
  [[ "$(<"$LOG")" == *"dotfiles_target_connection=local"* ]]
}

@test "binds opencode-runtime as an explicit local container" {
  run_install container opencode-runtime coder --target container --connection local --system-only

  [ "$status" -eq 0 ]
  [[ "$(<"$LOG")" == *"ansible-playbook"* && "$(<"$LOG")" == *"--connection local"* ]]
  [[ "$(<"$LOG")" == *"dotfiles_target_profile=container"* ]]
  [[ "$(<"$LOG")" == *"dotfiles_target_user=coder"* ]]
}

@test "remote user convergence preserves the controller home sentinel" {
  sentinel="$TARGET_HOME/controller-sentinel"
  printf 'preserve-me\n' >"$sentinel"

  run_install remote microdragon remoteuser --target remote-host --connection ssh

  [ "$status" -eq 0 ]
  [ "$(<"$sentinel")" = "preserve-me" ]
  [[ "$(<"$LOG")" == *"ansible-playbook"*"sync.json"* ]]
  run python3 - "$LOG.payload" <<'PY'
import json, pathlib, sys
play, = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert play['become_user'] == 'remoteuser'
assert play['environment']['HOME'] == '/remote/microdragon/home/remoteuser'
stage, transaction = play['tasks']
assert stage['ansible.builtin.tempfile']['state'] == 'directory'
unpack, check, sync, apply = transaction['block']
archive = unpack['ansible.builtin.unarchive']
assert archive['extra_opts'] == ['--same-permissions', '--no-same-owner']
assert archive['remote_src'] is False
assert archive['dest'] == '{{ dotfiles_remote_stage.path }}/'
assert not pathlib.Path(archive['src']).exists()  # controller staging cleaned
assert 'check-paths' in check['ansible.builtin.command']['argv']
assert sync['ansible.builtin.command']['argv'][-1] == '/remote/microdragon/home/remoteuser/.local/share/chezmoi'
assert sync['ansible.builtin.command']['argv'][1].endswith('/infra/chezmoi/bin/chezmoi-sync')
assert apply['ansible.builtin.command']['argv'][-1] == 'apply'
cleanup, = transaction['always']
cleanup_argv = cleanup['ansible.builtin.command']['argv']
assert cleanup_argv[:2] == ['python3', '-c']
assert cleanup_argv[-1] == '{{ dotfiles_remote_stage.path }}'
assert 'followlinks=False' in cleanup_argv[2]
PY
  [ "$status" -eq 0 ]
  [[ "$(<"$LOG")" != *"chezmoi --source"* ]]
}

@test "remote execution failure propagates and cleans controller payload staging" {
  REMOTE_SYNC_STATUS=42 run_install remote microdragon remoteuser
  [ "$status" -eq 42 ]
  [ ! -e "$TARGET_SOURCE" ]
  run python3 - "$LOG.payload" <<'PY'
import json, pathlib, sys
play, = json.loads(pathlib.Path(sys.argv[1]).read_text())
copy = play['tasks'][1]['block'][0]['ansible.builtin.unarchive']
assert not pathlib.Path(copy['src']).exists()
PY
  [ "$status" -eq 0 ]
}

@test "failed local payload preflight prevents transfer and cleans controller staging" {
  SYNC_STATUS=43 run_install remote microdragon remoteuser
  [ "$status" -eq 43 ]
  [[ "$(<"$LOG")" != *"ansible-playbook"* ]]
  [ ! -e "$(<"$LOG.validation")" ]
  [ ! -e "$TARGET_SOURCE" ]
}

@test "local dry-run binds chezmoi to an isolated source and selected home" {
  run_install local local-profile localuser --target local-profile --connection local --dry-run

  [ "$status" -eq 0 ]
  [ ! -e "$TARGET_SOURCE" ]
  [[ "$(<"$LOG")" == *"chezmoi-sync --host local-profile --source-dir ${TMP_ROOT}/dotfiles-chezmoi-dry-run."* ]]
  [[ "$(<"$LOG")" == *"chezmoi --source ${TMP_ROOT}/dotfiles-chezmoi-dry-run."* ]]
  [[ "$(<"$LOG")" == *"--destination $TARGET_HOME diff"* ]]
}

@test "surfaces a local dry-run chezmoi failure" {
  CHEZMOI_MODE=fail run_install local local-profile localuser --target local-profile --connection local --dry-run

  [ "$status" -eq 42 ]
  [[ "$output" != *"User state previewed"* ]]
}

@test "same-host hostname does not override a remote inventory connection" {
  cat >"$MOCK_DIR/hostname" <<'EOF'
#!/usr/bin/env bash
printf 'microdragon\n'
EOF
  chmod +x "$MOCK_DIR/hostname"

  run env PATH="$MOCK_DIR:$PATH" "$WRAPPER" playbooks/site.yml --limit microdragon --extra-vars "$REMOTE_TUPLE"

  [ "$status" -eq 0 ]
  [[ "$(<"$LOG")" == *"--connection=ssh"* ]]
  [[ "$(<"$LOG")" != *"--connection=local"* ]]
}

@test "rejects root as the managed user before mutation" {
  run_install root local-profile root --target local-profile --connection local

  [ "$status" -ne 0 ]
  [ ! -s "$LOG" ]
  [[ "$output" == *"root"* ]]
}

@test "requires an explicit user when managed_users is ambiguous" {
  run_install ambiguous local-profile ""

  [ "$status" -ne 0 ]
  [ ! -s "$LOG" ]
  [[ "$output" == *"--user"* ]]
}

@test "explicit user selection isolates one of several managed users" {
  run_install ambiguous local-profile one --system-only

  [ "$status" -eq 0 ]
  [[ "$(<"$LOG")" == *"dotfiles_target_user=one"* ]]
  [[ "$(<"$LOG")" != *"dotfiles_target_user=two"* ]]
}

@test "rejects duplicate selected managed users" {
  run_install duplicate local-profile one

  [ "$status" -ne 0 ]
  [ ! -s "$LOG" ]
  [[ "$output" == *"target tuple"* || "$output" == *"unique"* ]]
}

@test "rejects a connection mismatch before mutation" {
  run_install local local-profile localuser --target local-profile --connection ssh

  [ "$status" -ne 0 ]
  [ ! -s "$LOG" ]
  [[ "$output" == *"connection"* ]]
}

@test "rejects an alternate configured chezmoi source" {
  mkdir -p "$TARGET_HOME/.config/chezmoi"
  printf 'sourceDir = "%s"\n' "$TEST_ROOT/alternate-source" >"$TARGET_HOME/.config/chezmoi/chezmoi.toml"

  run_install local local-profile localuser --target local-profile --connection local

  [ "$status" -ne 0 ]
  [ ! -s "$LOG" ]
  [[ "$output" == *"source"* ]]
}

@test "rejects an explicit source mismatch" {
  run_install local local-profile localuser --target local-profile --connection local --source-dir "$TEST_ROOT/alternate-source"

  [ "$status" -ne 0 ]
  [ ! -s "$LOG" ]
  [[ "$output" == *"source"* ]]
}

@test "rejects missing required inventory tuple fields" {
  run_install missing-profile local-profile localuser

  [ "$status" -ne 0 ]
  [ ! -s "$LOG" ]
  [[ "$output" == *"target_profile"* || "$output" == *"target tuple"* ]]
}

@test "rejects a missing inventory connection instead of synthesizing one" {
  run_install missing-connection microdragon remoteuser

  [ "$status" -ne 0 ]
  [ ! -s "$LOG" ]
  [[ "$output" == *"target_connection"* || "$output" == *"target tuple"* ]]
}

@test "rejects a missing inventory source instead of synthesizing one" {
  run_install missing-source local-profile localuser

  [ "$status" -ne 0 ]
  [ ! -s "$LOG" ]
  [[ "$output" == *"target_source"* || "$output" == *"target tuple"* ]]
}

@test "rejects drifted platform connection policies" {
  run_install policy-drift microdragon remoteuser

  [ "$status" -ne 0 ]
  [ ! -s "$LOG" ]
  [[ "$output" == *"platform policy"* || "$output" == *"target tuple"* ]]
}

@test "rejects an unknown host before mutation" {
  run_install unknown does-not-exist localuser --target remote-host --connection ssh

  [ "$status" -ne 0 ]
  [ ! -s "$LOG" ]
  [[ "$output" == *"managed user"* || "$output" == *"host"* ]]
}

@test "accounts consumer acts only on the selected managed user" {
  accounts="$REPOSITORY_ROOT/infra/ansible/roles/users/tasks/accounts.yml"
  content="$(<"$accounts")"

  [[ "$content" == *"dotfiles_target_user"* ]]
  [[ "$content" == *"selected_managed_users[0].name"* ]]
  [[ "$content" != *'loop: "{{ managed_users }}"'* ]]
}
