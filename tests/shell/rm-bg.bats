#!/usr/bin/env bats

setup() {
  RM_BG_FUNCTION="${BATS_TEST_DIRNAME}/../../packages/zsh/.config/zsh/functions/rm-bg.zsh"
  TEST_ROOT="$(mktemp -d)"
}

teardown() {
  [[ -d "${TEST_ROOT:-}" ]] && rm -rf -- "$TEST_ROOT"
}

@test "protects descendants of every protected root" {
  run zsh -f -c '
    log_error() { print -u2 -- "[ERROR] $*"; }
    log_info() { print -- "[INFO] $*"; }
    log_success() { print -- "[SUCCESS] $*"; }
    source "$1"
    for root in /bin /sbin /usr /lib /lib64 /etc /boot /dev /proc /sys /run /root /var /System /Library /Applications; do
      _rm_bg_is_protected "$root/child" || exit 1
    done
  ' zsh "$RM_BG_FUNCTION"

  [ "$status" -eq 0 ]
}

@test "refuses a symlink resolving into a protected root" {
  run zsh -f -c '
    log_error() { print -u2 -- "[ERROR] $*"; }
    log_info() { print -- "[INFO] $*"; }
    log_success() { print -- "[SUCCESS] $*"; }
    source "$1"
    ln -s /var "$2/protected-link"
    RM_BG_NOTIFY=0 RM_BG_SYNC=1 rm_bg "$2/protected-link"
  ' zsh "$RM_BG_FUNCTION" "$TEST_ROOT"

  [ "$status" -eq 1 ]
  [[ "$output" == *"protected path refused"* ]]
  [ -L "$TEST_ROOT/protected-link" ]
}

@test "refuses paths through symlinked parents" {
  run zsh -f -c '
    log_error() { print -u2 -- "[ERROR] $*"; }
    log_info() { print -- "[INFO] $*"; }
    log_success() { print -- "[SUCCESS] $*"; }
    source "$1"
    mkdir "$2/real"
    touch "$2/real/file"
    ln -s real "$2/link"
    RM_BG_NOTIFY=0 RM_BG_SYNC=1 rm_bg "$2/link/file"
  ' zsh "$RM_BG_FUNCTION" "$TEST_ROOT"

  [ "$status" -eq 1 ]
  [[ "$output" == *"symlinked parent"* ]]
  [ -e "$TEST_ROOT/real/file" ]
}

@test "rejects directories instead of recursively deleting them" {
  run zsh -f -c '
    log_error() { print -u2 -- "[ERROR] $*"; }
    log_info() { print -- "[INFO] $*"; }
    log_success() { print -- "[SUCCESS] $*"; }
    source "$1"
    mkdir "$2/target"
    RM_BG_NOTIFY=0 RM_BG_SYNC=1 rm_bg "$2/target"
  ' zsh "$RM_BG_FUNCTION" "$TEST_ROOT"

  [ "$status" -eq 1 ]
  [[ "$output" == *"directories are not supported"* ]]
  [ -d "$TEST_ROOT/target" ]
}

@test "rejects option-like paths without the sentinel" {
  run zsh -f -c '
    log_error() { print -u2 -- "[ERROR] $*"; }
    log_info() { print -- "[INFO] $*"; }
    log_success() { print -- "[SUCCESS] $*"; }
    source "$1"
    cd "$2" || exit 2
    touch -- --option
    RM_BG_SYNC=1 rm_bg --option
  ' zsh "$RM_BG_FUNCTION" "$TEST_ROOT"

  [ "$status" -eq 1 ]
  [[ "$output" == *"refuse option-like path"* ]]
  [ -e "$TEST_ROOT/--option" ]
}

@test "rejects parent-directory path components" {
  run zsh -f -c '
    log_error() { print -u2 -- "[ERROR] $*"; }
    log_info() { print -- "[INFO] $*"; }
    log_success() { print -- "[SUCCESS] $*"; }
    source "$1"
    mkdir "$2/child"
    for raw in "$2/child/.." "$2/./." "$2/././" "$2/.//"; do
      rc=0
      RM_BG_NOTIFY=0 RM_BG_SYNC=1 rm_bg "$raw" || rc=$?
      [[ $rc -eq 1 && -d "$2" ]] || exit 2
    done
    exit 1
  ' zsh "$RM_BG_FUNCTION" "$TEST_ROOT"

  [ "$status" -eq 1 ]
  [[ "$output" == *"parent-directory path component"* ]]
  [ -d "$TEST_ROOT" ]
}

@test "removes option-like paths after the sentinel" {
  run zsh -f -c '
    log_error() { print -u2 -- "[ERROR] $*"; }
    log_info() { print -- "[INFO] $*"; }
    log_success() { print -- "[SUCCESS] $*"; }
    source "$1"
    cd "$2" || exit 2
    touch -- --option
    RM_BG_NOTIFY=0 RM_BG_SYNC=1 rm_bg -- --option
    [[ ! -e ./--option ]]
  ' zsh "$RM_BG_FUNCTION" "$TEST_ROOT"

  [ "$status" -eq 0 ]
}

@test "has valid zsh syntax" {
  run zsh -n "$RM_BG_FUNCTION"
  [ "$status" -eq 0 ]
}
