#!/usr/bin/env bats
# PATH detection without auto-edit: prints manual instructions when
# EGLOFF_BIN_DIR is missing from PATH, never edits any rc file.

load 'helpers/setup'

setup() {
  sandbox_setup
}

teardown() {
  sandbox_teardown
}

@test "prints manual PATH instructions when EGLOFF_BIN_DIR is off PATH, rc files untouched" {
  local checkout="${SANDBOX_TMP}/checkout-with-cli"
  build_local_checkout "$checkout" with-cli

  local rc_before_bashrc rc_before_zshrc rc_before_profile
  rc_before_bashrc="$(cat "${HOME}/.bashrc")"
  rc_before_zshrc="$(cat "${HOME}/.zshrc")"
  rc_before_profile="$(cat "${HOME}/.profile")"

  PATH="/usr/bin:/bin" run bash "${checkout}/install.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"not on your PATH"* ]]
  [[ "$output" == *"export PATH="* ]]

  [ "$(cat "${HOME}/.bashrc")" = "$rc_before_bashrc" ]
  [ "$(cat "${HOME}/.zshrc")" = "$rc_before_zshrc" ]
  [ "$(cat "${HOME}/.profile")" = "$rc_before_profile" ]
}

@test "no PATH notice when EGLOFF_BIN_DIR already on PATH" {
  local checkout="${SANDBOX_TMP}/checkout-with-cli"
  build_local_checkout "$checkout" with-cli

  PATH="${EGLOFF_BIN_DIR}:${PATH}" run bash "${checkout}/install.sh"
  [ "$status" -eq 0 ]
  [[ "$output" != *"not on your PATH"* ]]
}
