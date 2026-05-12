#!/usr/bin/env bats
#
# run-playbook.bats - Tests for the Ansible playbook wrapper's local-connection
# auto-detection logic.
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

  # Prepend mock to PATH so the wrapper calls it
  export PATH="${MOCK_DIR}:${PATH}"

  # Capture the current hostname for local-target tests
  CURRENT_HOSTNAME="$(hostname -s 2>/dev/null || hostname)"
}

teardown() {
  [[ -d "${MOCK_DIR:-}" ]] && rm -rf "$MOCK_DIR"
}

# ---------------------------------------------------------------------------
# Local target detection
# ---------------------------------------------------------------------------

@test "injects --connection=local when --limit matches current hostname" {
  run "${WRAPPER}" playbooks/site.yml --limit "${CURRENT_HOSTNAME}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"--connection=local"* ]]
}

@test "injects --connection=local when --limit is localhost" {
  run "${WRAPPER}" playbooks/site.yml --limit localhost
  [ "$status" -eq 0 ]
  [[ "$output" == *"--connection=local"* ]]
}

@test "injects --connection=local when --limit is 127.0.0.1" {
  run "${WRAPPER}" playbooks/site.yml --limit 127.0.0.1
  [ "$status" -eq 0 ]
  [[ "$output" == *"--connection=local"* ]]
}

@test "does NOT inject --connection=local for foreign host" {
  run "${WRAPPER}" playbooks/site.yml --limit definitely-not-localhost
  [ "$status" -eq 0 ]
  [[ "$output" != *"--connection=local"* ]]
}

@test "does NOT inject --connection=local when --limit is absent" {
  run "${WRAPPER}" playbooks/site.yml
  [ "$status" -eq 0 ]
  [[ "$output" != *"--connection=local"* ]]
}

# ---------------------------------------------------------------------------
# Argument passthrough
# ---------------------------------------------------------------------------

@test "passes through extra ansible-playbook flags" {
  run "${WRAPPER}" playbooks/site.yml --limit "${CURRENT_HOSTNAME}" --check --diff
  [ "$status" -eq 0 ]
  [[ "$output" == *"--check"* ]]
  [[ "$output" == *"--diff"* ]]
}

@test "handles --limit=<value> syntax" {
  run "${WRAPPER}" playbooks/site.yml --limit="${CURRENT_HOSTNAME}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"--connection=local"* ]]
}

@test "handles --limit=<foreign> syntax without local injection" {
  run "${WRAPPER}" playbooks/site.yml --limit=foreignhost
  [ "$status" -eq 0 ]
  [[ "$output" != *"--connection=local"* ]]
}

# ---------------------------------------------------------------------------
# Error handling
# ---------------------------------------------------------------------------

@test "exits with error when no playbook is provided" {
  run "${WRAPPER}"
  [ "$status" -eq 2 ]
  [[ "$output" == *"No playbook specified"* ]] || [[ "$output" == *"Usage"* ]]
}
