#!/usr/bin/env bats
#
# run-playbook.bats - Tests for the Ansible playbook wrapper's inventory-bound
# connection behavior.
#

setup() {
  WRAPPER="${BATS_TEST_DIRNAME}/../../infra/ansible/run-playbook.sh"
  MOCK_DIR="$(mktemp -d)"

  # Create a mock ansible-playbook that echoes its arguments
  cat >"${MOCK_DIR}/ansible-playbook" <<'EOF'
#!/usr/bin/env bash
echo "ANSIBLE_PLAYBOOK_ARGS: $*"
EOF
  chmod +x "${MOCK_DIR}/ansible-playbook"

  cat >"${MOCK_DIR}/ansible-inventory" <<'EOF'
#!/usr/bin/env bash
host=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)
      host="${2:-}"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
case "$host" in
  microdragon)
    printf '%s\n' '{"target_profile":"remote-host","target_connection":"ssh","target_home":"/remote/microdragon/home/remoteuser","target_source":"/remote/microdragon/home/remoteuser/.local/share/chezmoi","managed_users":[{"name":"remoteuser","home":"/remote/microdragon/home/remoteuser","chezmoi_source":"/remote/microdragon/home/remoteuser/.local/share/chezmoi"}]}'
    ;;
  localhost|127.0.0.1)
    printf '%s\n' '{"target_profile":"local-profile","target_connection":"local","target_home":"/home/localuser","target_source":"/home/localuser/.local/share/chezmoi","managed_users":[{"name":"localuser","home":"/home/localuser","chezmoi_source":"/home/localuser/.local/share/chezmoi"}]}'
    ;;
  managed-no-contract)
    printf '%s\n' '{"target_profile":"remote-host","target_home":"/remote/microdragon/home/remoteuser","target_source":"/remote/microdragon/home/remoteuser/.local/share/chezmoi","managed_users":[{"name":"remoteuser","home":"/remote/microdragon/home/remoteuser","chezmoi_source":"/remote/microdragon/home/remoteuser/.local/share/chezmoi"}]}'
    ;;
  *)
    exit 1
    ;;
esac
EOF
  chmod +x "${MOCK_DIR}/ansible-inventory"

  REMOTE_TUPLE="dotfiles_target_profile=remote-host dotfiles_target_user=remoteuser dotfiles_target_home=/remote/microdragon/home/remoteuser dotfiles_target_source=/remote/microdragon/home/remoteuser/.local/share/chezmoi dotfiles_target_connection=ssh"
  LOCAL_TUPLE="dotfiles_target_profile=local-profile dotfiles_target_user=localuser dotfiles_target_home=/home/localuser dotfiles_target_source=/home/localuser/.local/share/chezmoi dotfiles_target_connection=local"

  # Prepend mock to PATH so the wrapper calls it
  export PATH="${MOCK_DIR}:${PATH}"

}

teardown() {
  [[ -d "${MOCK_DIR:-}" ]] && rm -rf "$MOCK_DIR"
}

# ---------------------------------------------------------------------------
# Inventory-first connection selection
# ---------------------------------------------------------------------------

@test "inventory remote connection wins when hostname matches the target" {
  cat >"${MOCK_DIR}/hostname" <<'EOF'
#!/usr/bin/env bash
printf 'microdragon\n'
EOF
  chmod +x "${MOCK_DIR}/hostname"

  run env PATH="${MOCK_DIR}:${PATH}" "${WRAPPER}" playbooks/site.yml --limit microdragon --user remoteuser --extra-vars "$REMOTE_TUPLE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"--connection=ssh"* ]]
  [[ "$output" == *"dotfiles_target_user=remoteuser"* ]]
  [[ "$output" != *"--connection=local"* ]]
}

@test "preserves explicit local behavior for localhost" {
  run "${WRAPPER}" playbooks/site.yml --limit localhost --connection local --user localuser --extra-vars "$LOCAL_TUPLE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"--connection local"* ]]
}

@test "preserves explicit local behavior for 127.0.0.1" {
  run "${WRAPPER}" playbooks/site.yml --limit 127.0.0.1 --connection local --user localuser --extra-vars "$LOCAL_TUPLE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"--connection local"* ]]
}

@test "rejects a limited site without a selected user" {
  run "${WRAPPER}" playbooks/site.yml --limit microdragon --extra-vars "dotfiles_target_profile=remote-host dotfiles_target_home=/remote/microdragon/home/remoteuser dotfiles_target_source=/remote/microdragon/home/remoteuser/.local/share/chezmoi dotfiles_target_connection=ssh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"dotfiles_target_user"* ]]
  [[ "$output" != *"ANSIBLE_PLAYBOOK_ARGS"* ]]
}

@test "rejects site.yml without --limit" {
  run "${WRAPPER}" playbooks/site.yml --extra-vars "$REMOTE_TUPLE"
  [ "$status" -ne 0 ]
  [[ "$output" == *"site.yml requires a non-empty --limit"* ]]
  [[ "$output" != *"ANSIBLE_PLAYBOOK_ARGS"* ]]
}

@test "rejects localhost without a complete target tuple" {
  run "${WRAPPER}" playbooks/site.yml --limit localhost --user localuser
  [ "$status" -ne 0 ]
  [[ "$output" == *"dotfiles_target_profile"* ]]
}

@test "rejects a missing target tuple field" {
  run "${WRAPPER}" playbooks/site.yml --limit microdragon --extra-vars "dotfiles_target_profile=remote-host dotfiles_target_user=remoteuser dotfiles_target_home=/remote/microdragon/home/remoteuser dotfiles_target_connection=ssh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"dotfiles_target_source"* ]]
}

@test "rejects an unknown selected user" {
  run "${WRAPPER}" playbooks/site.yml --limit microdragon --extra-vars "dotfiles_target_profile=remote-host dotfiles_target_user=ghost dotfiles_target_home=/remote/microdragon/home/remoteuser dotfiles_target_source=/remote/microdragon/home/remoteuser/.local/share/chezmoi dotfiles_target_connection=ssh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"selected managed user is not unique"* ]]
}

@test "rejects a conflicting target profile" {
  run "${WRAPPER}" playbooks/site.yml --limit microdragon --extra-vars "dotfiles_target_profile=local-profile dotfiles_target_user=remoteuser dotfiles_target_home=/remote/microdragon/home/remoteuser dotfiles_target_source=/remote/microdragon/home/remoteuser/.local/share/chezmoi dotfiles_target_connection=ssh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"target profile does not match inventory"* ]]
}

@test "rejects a conflicting target home" {
  run "${WRAPPER}" playbooks/site.yml --limit microdragon --extra-vars "dotfiles_target_profile=remote-host dotfiles_target_user=remoteuser dotfiles_target_home=/wrong/home dotfiles_target_source=/remote/microdragon/home/remoteuser/.local/share/chezmoi dotfiles_target_connection=ssh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"target home does not match inventory"* ]]
}

@test "rejects a conflicting target source" {
  run "${WRAPPER}" playbooks/site.yml --limit microdragon --extra-vars "dotfiles_target_profile=remote-host dotfiles_target_user=remoteuser dotfiles_target_home=/remote/microdragon/home/remoteuser dotfiles_target_source=/wrong/source dotfiles_target_connection=ssh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"target source does not match inventory"* ]]
}

@test "rejects a conflicting target connection" {
  run "${WRAPPER}" playbooks/site.yml --limit microdragon --extra-vars "dotfiles_target_profile=remote-host dotfiles_target_user=remoteuser dotfiles_target_home=/remote/microdragon/home/remoteuser dotfiles_target_source=/remote/microdragon/home/remoteuser/.local/share/chezmoi dotfiles_target_connection=local"
  [ "$status" -ne 0 ]
  [[ "$output" == *"target connection does not match inventory"* ]]
}

@test "rejects structured extra-vars after a valid target tuple" {
  run "${WRAPPER}" playbooks/site.yml --limit microdragon --extra-vars "$REMOTE_TUPLE" --extra-vars '{"dotfiles_target_home":"/wrong"}'
  [ "$status" -ne 0 ]
  [[ "$output" == *"structured or indirect"* ]]
  [[ "$output" != *"ANSIBLE_PLAYBOOK_ARGS"* ]]
}

@test "rejects JSON extra-vars containing equals signs" {
  run "${WRAPPER}" playbooks/site.yml --limit microdragon --extra-vars "$REMOTE_TUPLE" --extra-vars '{"dotfiles_target_home":"x=y"}'
  [ "$status" -ne 0 ]
  [[ "$output" == *"structured or indirect"* ]]
  [[ "$output" != *"ANSIBLE_PLAYBOOK_ARGS"* ]]
}

@test "rejects indirect extra-vars files after a valid target tuple" {
  extra_vars_file="${MOCK_DIR}/extra-vars.yml"
  printf 'dotfiles_target_home: /wrong\n' >"${extra_vars_file}"

  run "${WRAPPER}" playbooks/site.yml --limit microdragon --extra-vars "$REMOTE_TUPLE" --extra-vars "@${extra_vars_file}"
  [ "$status" -ne 0 ]
  [[ "$output" == *"structured or indirect"* ]]
  [[ "$output" != *"ANSIBLE_PLAYBOOK_ARGS"* ]]
}

@test "rejects attached -e@file after a valid target tuple" {
  extra_vars_file="${MOCK_DIR}/attached-extra-vars.yml"
  printf 'dotfiles_target_home: /wrong\n' >"${extra_vars_file}"

  run "${WRAPPER}" playbooks/site.yml --limit microdragon --extra-vars "$REMOTE_TUPLE" "-e@${extra_vars_file}"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Attached -e forms are unsupported"* ]]
  [[ "$output" != *"ANSIBLE_PLAYBOOK_ARGS"* ]]
}

@test "rejects attached -e=@file after a valid target tuple" {
  extra_vars_file="${MOCK_DIR}/attached-equals-extra-vars.yml"
  printf 'dotfiles_target_home: /wrong\n' >"${extra_vars_file}"

  run "${WRAPPER}" playbooks/site.yml --limit microdragon --extra-vars "$REMOTE_TUPLE" "-e=@${extra_vars_file}"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Attached -e forms are unsupported"* ]]
  [[ "$output" != *"ANSIBLE_PLAYBOOK_ARGS"* ]]
}

@test "rejects attached -eKEY=VALUE after a valid target tuple" {
  run "${WRAPPER}" playbooks/site.yml --limit microdragon --extra-vars "$REMOTE_TUPLE" '-edotfiles_target_home=/wrong'
  [ "$status" -eq 2 ]
  [[ "$output" == *"Attached -e forms are unsupported"* ]]
  [[ "$output" != *"ANSIBLE_PLAYBOOK_ARGS"* ]]
}

@test "rejects the clustered -clocal connection option" {
  run "${WRAPPER}" playbooks/site.yml --limit microdragon --extra-vars "$REMOTE_TUPLE" -clocal
  [ "$status" -eq 2 ]
  [[ "$output" == *"Short option clusters containing c, e, l, u, or i are unsupported"* ]]
  [[ "$output" != *"ANSIBLE_PLAYBOOK_ARGS"* ]]
}

@test "rejects the clustered -ve extra-vars option" {
  run "${WRAPPER}" playbooks/site.yml --limit microdragon --extra-vars "$REMOTE_TUPLE" -ve
  [ "$status" -eq 2 ]
  [[ "$output" == *"Short option clusters containing c, e, l, u, or i are unsupported"* ]]
  [[ "$output" != *"ANSIBLE_PLAYBOOK_ARGS"* ]]
}

@test "rejects the clustered -vc connection option" {
  run "${WRAPPER}" playbooks/site.yml --limit microdragon --extra-vars "$REMOTE_TUPLE" -vc
  [ "$status" -eq 2 ]
  [[ "$output" == *"Short option clusters containing c, e, l, u, or i are unsupported"* ]]
  [[ "$output" != *"ANSIBLE_PLAYBOOK_ARGS"* ]]
}

@test "rejects reserved routing and identity extra-vars" {
  for reserved_var in \
    'ansible_connection=local' \
    'ansible_host=localhost' \
    'ansible_user=root' \
    'ansible_become=true' \
    'ansible_become_user=root' \
    'ansible_custom=override' \
    'inventory_hostname=localhost' \
    'groups=all' \
    'hostvars=override' \
    'group_names=all' \
    'inventory_dir=/tmp' \
    'inventory_file=/tmp/hosts' \
    'playbook_dir=/tmp' \
    'role_path=/tmp'; do
    run "${WRAPPER}" playbooks/site.yml --limit microdragon --extra-vars "$REMOTE_TUPLE $reserved_var"
    [ "$status" -eq 2 ]
    [[ "$output" == *"Reserved extra-vars key is not accepted"* ]]
    [[ "$output" != *"ANSIBLE_PLAYBOOK_ARGS"* ]]
  done
}

@test "rejects a newline-hidden reserved extra-var" {
  payload="${REMOTE_TUPLE}"$'\n''ansible_connection=local'
  run "${WRAPPER}" playbooks/site.yml --limit microdragon --extra-vars "$payload"
  [ "$status" -eq 2 ]
  [[ "$output" == *"extra-vars payloads cannot contain newlines"* ]]
  [[ "$output" != *"ANSIBLE_PLAYBOOK_ARGS"* ]]
}

@test "rejects YAML mapping extra-vars after a valid target tuple" {
  run "${WRAPPER}" playbooks/site.yml --limit microdragon --extra-vars "$REMOTE_TUPLE" --extra-vars 'dotfiles_target_home: /wrong'
  [ "$status" -ne 0 ]
  [[ "$output" == *"structured or indirect"* ]]
  [[ "$output" != *"ANSIBLE_PLAYBOOK_ARGS"* ]]
}

@test "rejects YAML mapping extra-vars containing equals signs" {
  run "${WRAPPER}" playbooks/site.yml --limit microdragon --extra-vars "$REMOTE_TUPLE" --extra-vars 'dotfiles_target_home: x=y'
  [ "$status" -ne 0 ]
  [[ "$output" == *"structured or indirect"* ]]
  [[ "$output" != *"ANSIBLE_PLAYBOOK_ARGS"* ]]
}

@test "rejects identical duplicate target fields" {
  run "${WRAPPER}" playbooks/site.yml --limit microdragon --extra-vars "$REMOTE_TUPLE" --extra-vars "dotfiles_target_home=/remote/microdragon/home/remoteuser"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Duplicate target homes"* ]]
  [[ "$output" != *"ANSIBLE_PLAYBOOK_ARGS"* ]]
}

@test "rejects a missing --limit value before inventory execution" {
  run "${WRAPPER}" playbooks/site.yml --limit
  [ "$status" -eq 2 ]
  [[ "$output" == *"--limit requires a non-empty target"* ]]
  [[ "$output" != *"ANSIBLE_PLAYBOOK_ARGS"* ]]
}

@test "rejects an empty --limit= value before inventory execution" {
  run "${WRAPPER}" playbooks/site.yml --limit=
  [ "$status" -eq 2 ]
  [[ "$output" == *"--limit requires a non-empty target"* ]]
  [[ "$output" != *"ANSIBLE_PLAYBOOK_ARGS"* ]]
}

@test "rejects a duplicate --limit before playbook execution" {
  run "${WRAPPER}" playbooks/site.yml --limit microdragon --limit microdragon --extra-vars "$REMOTE_TUPLE"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Duplicate --limit options are not allowed"* ]]
  [[ "$output" != *"ANSIBLE_PLAYBOOK_ARGS"* ]]
}

@test "rejects a short -l alternate target before playbook execution" {
  run "${WRAPPER}" playbooks/site.yml --limit microdragon --extra-vars "$REMOTE_TUPLE" -l opencode-runtime
  [ "$status" -eq 2 ]
  [[ "$output" == *"Short -l options are unsupported"* ]]
  [[ "$output" != *"ANSIBLE_PLAYBOOK_ARGS"* ]]
}

@test "rejects a short -u root override before playbook execution" {
  run "${WRAPPER}" playbooks/site.yml --limit microdragon --extra-vars "$REMOTE_TUPLE" -u root
  [ "$status" -eq 2 ]
  [[ "$output" == *"Short -u options are unsupported"* ]]
  [[ "$output" != *"ANSIBLE_PLAYBOOK_ARGS"* ]]
}

@test "rejects a short -i alternate inventory before playbook execution" {
  run "${WRAPPER}" playbooks/site.yml --limit microdragon --extra-vars "$REMOTE_TUPLE" -i alternate
  [ "$status" -eq 2 ]
  [[ "$output" == *"Short -i options are unsupported"* ]]
  [[ "$output" != *"ANSIBLE_PLAYBOOK_ARGS"* ]]
}

@test "rejects attached short target-affecting options before playbook execution" {
  for option in -lopencode-runtime -l=opencode-runtime -uroot -ialternate; do
    run "${WRAPPER}" playbooks/site.yml --limit microdragon --extra-vars "$REMOTE_TUPLE" "$option"
    [ "$status" -eq 2 ]
    [[ "$output" != *"ANSIBLE_PLAYBOOK_ARGS"* ]]
  done
}

@test "rejects a long alternate inventory before playbook execution" {
  run "${WRAPPER}" playbooks/site.yml --limit microdragon --extra-vars "$REMOTE_TUPLE" --inventory=alternate
  [ "$status" -eq 2 ]
  [[ "$output" == *"wrapper inventory is authoritative"* ]]
  [[ "$output" != *"ANSIBLE_PLAYBOOK_ARGS"* ]]
}

@test "rejects reviewed long option aliases before playbook execution" {
  for option in --lim --use --inventory-file --extra-var; do
    run "${WRAPPER}" playbooks/site.yml --limit microdragon --extra-vars "$REMOTE_TUPLE" "$option" alternate
    [ "$status" -eq 2 ]
    [[ "$output" == *"Unsupported long option"* ]]
    [[ "$output" != *"ANSIBLE_PLAYBOOK_ARGS"* ]]
  done
}

@test "rejects attached reviewed long option aliases before playbook execution" {
  for option in --lim=opencode-runtime --use=root --inventory-file=alternate --extra-var=ansible_connection=local; do
    run "${WRAPPER}" playbooks/site.yml --limit microdragon --extra-vars "$REMOTE_TUPLE" "$option"
    [ "$status" -eq 2 ]
    [[ "$output" == *"Unsupported long option"* ]]
    [[ "$output" != *"ANSIBLE_PLAYBOOK_ARGS"* ]]
  done
}

@test "normalizes explicit remote-ssh to --connection ssh" {
  run "${WRAPPER}" playbooks/site.yml --limit microdragon --connection remote-ssh --user remoteuser --extra-vars "$REMOTE_TUPLE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"--connection ssh"* ]]
  [[ "$output" != *"remote-ssh"* ]]
}

@test "rejects an explicit local connection for a remote inventory target" {
  run "${WRAPPER}" playbooks/site.yml --limit microdragon --connection local --user remoteuser --extra-vars "$REMOTE_TUPLE"
  [ "$status" -ne 0 ]
  [[ "$output" == *"does not match"* ]]
}

@test "rejects attached -c=local before playbook execution" {
  run "${WRAPPER}" playbooks/site.yml --limit microdragon -c=local --extra-vars "$REMOTE_TUPLE"
  [ "$status" -eq 2 ]
  [[ "$output" == *"-c requires a separate value"* ]]
  [[ "$output" != *"ANSIBLE_PLAYBOOK_ARGS"* ]]
}

@test "rejects empty explicit connection values before playbook execution" {
  for option in --connection= -c=; do
    run "${WRAPPER}" playbooks/site.yml --limit microdragon --extra-vars "$REMOTE_TUPLE" "$option"
    [ "$status" -eq 2 ]
    [[ "$output" != *"ANSIBLE_PLAYBOOK_ARGS"* ]]
  done
}

@test "rejects an inventory query failure for an unknown host" {
  run "${WRAPPER}" playbooks/site.yml --limit definitely-not-localhost --user remoteuser --extra-vars "$REMOTE_TUPLE"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unable to resolve"* ]]
}

@test "rejects malformed inventory output instead of guessing local" {
  cat >"${MOCK_DIR}/ansible-inventory" <<'EOF'
#!/usr/bin/env bash
printf 'not-json\n'
EOF
  chmod +x "${MOCK_DIR}/ansible-inventory"

  run "${WRAPPER}" playbooks/site.yml --limit microdragon --user remoteuser --extra-vars "$REMOTE_TUPLE"
  [ "$status" -ne 0 ]
  [[ "$output" == *"site target inventory is not valid JSON"* ]]
}

@test "rejects a managed target with no target_connection contract" {
  cat >"${MOCK_DIR}/missing-target-connection.yml" <<'EOF'
---
all:
  hosts:
    managed-no-contract:
EOF

  run env DOTFILES_INVENTORY="${MOCK_DIR}/missing-target-connection.yml" \
    "${WRAPPER}" playbooks/site.yml --limit managed-no-contract --user remoteuser --extra-vars "$REMOTE_TUPLE"
  [ "$status" -ne 0 ]
  [[ "$output" == *"inventory is missing target_connection"* ]]
  [[ "$output" != *"ANSIBLE_PLAYBOOK_ARGS"* ]]
}

@test "does NOT inject --connection=local when --limit is absent for non-site playbooks" {
  run "${WRAPPER}" playbooks/foundation.yml
  [ "$status" -eq 0 ]
  [[ "$output" != *"--connection=local"* ]]
}

@test "rejects an explicit connection without --limit" {
  run "${WRAPPER}" playbooks/foundation.yml --connection local
  [ "$status" -ne 0 ]
  [[ "$output" == *"Explicit connections require a --limit target"* ]]
  [[ "$output" != *"ANSIBLE_PLAYBOOK_ARGS"* ]]
}

@test "rejects renamed and symlinked playbook copies before tuple validation" {
  renamed_playbook="${MOCK_DIR}/renamed-site.yml"
  symlinked_playbook="${MOCK_DIR}/site.yml"
  cp "${BATS_TEST_DIRNAME}/../../infra/ansible/playbooks/site.yml" "${renamed_playbook}"
  ln -s "${renamed_playbook}" "${symlinked_playbook}"

  for playbook in "${renamed_playbook}" "${symlinked_playbook}"; do
    run "${WRAPPER}" "${playbook}" --limit microdragon --extra-vars "$REMOTE_TUPLE"
    [ "$status" -eq 2 ]
    [[ "$output" == *"Unsupported playbook path"* ]]
    [[ "$output" != *"ANSIBLE_PLAYBOOK_ARGS"* ]]
  done
}

@test "rejects noncanonical target paths before playbook execution" {
  bad_tuple="dotfiles_target_profile=remote-host dotfiles_target_user=remoteuser dotfiles_target_home=/tmp/../root dotfiles_target_source=/tmp/../root/.local/share/chezmoi dotfiles_target_connection=ssh"
  run "${WRAPPER}" playbooks/site.yml --limit microdragon --extra-vars "$bad_tuple"
  [ "$status" -ne 0 ]
  [[ "$output" == *"dot path components"* ]]
  [[ "$output" != *"ANSIBLE_PLAYBOOK_ARGS"* ]]
}

@test "rejects repeated slash and trailing slash target paths before playbook execution" {
  for tuple in \
    "dotfiles_target_profile=remote-host dotfiles_target_user=remoteuser dotfiles_target_home=/tmp//remote-target-home dotfiles_target_source=/tmp//remote-target-home/.local/share/chezmoi dotfiles_target_connection=ssh" \
    "dotfiles_target_profile=remote-host dotfiles_target_user=remoteuser dotfiles_target_home=/tmp/remote-target-home/ dotfiles_target_source=/tmp/remote-target-home/.local/share/chezmoi/ dotfiles_target_connection=ssh"; do
    run "${WRAPPER}" playbooks/site.yml --limit microdragon --extra-vars "$tuple"
    [ "$status" -ne 0 ]
    [[ "$output" == *"lexically canonical"* ]]
    [[ "$output" != *"ANSIBLE_PLAYBOOK_ARGS"* ]]
  done
}

@test "rejects symlinked target home and source paths before playbook execution" {
  real_home="${MOCK_DIR}/real-home"
  home_link="${MOCK_DIR}/home-link"
  real_source="${MOCK_DIR}/real-source"
  source_link="${MOCK_DIR}/source-link"
  mkdir -p "${real_home}" "${real_source}"
  ln -s "${real_home}" "${home_link}"
  ln -s "${real_source}" "${source_link}"

  symlink_home_tuple="dotfiles_target_profile=remote-host dotfiles_target_user=remoteuser dotfiles_target_home=${home_link} dotfiles_target_source=${home_link}/.local/share/chezmoi dotfiles_target_connection=ssh"
  run "${WRAPPER}" playbooks/site.yml --limit microdragon --extra-vars "$symlink_home_tuple"
  [ "$status" -ne 0 ]
  [[ "$output" == *"resolves through a symlink"* ]]
  [[ "$output" != *"ANSIBLE_PLAYBOOK_ARGS"* ]]

  symlink_source_tuple="dotfiles_target_profile=remote-host dotfiles_target_user=remoteuser dotfiles_target_home=/tmp/remote-target-home dotfiles_target_source=${source_link} dotfiles_target_connection=ssh"
  run "${WRAPPER}" playbooks/site.yml --limit microdragon --extra-vars "$symlink_source_tuple"
  [ "$status" -ne 0 ]
  [[ "$output" == *"resolves through a symlink"* ]]
  [[ "$output" != *"ANSIBLE_PLAYBOOK_ARGS"* ]]
}

# ---------------------------------------------------------------------------
# Argument passthrough
# ---------------------------------------------------------------------------

@test "passes through extra ansible-playbook flags" {
  run "${WRAPPER}" playbooks/site.yml --limit microdragon --user remoteuser --extra-vars "$REMOTE_TUPLE" --check --diff
  [ "$status" -eq 0 ]
  [[ "$output" == *"--check"* ]]
  [[ "$output" == *"--diff"* ]]
}

@test "passes through the supported non-target flags" {
  run "${WRAPPER}" playbooks/site.yml --limit microdragon --user remoteuser --extra-vars "$REMOTE_TUPLE" --check --diff --syntax-check --list-tasks
  [ "$status" -eq 0 ]
  [[ "$output" == *"--check"* ]]
  [[ "$output" == *"--diff"* ]]
  [[ "$output" == *"--syntax-check"* ]]
  [[ "$output" == *"--list-tasks"* ]]
}

@test "handles --limit=<remote inventory target> syntax" {
  run "${WRAPPER}" playbooks/site.yml --limit=microdragon --user remoteuser --extra-vars "$REMOTE_TUPLE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"--connection=ssh"* ]]
  [[ "$output" != *"--connection=local"* ]]
}

@test "rejects --limit=<foreign> syntax without guessing a connection" {
  run "${WRAPPER}" playbooks/site.yml --limit=foreignhost --user remoteuser --extra-vars "$REMOTE_TUPLE"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unable to resolve"* ]]
}

@test "rejects structured or indirect extra-vars for a limited foundation playbook" {
  extra_vars_file="${MOCK_DIR}/foundation-extra-vars.yml"
  printf 'ansible_connection: local\n' >"${extra_vars_file}"

  for payload in \
    '{"ansible_connection":"local"}' \
    'ansible_host: localhost' \
    "@${extra_vars_file}"; do
    run "${WRAPPER}" playbooks/foundation.yml --limit microdragon --extra-vars "$payload"
    [ "$status" -ne 0 ]
    [[ "$output" == *"structured or indirect"* ]]
    [[ "$output" != *"ANSIBLE_PLAYBOOK_ARGS"* ]]
  done
}

@test "rejects structured or indirect extra-vars without a limit" {
  extra_vars_file="${MOCK_DIR}/unlimited-extra-vars.yml"
  printf 'ansible_host: localhost\n' >"${extra_vars_file}"

  for payload in \
    '{"ansible_connection":"local"}' \
    'ansible_host: localhost' \
    "@${extra_vars_file}"; do
    run "${WRAPPER}" playbooks/foundation.yml --extra-vars "$payload"
    [ "$status" -ne 0 ]
    [[ "$output" == *"structured or indirect"* ]]
    [[ "$output" != *"ANSIBLE_PLAYBOOK_ARGS"* ]]
  done
}

@test "rejects reserved key=value extra-vars for a limited foundation playbook" {
  for payload in ansible_connection=local ansible_host=localhost; do
    run "${WRAPPER}" playbooks/foundation.yml --limit microdragon --extra-vars "$payload"
    [ "$status" -eq 2 ]
    [[ "$output" == *"Reserved extra-vars key is not accepted"* ]]
    [[ "$output" != *"ANSIBLE_PLAYBOOK_ARGS"* ]]
  done
}

@test "rejects inventory policy identity and unknown target extra-vars" {
  for payload in \
    managed_users=remoteuser \
    target_connection=local \
    target_profile=local-profile \
    target_home=/wrong \
    target_source=/wrong \
    target_user=root \
    host_name=localhost \
    platform_connection_mode=local \
    legacy_connection=local \
    inventory_file=/tmp/alternate \
    hostvars=override \
    groups=all \
    group_names=all \
    dotfiles_target_unknown=override; do
    run "${WRAPPER}" playbooks/foundation.yml --extra-vars "$payload"
    [ "$status" -eq 2 ]
    [[ "$output" == *"extra-vars key is not accepted"* ]]
    [[ "$output" != *"ANSIBLE_PLAYBOOK_ARGS"* ]]

    run "${WRAPPER}" playbooks/site.yml --limit microdragon --extra-vars "$REMOTE_TUPLE $payload"
    [ "$status" -eq 2 ]
    [[ "$output" == *"extra-vars key is not accepted"* ]]
    [[ "$output" != *"ANSIBLE_PLAYBOOK_ARGS"* ]]
  done
}

@test "rejects unapproved short options before playbook execution" {
  for option in -b -bk -v; do
    run "${WRAPPER}" playbooks/site.yml --limit microdragon --extra-vars "$REMOTE_TUPLE" "$option"
    [ "$status" -eq 2 ]
    [[ "$output" == *"Unsupported short option"* ]]
    [[ "$output" != *"ANSIBLE_PLAYBOOK_ARGS"* ]]
  done
}

# ---------------------------------------------------------------------------
# Error handling
# ---------------------------------------------------------------------------

@test "exits with error when no playbook is provided" {
  run "${WRAPPER}"
  [ "$status" -eq 2 ]
  [[ "$output" == *"No playbook specified"* ]] || [[ "$output" == *"Usage"* ]]
}
