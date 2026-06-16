#!/usr/bin/env bats
# Test suite for windsurf zsh completion.
# Tests _windsurf_folder directly (the custom logic).
# Trusts _arguments (part of zsh) and validates its spec statically.

COMPLETION_FILE="${COMPLETION_FILE:-${BATS_TEST_DIRNAME}/_windsurf}"

# Invoke _windsurf_folder in a clean zsh with stubbed completions.
# Arguments are the simulated words array (last = word under cursor).
run_completion() {
  local func_def
  func_def=$(sed -n '/^_windsurf_folder/,/^}/p' "$COMPLETION_FILE")
  zsh -f -c '
    STUB_LOG=$(mktemp)
    trap "rm -f $STUB_LOG" EXIT

    _remote_files()  { echo "remote_files:$*" >> $STUB_LOG; }
    _files()         { echo "files:$*" >> $STUB_LOG; }
    compadd()        { echo "compadd:$*" >> $STUB_LOG; }
    ssh()            { echo "ssh:$*" >> $STUB_LOG; echo "user someuser"; }

    eval "$1"; shift

    words=("$@")
    CURRENT=${#words[@]}
    _windsurf_folder 2>/dev/null

    cat $STUB_LOG
  ' -- "$func_def" "$@"
}

# Assert a glob pattern appears in output
assert_has() {
  local pattern="$1"
  local line
  while IFS= read -r line; do
    [[ "$line" == $pattern ]] && return 0
  done <<< "$output"
  echo "Expected '$pattern' in:" >&2
  echo "$output" >&2
  return 1
}

# Assert a glob pattern does NOT appear in output
assert_lacks() {
  local pattern="$1"
  local line
  while IFS= read -r line; do
    if [[ "$line" == $pattern ]]; then
      echo "Unexpected '$pattern' in:" >&2
      echo "$output" >&2
      return 1
    fi
  done <<< "$output"
}

# ── Static checks on the _arguments spec ──

@test "spec: has #compdef windsurf" {
  head -1 "$COMPLETION_FILE" | grep -q '#compdef windsurf'
}

@test "spec: _arguments declares -r/--remote with _ssh_hosts" {
  grep -q "_arguments" "$COMPLETION_FILE"
  grep -q "'{-r,--remote}'" "$COMPLETION_FILE"
  grep -q "_ssh_hosts" "$COMPLETION_FILE"
}

@test "spec: _arguments declares -h/--help" {
  grep -q "'{-h,--help}'" "$COMPLETION_FILE"
}

@test "spec: _arguments declares positional folder with _windsurf_folder" {
  grep -q "_windsurf_folder" "$COMPLETION_FILE"
}

# ── _windsurf_folder behavior ──

@test "no -r flag, empty word: completes local directories" {
  run run_completion windsurf ''
  assert_has 'files:-/'
  assert_lacks 'remote_files:*'
  assert_lacks 'compadd:*'
}

@test "no -r flag, partial path: completes local directories" {
  run run_completion windsurf '/loc'
  assert_has 'files:-/'
  assert_lacks 'remote_files:*'
}

@test "-r host, empty word: suggests remote home dir via ssh -G" {
  run run_completion windsurf -r myhost ''
  assert_has 'compadd:*-S*--*/home/someuser/*'
  assert_has 'ssh:*-G*myhost*'
  assert_lacks 'files:*'
  assert_lacks 'remote_files:*'
}

@test "--remote host, empty word: suggests remote home dir" {
  run run_completion windsurf --remote myhost ''
  assert_has 'compadd:*-S*--*/home/someuser/*'
  assert_lacks 'files:*'
}

@test "-r host, partial path: completes remote directories" {
  run run_completion windsurf -r myhost '/some'
  assert_has 'remote_files:*-/*-h*myhost*--*ssh*'
  assert_lacks 'files:*'
  assert_lacks 'compadd:*'
}

@test "--remote host, partial path: completes remote directories" {
  run run_completion windsurf --remote myhost '/var'
  assert_has 'remote_files:*-/*-h*myhost*--*ssh*'
  assert_lacks 'files:*'
}

@test "-r host with extra args before folder: still remote" {
  run run_completion windsurf -r myhost '/path/to/dir'
  assert_has 'remote_files:*-/*-h*myhost*--*ssh*'
  assert_lacks 'files:*'
}
