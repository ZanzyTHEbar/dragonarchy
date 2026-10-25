#!/usr/bin/env zsh
setopt no_unset

ROOT="${0:A:h:h:h}"
source "$ROOT/packages/zsh/.config/zsh/functions/ssh-tint.zsh"

fail() {
  print -u2 -- "FAIL: $1"
  exit 1
}

assert_eq() {
  [[ "$1" == "$2" ]] || fail "expected <$2>, got <$1>"
}

TEST_ROOT="$(command mktemp -d)" || fail "could not create temporary test directory"
trap 'command rm -rf "$TEST_ROOT"' EXIT
mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/home/.config/current/theme"
export HOME="$TEST_ROOT/home" XDG_CACHE_HOME="$TEST_ROOT/home/.cache" TMPDIR="$TEST_ROOT" TERM=xterm-kitty KITTY_WINDOW_ID=42 KITTY_LISTEN_ON="unix:$TEST_ROOT/kitty.sock"
export KITTY_CALLS="$TEST_ROOT/kitty-calls" SSH_CALLS="$TEST_ROOT/ssh-calls"
export SSH_TINT_TEST_AUTH=1 SSH_TINT_TEST_STATUS=23 SSH_TINT_TEST_LOCALCOMMAND=none

cat >"$TEST_ROOT/bin/ssh" <<'EOF'
#!/bin/sh
if [ "${1:-}" = -G ]; then
  printf 'hostname %s\nuser fixture-user\nport %s\nhostkeyalias none\nlocalcommand %s\nproxyjump %s\nproxycommand %s\nloglevel INFO\n' \
    "${SSH_TINT_TEST_HOSTNAME:-fixture.example}" \
    "${SSH_TINT_TEST_PORT:-22}" \
    "${SSH_TINT_TEST_LOCALCOMMAND:-none}" \
    "${SSH_TINT_TEST_PROXYJUMP:-none}" \
    "${SSH_TINT_TEST_PROXYCOMMAND:-none}"
  exit 0
fi
printf '%s\n' "$*" >>"$SSH_CALLS"
exit "${SSH_TINT_TEST_STATUS:-0}"
EOF

cat >"$TEST_ROOT/bin/kitty" <<'EOF'
#!/bin/sh
if [ "${1:-}" = @ ]; then
  printf '%s\n' "$*" >>"$KITTY_CALLS"
  exit 0
fi
[ "${1:-}" = +kitten ] && [ "${2:-}" = ssh ] || exit 90
printf '%s\n' "$*" >>"$SSH_CALLS"
shift 2
log=
local_command=
while [ "$#" -gt 0 ]; do
  case "$1" in
    -E) log=$2; shift 2 ;;
    -o)
      case "$2" in LocalCommand=*) local_command=${2#LocalCommand=} ;; esac
      shift 2
      ;;
    *) shift ;;
  esac
done
if [ -n "$log" ]; then
  if [ "${SSH_TINT_TEST_MUX:-0}" = 1 ]; then
    printf 'debug1: auto-mux: Trying existing master\n' >"$log"
    printf 'debug1: mux_client_request_session: master session id: 2\n' >>"$log"
  else
    printf 'debug1: Server host key: ssh-ed25519 SHA256:BAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\n' >"$log"
    if [ "${SSH_TINT_TEST_AUTH:-0}" = 1 ]; then
      printf 'Authenticated to fixture.example ([192.0.2.1]:22) using "publickey".\r\n' >>"$log"
    fi
  fi
fi
if [ -n "$local_command" ] && [ "${SSH_TINT_TEST_MUX:-0}" != 1 ]; then eval "$local_command"; fi
sleep 0.2
exit "${SSH_TINT_TEST_STATUS:-0}"
EOF

chmod +x "$TEST_ROOT/bin/ssh" "$TEST_ROOT/bin/kitty"
export PATH="$TEST_ROOT/bin:$PATH"
print -r -- 'active_border_color #7aa2f7' >"$HOME/.config/current/theme/kitty.conf"

# The first five base64 bits cover all 32 slots; adjacent values can collide.
typeset -a alphabet
alphabet=( {A..Z} {a..z} {0..9} + / )
for slot in {0..31}; do
  encoded="${alphabet[$((slot * 2 + 1))]}AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
  assert_eq "$(_ssh_tint_slot "SHA256:$encoded")" "$slot"
done
assert_eq "$(_ssh_tint_slot SHA256:BAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA)" 0
if _ssh_tint_slot SHA256:invalid >/dev/null 2>&1; then
  fail 'accepted a malformed fingerprint'
fi
cache_key="$(_ssh_tint_cache_key fixture.example fixture-user 22)"
[[ "$cache_key" != "$(_ssh_tint_cache_key fixture.example fixture-user 2222)" ]] || fail 'cache key ignored the SSH port'

# Tint palettes must produce 32 distinct colors while following every theme accent.
kitty_config="$ROOT/packages/kitty/.config/kitty/kitty.conf"
includes=("${(@f)$(command awk '/^include / { print }' "$kitty_config")}")
assert_eq "${includes[1]}" 'include themes/OneDark.conf'
assert_eq "${includes[2]}" 'include colors.conf'
listen_on="$(command awk '$1 == "listen_on" { print $2; exit }' "$kitty_config")"
assert_eq "$listen_on" 'unix:${XDG_RUNTIME_DIR}/kitty-{kitty_pid}'
for theme_file in "$ROOT"/packages/themes/.config/themes/*/kitty.conf(N); do
  accent="$(command awk '$1 == "active_border_color" { print $2; exit }' "$theme_file")"
  [[ "$accent" == \#?????? ]] || fail "missing theme accent in $theme_file"
  active_background="$(command awk '$1 == "active_tab_background" { print $2; exit }' "$theme_file")"
  active_foreground="$(command awk '$1 == "active_tab_foreground" { print $2; exit }' "$theme_file")"
  inactive_background="$(command awk '$1 == "inactive_tab_background" { print $2; exit }' "$theme_file")"
  inactive_foreground="$(command awk '$1 == "inactive_tab_foreground" { print $2; exit }' "$theme_file")"
  assert_eq "$active_background" "$accent"
  assert_eq "$inactive_background" "$(command awk '$1 == "background" { print $2; exit }' "$theme_file")"
  assert_eq "$inactive_foreground" "$(command awk '$1 == "foreground" { print $2; exit }' "$theme_file")"
  base_colors="$(_ssh_tint_colors "$accent" 0)"
  assert_eq "$active_foreground" "${base_colors##* }"
  typeset -A seen_colors=()
  for slot in {0..31}; do
    colors="$(_ssh_tint_colors "$accent" "$slot")" || fail "could not derive tint for $theme_file"
    tint="${colors%% *}"
    [[ -z "${seen_colors[$tint]-}" ]] || fail "duplicate tint $tint in $theme_file"
    seen_colors[$tint]=1
  done
done

# The log parser waits for authentication and rejects ambiguous key logs.
log="$TEST_ROOT/ssh-debug.log"
cache_file="$TEST_ROOT/cache/fingerprint"
print -r -- $'debug1: Server host key: ssh-ed25519 SHA256:BAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r' >"$log"
if _ssh_tint_fingerprint_from_log "$log" >/dev/null 2>&1; then
  fail 'accepted a host key before authentication'
fi
print -r -- $'Authenticated to fixture.example ([192.0.2.1]:22) using "publickey".\r' >>"$log"
assert_eq "$(_ssh_tint_fingerprint_from_log "$log")" 'SHA256:BAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
print -r -- $'debug1: Authenticated to fixture.example ([192.0.2.1]:22) using "publickey".\r' >>"$log"
assert_eq "$(_ssh_tint_fingerprint_from_log "$log")" 'SHA256:BAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
print -r -- 'debug1: Server host key: ecdsa-sha2-nistp256 SHA256:CAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' >>"$log"
if _ssh_tint_fingerprint_from_log "$log" >/dev/null 2>&1; then
  fail 'accepted multiple distinct server fingerprints'
fi

# The local helper applies only after verified authentication and reports whether cleanup is needed.
: >"$KITTY_CALLS"
print -r -- $'debug1: Server host key: ssh-ed25519 SHA256:BAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r' >"$log"
print -r -- $'Authenticated to fixture.example ([192.0.2.1]:22) using "publickey".\r' >>"$log"
_ssh_tint_apply "$log" 42 "$cache_file" || fail 'could not apply a valid SSH tint'
[[ "$(<"$log")" == *'SSH_TINT_APPLIED'* ]] || fail 'successful tint did not request cleanup'
[[ "$(<"$KITTY_CALLS")" == *'active_bg='* ]] || fail 'Kitty did not receive a tint'
[[ "$(<"$KITTY_CALLS")" == *'--to unix:'* ]] || fail 'Kitty control command did not use its listener socket'
assert_eq "$(<"$cache_file")" 'SHA256:BAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'

: >"$KITTY_CALLS"
print -r -- 'debug1: auto-mux: Trying existing master' >"$log"
if _ssh_tint_fingerprint_from_log "$log" >/dev/null 2>&1; then
  fail 'accepted a Mux master before its session was confirmed'
fi
print -r -- 'debug1: mux_client_request_session: master session id: 2' >>"$log"
assert_eq "$(_ssh_tint_fingerprint_from_log "$log")" SSH_TINT_REUSED_MASTER
_ssh_tint_apply "$log" 42 "$cache_file" || fail 'reused master did not use its cached fingerprint'
[[ "$(<"$KITTY_CALLS")" == *'active_bg='* ]] || fail 'cached fingerprint did not tint the tab'

: >"$KITTY_CALLS"
print -r -- 'debug1: auto-mux: Trying existing master' >"$log"
print -r -- 'debug1: mux_client_request_session: master session id: 2' >>"$log"
if _ssh_tint_apply "$log" 42 "$TEST_ROOT/cache/missing" >/dev/null 2>&1; then
  fail 'tinted a reused master without a cached fingerprint'
fi
[[ ! -s "$KITTY_CALLS" ]] || fail 'missing cached fingerprint changed tab colors'

: >"$KITTY_CALLS"
print -r -- $'debug1: Server host key: ssh-ed25519 SHA256:BAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r' >"$log"
if _ssh_tint_apply "$log" 42 "$cache_file" >/dev/null 2>&1; then
  fail 'applied a tint without authentication'
fi
[[ ! -s "$KITTY_CALLS" && "$(<"$log")" != *'SSH_TINT_APPLIED'* ]] || fail 'failed authentication changed tab color'

# The SSH wrapper preserves status, restores on success, and leaves proxy/custom hooks alone.
: >"$KITTY_CALLS" "$SSH_CALLS"
ssh fixture.example
ssh_status=$?
assert_eq "$ssh_status" 23
calls="$(<"$KITTY_CALLS")"
[[ "$calls" == *'active_bg='* && "$calls" == *'active_bg=NONE'* ]] || fail 'SSH tint lifecycle did not apply and restore the tab colors'
cache_files=("$HOME/.cache/ssh-tint"/*(N))
assert_eq "${#cache_files}" 1

: >"$KITTY_CALLS" "$SSH_CALLS"
export SSH_TINT_TEST_MUX=1
ssh fixture.example
ssh_status=$?
assert_eq "$ssh_status" 23
calls="$(<"$KITTY_CALLS")"
[[ "$calls" == *'active_bg='* && "$calls" == *'active_bg=NONE'* ]] || fail 'reused Kitty SSH did not use its verified fingerprint cache'

: >"$KITTY_CALLS" "$SSH_CALLS"
export SSH_TINT_TEST_HOSTNAME=other.example
ssh fixture.example
ssh_status=$?
assert_eq "$ssh_status" 23
[[ ! -s "$KITTY_CALLS" ]] || fail 'used a cached fingerprint for a different effective host'
export SSH_TINT_TEST_HOSTNAME=fixture.example SSH_TINT_TEST_MUX=0

: >"$KITTY_CALLS" "$SSH_CALLS"
SSH_TINT_TEST_STATUS=26 ssh -f fixture.example
ssh_status=$?
assert_eq "$ssh_status" 26
[[ ! -s "$KITTY_CALLS" ]] || fail 'background SSH unexpectedly tinted the tab'

: >"$KITTY_CALLS" "$SSH_CALLS"
export SSH_TINT_TEST_AUTH=0 SSH_TINT_TEST_STATUS=24
ssh fixture.example
ssh_status=$?
assert_eq "$ssh_status" 24
[[ ! -s "$KITTY_CALLS" ]] || fail 'failed SSH authentication changed tab colors'

: >"$KITTY_CALLS" "$SSH_CALLS"
export SSH_TINT_TEST_AUTH=1 SSH_TINT_TEST_STATUS=25 SSH_TINT_TEST_PROXYJUMP=gateway.example
ssh fixture.example
ssh_status=$?
assert_eq "$ssh_status" 25
[[ ! -s "$KITTY_CALLS" ]] || fail 'proxied SSH unexpectedly applied a tint'

: >"$KITTY_CALLS" "$SSH_CALLS"
export SSH_TINT_TEST_PROXYJUMP=none SSH_TINT_TEST_LOCALCOMMAND='echo user-hook'
ssh fixture.example
calls="$(<"$KITTY_CALLS")"
[[ "$calls" == *'active_bg='* && "$calls" == *'active_bg=NONE'* ]] || fail 'SSH tint was skipped for a host with a custom LocalCommand'
[[ "$(<"$SSH_CALLS")" != *'LocalCommand='* ]] || fail 'custom LocalCommand was injected or replaced'

: >"$SSH_CALLS"
export TERM=xterm-256color SSH_TINT_TEST_LOCALCOMMAND=none
ssh fixture.example
[[ "$(<"$SSH_CALLS")" == 'fixture.example' ]] || fail 'non-Kitty SSH did not use OpenSSH directly'

print -r -- 'SSH tint checks passed'
