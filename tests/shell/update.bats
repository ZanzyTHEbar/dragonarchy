#!/usr/bin/env bats

setup() {
  ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  TEST_ROOT="$(mktemp -d)"
  export HOME="$TEST_ROOT/home" COMMAND_LOG="$TEST_ROOT/calls" INVENTORY_LOG="$TEST_ROOT/inventory"
  export DOTFILES_CHEZMOI_SYNC="$TEST_ROOT/bin/chezmoi-sync"
  export PATH="$TEST_ROOT/bin:$PATH"
  mkdir -p "$TEST_ROOT/bin" "$HOME"
  cat >"$TEST_ROOT/bin/ansible-inventory" <<'EOF'
#!/usr/bin/env python3
import json, os
with open(os.environ['INVENTORY_LOG'], 'a') as log:
    log.write('inventory\n')
profile = os.environ.get('PROFILE', 'local-profile')
remote = profile == 'remote-host'
container = profile == 'container'
home = '/remote/home/testuser' if remote else os.environ['HOME']
source = home + '/.local/share/chezmoi'
print(json.dumps(dict(
    host_desktop_stack='none',
    target_profile=profile, target_connection='ssh' if remote else 'local',
    target_home=home, target_source=source,
    platform_connection_mode='remote-ssh' if remote else 'local',
    platform_local_connection_policy='forbidden' if remote else 'required',
    platform_remote_connection_policy='required' if remote else 'forbidden',
    platform_container_policy='required' if container else 'forbidden',
    platform_container_identity='declared-local-container' if container else 'not-applicable',
    platform_controller_home_policy='forbidden', platform_unsupported_combination_policy='reject',
    platform_generic_family_fallback='forbidden',
    managed_users=[dict(name='testuser', home=home, chezmoi_source=source)])))
EOF
  cat >"$TEST_ROOT/bin/ansible-playbook" <<'EOF'
#!/usr/bin/env bash
printf 'playbook %s\n' "$*" >>"$COMMAND_LOG"
for arg in "$@"; do
  [[ "$arg" != */sync.json ]] || cp "$arg" "$COMMAND_LOG.payload"
done
exit "${PACKAGE_STATUS:-0}"
EOF
  for cmd in ansible chezmoi chezmoi-sync sudo apt-get pacman paru git; do
    cat >"$TEST_ROOT/bin/$cmd" <<'EOF'
#!/usr/bin/env bash
printf '%s %s\n' "${0##*/}" "$*" >>"$COMMAND_LOG"
case "${0##*/}" in sudo|apt-get|pacman|paru|git) exit 99;; esac
EOF
  done
  cat >"$TEST_ROOT/bin/systemd-detect-virt" <<'EOF'
#!/usr/bin/env bash
exit "${CONTAINER_STATUS:-0}"
EOF
  chmod +x "$TEST_ROOT/bin/"*
}

teardown() {
  rm -rf "$TEST_ROOT"
}

update() {
  run "$ROOT/install" --update --host "${HOST_NAME:-fixture}" --user testuser "$@"
}

@test "update dispatches all three profiles to upgrades then declared user convergence" {
  for profile in local-profile remote-host container; do
    export PROFILE="$profile"
    HOST_NAME=fixture
    [[ "$profile" != container ]] || HOST_NAME=opencode-runtime
    : >"$COMMAND_LOG"
    update
    [ "$status" -eq 0 ]
    calls="$(<"$COMMAND_LOG")"
    [[ "$calls" == *"playbook "*"/playbooks/update.yml"* ]]
    [[ "$calls" == *"dotfiles_target_profile=$profile"* ]]
    [[ "$calls" != *foundation.yml* && "$calls" != *site.yml* ]]
    if [[ "$profile" == remote-host ]]; then
      [[ "$calls" == *"--connection ssh"* && "$calls" == *"--become-user root"* ]]
      [[ "$calls" == *"/remote/home/testuser/.local/share/chezmoi"* ]]
      [[ "$calls" == *"sync.json"* ]]
      [[ "$(<"$COMMAND_LOG.payload")" == *"chezmoi-sync"* ]]
    else
      [[ "$calls" == *"chezmoi-sync --host $HOST_NAME --source-dir "* ]]
      [[ "$calls" == *"--connection local"* ]]
      [[ "$calls" == *"chezmoi --source $HOME/.local/share/chezmoi --destination $HOME apply"* ]]
    fi
  done
}

@test "update dry-run reports scoped plans without execution or source promotion" {
  for profile in local-profile remote-host container; do
    export PROFILE="$profile"
    HOST_NAME=fixture
    [[ "$profile" != container ]] || HOST_NAME=opencode-runtime
    for scope in all system user; do
      args=(--dry-run)
      [[ "$scope" != system ]] || args+=(--system-only)
      [[ "$scope" != user ]] || args+=(--user-only)
      update "${args[@]}"
      [ "$status" -eq 0 ]
      [[ "$output" == *"Update plan"* ]]
      if [[ "$scope" != user ]]; then [[ "$output" == *"update.yml"* ]]; fi
      if [[ "$scope" != system ]]; then [[ "$output" == *"chezmoi"* ]]; fi
      [ ! -s "$COMMAND_LOG" ]
      [ ! -e "$HOME/.local/share/chezmoi" ]
    done
  done
}

@test "package failure stops update before user convergence" {
  export PACKAGE_STATUS=42
  for profile in local-profile remote-host container; do
    export PROFILE="$profile"
    HOST_NAME=fixture
    [[ "$profile" != container ]] || HOST_NAME=opencode-runtime
    : >"$COMMAND_LOG"
    update
    [ "$status" -eq 42 ]
    [[ "$(<"$COMMAND_LOG")" == *update.yml* ]]
    [[ "$(<"$COMMAND_LOG")" != *chezmoi-sync* ]]
    [[ "$(<"$COMMAND_LOG")" != *$'\nansible '* ]]
  done
}

@test "normal install invokes site once then user convergence (site imports foundation)" {
  run "$ROOT/install" --host fixture --user testuser
  [ "$status" -eq 0 ]
  calls="$(<"$COMMAND_LOG")"
  [[ "$calls" == "playbook "*site.yml*"chezmoi-sync "*"chezmoi "* ]]
  [[ "$calls" != *foundation.yml* ]]
  [[ "$calls" != *update.yml* ]]
}

@test "update scopes exclude the other owner and user-only needs no package sudo" {
  update --system-only
  [ "$status" -eq 0 ]
  [[ "$(<"$COMMAND_LOG")" != *chezmoi-sync* ]]
  : >"$COMMAND_LOG"
  update --user-only
  [ "$status" -eq 0 ]
  [[ "$(<"$COMMAND_LOG")" == "chezmoi-sync "* ]]
  [[ "$(<"$COMMAND_LOG")" != *playbook* && "$(<"$COMMAND_LOG")" != *sudo* ]]
}

@test "invalid scopes and nonliteral hosts fail before inventory or execution" {
  update --system-only --user-only
  [ "$status" -ne 0 ]
  [[ "$output" == *"mutually exclusive"* ]]
  [ ! -e "$INVENTORY_LOG" ]
  for host in 'all:*' 'fixture,other' '@hosts' 'fixture[0]' 'fixture other' '../fixture'; do
    HOST_NAME="$host" update
    [ "$status" -ne 0 ]
    [[ "$output" == *"literal"* ]]
    [ ! -e "$INVENTORY_LOG" ]
  done
  [ ! -s "$COMMAND_LOG" ]
}

@test "tuple mismatches fail after inventory but before any execution" {
  for args in '--connection ssh' '--target remote-host' '--home /wrong' '--source-dir /wrong' '--user unknown'; do
    read -r -a options <<<"$args"
    update "${options[@]}"
    [ "$status" -ne 0 ]
    [[ "$output" != *"Unknown option"* ]]
    [ -s "$INVENTORY_LOG" ]
    [ ! -s "$COMMAND_LOG" ]
  done
}

@test "container update outside a container fails closed including user-only and dry-run" {
  export PROFILE=container CONTAINER_STATUS=1
  HOST_NAME=opencode-runtime
  for scope in --system-only --user-only --dry-run; do
    update "$scope"
    [ "$status" -ne 0 ]
    [[ "$output" == *"requires execution inside a detected container"* ]]
    [ ! -s "$COMMAND_LOG" ]
  done
}

@test "update wrapper enforces the site tuple and extra-vars restrictions" {
  tuple="dotfiles_target_profile=local-profile dotfiles_target_user=testuser dotfiles_target_home=$HOME dotfiles_target_source=$HOME/.local/share/chezmoi dotfiles_target_connection=local"
  wrapper="$ROOT/infra/ansible/run-playbook.sh"
  run "$wrapper" playbooks/update.yml --limit fixture --extra-vars "$tuple"
  [ "$status" -eq 0 ]
  for extra in 'ansible_connection=ssh' 'other=value' '@vars.yml' '{"x":1}'; do
    : >"$COMMAND_LOG"
    run "$wrapper" playbooks/update.yml --limit fixture --extra-vars "$tuple" -e "$extra"
    [ "$status" -ne 0 ]
    [ ! -s "$COMMAND_LOG" ]
  done
  run "$wrapper" playbooks/update.yml --limit fixture
  [ "$status" -ne 0 ]
  run "$wrapper" playbooks/update.yml --limit fixture --extra-vars "${tuple/testuser/unknown}"
  [ "$status" -ne 0 ]
  run "$wrapper" playbooks/update.yml --extra-vars "$tuple"
  [ "$status" -ne 0 ]
  run "$wrapper" playbooks/update.yml --limit fixture --connection ssh --extra-vars "$tuple"
  [ "$status" -ne 0 ]
  run "$wrapper" playbooks/update.yml --limit 'fixture:*' --extra-vars "$tuple"
  [ "$status" -ne 0 ]
  [ ! -s "$COMMAND_LOG" ]
}

@test "upgrade structure preserves target identity package selection and safety gates (not live proof)" {
  run python3 - "$ROOT" <<'PY'
import pathlib, sys, yaml
root = pathlib.Path(sys.argv[1]) / 'infra/ansible'
play, = yaml.safe_load((root / 'playbooks/update.yml').read_text())
assert play['gather_facts'] and play['any_errors_fatal']
assert 'roles' not in play and 'import_playbook' not in play
assert play['pre_tasks'][0]['ansible.builtin.import_role'] == {'name': 'common', 'tasks_from': 'contract'}
assert all('ansible.builtin.assert' in t for t in yaml.safe_load(
    (root / 'roles/common/tasks/contract.yml').read_text()))
tasks = yaml.safe_load((root / 'roles/packages/tasks/upgrade.yml').read_text())
text = (root / 'roles/packages/tasks/upgrade.yml').read_text()
assert 'host_platform_family' in text and 'ansible_os_family' in text
assert 'ansible_virtualization_type' in text
debian = next(t for t in tasks if t.get('when') == "host_platform_family == 'debian'")
assert debian['become'] and debian['become_user'] == 'root'
assert [t['ansible.builtin.command']['argv'] for t in debian['block']] == [
    ['apt-get', 'update'], ['apt-get', 'upgrade', '-y']]
arch = next(t for t in tasks if t.get('when') == "host_platform_family == 'arch'")
assert arch['become'] and arch['become_user'] == '{{ dotfiles_target_user }}'
assert arch['environment']['HOME'] == '{{ dotfiles_target_home }}'
block = arch['block']
commands = [t.get('ansible.builtin.command', {}).get('argv') for t in block]
sudo = commands.index(['sudo', '-n', 'true'])
paru = commands.index(['{{ upgrade_paru.stdout }}', '-Syu', '--noconfirm'])
foreign = commands.index(['pacman', '-Qmq'])
pacman = commands.index(['pacman', '-Syu', '--noconfirm'])
assert sudo < paru and foreign < pacman
assert block[paru]['when'] == 'upgrade_paru.rc == 0'
assert block[sudo]['when'] == 'upgrade_paru.rc == 0'
assert block[foreign]['when'] == 'upgrade_paru.rc == 1'
assert block[pacman]['when'] == 'upgrade_paru.rc == 1'
assert block[pacman]['become_user'] == 'root'
assert any('upgrade_foreign.stdout' in str(t.get('ansible.builtin.assert')) for t in block[foreign:pacman])
assert any('upgrade_uid.stdout' in str(t.get('ansible.builtin.assert')) for t in block[:sudo])
for t in [debian['block'][0], debian['block'][1], block[paru], block[pacman]]:
    assert not t.get('check_mode') is False
assert not any(word in text for word in ['autoremove', 'reboot', 'dist-upgrade', 'with-new-pkgs'])
PY
  [ "$status" -eq 0 ]
}
