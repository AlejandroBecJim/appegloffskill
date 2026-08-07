#!/usr/bin/env bats
# Guarded CLI symlink: present -> linked; absent -> warn + skip + exit 0;
# pre-existing non-symlink file -> refuse to clobber + exit 0.

load 'helpers/setup'

setup() {
  sandbox_setup
}

teardown() {
  sandbox_teardown
}

@test "bin/egloff-api present is symlinked into EGLOFF_BIN_DIR" {
  local checkout="${SANDBOX_TMP}/checkout-with-cli"
  build_local_checkout "$checkout" with-cli

  run bash "${checkout}/install.sh"
  [ "$status" -eq 0 ]
  [ -L "${EGLOFF_BIN_DIR}/egloff-api" ]
  [ "$(readlink "${EGLOFF_BIN_DIR}/egloff-api")" = "${checkout}/bin/egloff-api" ]
}

@test "bin/egloff-api absent warns, skips symlink, still installs skill, exits 0" {
  local checkout="${SANDBOX_TMP}/checkout-without-cli"
  build_local_checkout "$checkout" without-cli

  run bash "${checkout}/install.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"not found"* ]] || [[ "$output" == *"skipping CLI symlink"* ]]
  [ ! -e "${EGLOFF_BIN_DIR}/egloff-api" ]
  [ -L "${HOME}/.claude/skills/egloff-api" ]
}

@test "pre-existing real file at CLI target is not clobbered" {
  local checkout="${SANDBOX_TMP}/checkout-with-cli"
  build_local_checkout "$checkout" with-cli

  mkdir -p "$EGLOFF_BIN_DIR"
  echo "user binary — do not touch" > "${EGLOFF_BIN_DIR}/egloff-api"

  run bash "${checkout}/install.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"not managed by this installer"* ]] || [[ "$output" == *"refusing to overwrite"* ]]
  [ ! -L "${EGLOFF_BIN_DIR}/egloff-api" ]
  [ "$(cat "${EGLOFF_BIN_DIR}/egloff-api")" = "user binary — do not touch" ]
  [ -L "${HOME}/.claude/skills/egloff-api" ]
}
