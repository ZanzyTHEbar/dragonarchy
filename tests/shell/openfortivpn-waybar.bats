#!/usr/bin/env bats

setup() {
  LIB_ROOT="${BATS_TEST_DIRNAME}/../../scripts/utilities/openfortivpn-waybar-lib"
  source "${LIB_ROOT}/ui.sh"
  source "${LIB_ROOT}/core.sh"

  # Create a temp config file for config_value tests.
  TEMP_CONFIG="$(mktemp)"
  cat >"$TEMP_CONFIG" <<'EOF'
host = vpn.example.com
port=443

# username = admin
username = user@example.com
password = secret with spaces
trailing-space = value 
EOF
  export VPN_CONFIG="$TEMP_CONFIG"
}

teardown() {
  [[ -f "${TEMP_CONFIG:-}" ]] && rm -f "$TEMP_CONFIG"
}

# ---------------------------------------------------------------------------
# json_escape
# ---------------------------------------------------------------------------

@test "json_escape escapes backslashes" {
  result="$(json_escape 'a\b')"
  [ "$result" = 'a\\b' ]
}

@test "json_escape escapes double quotes" {
  result="$(json_escape 'say "hello"')"
  [ "$result" = 'say \"hello\"' ]
}

@test "json_escape escapes newlines" {
  result="$(json_escape $'line1\nline2')"
  [ "$result" = 'line1\nline2' ]
}

@test "json_escape handles empty string" {
  result="$(json_escape '')"
  [ "$result" = '' ]
}

@test "json_escape escapes multiple special chars" {
  result="$(json_escape $'a\\b"c\nd')"
  [ "$result" = 'a\\b\"c\nd' ]
}

# ---------------------------------------------------------------------------
# config_value
# ---------------------------------------------------------------------------

@test "config_value reads host key" {
  result="$(config_value host)"
  [ "$result" = 'vpn.example.com' ]
}

@test "config_value reads port key without spaces" {
  result="$(config_value port)"
  [ "$result" = '443' ]
}

@test "config_value skips commented line" {
  result="$(config_value username)"
  [ "$result" = 'user@example.com' ]
}

@test "config_value trims leading whitespace in value" {
  result="$(config_value host)"
  [ "$result" = 'vpn.example.com' ]
}

@test "config_value trims trailing whitespace in value" {
  result="$(config_value trailing-space)"
  [ "$result" = 'value' ]
}

@test "config_value returns empty for missing key" {
  result="$(config_value nonexistent)"
  [ "$result" = '' ]
}

@test "config_value handles value with spaces" {
  result="$(config_value password)"
  [ "$result" = 'secret with spaces' ]
}

# ---------------------------------------------------------------------------
# config_or_default
# ---------------------------------------------------------------------------

@test "config_or_default returns existing value" {
  result="$(config_or_default port 8443)"
  [ "$result" = '443' ]
}

@test "config_or_default returns default when key missing" {
  result="$(config_or_default nonexistent fallback)"
  [ "$result" = 'fallback' ]
}

@test "config_or_default returns default when value empty" {
  result="$(config_or_default missing fallback)"
  [ "$result" = 'fallback' ]
}

# ---------------------------------------------------------------------------
# have_cmd
# ---------------------------------------------------------------------------

@test "have_cmd succeeds for known existing command" {
  have_cmd bash
}

@test "have_cmd fails for non-existing command" {
  ! have_cmd __not_a_real_command_12345__
}

# ---------------------------------------------------------------------------
# build_cmd_string
# ---------------------------------------------------------------------------

@test "build_cmd_string quotes arguments with spaces" {
  result="$(build_cmd_string echo 'hello world')"
  [ "$result" = 'echo hello\ world' ]
}

@test "build_cmd_string quotes arguments with special chars" {
  result="$(build_cmd_string echo 'a&b;c')"
  [ "$result" = 'echo a\&b\;c' ]
}

@test "build_cmd_string handles multiple arguments" {
  result="$(build_cmd_string one two 'three four')"
  [ "$result" = 'one two three\ four' ]
}

@test "build_cmd_string handles single argument without spaces" {
  result="$(build_cmd_string ls)"
  [ "$result" = 'ls' ]
}

@test "build_cmd_string handles empty input" {
  result="$(build_cmd_string)"
  [ "$result" = '' ]
}
