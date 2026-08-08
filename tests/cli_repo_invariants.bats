#!/usr/bin/env bats
# Repo-level invariants for the consolidated CLI: bin/egloff-api must be
# committed executable, and the retired legacy asset must be gone.

load 'helpers/setup'

setup() {
  sandbox_setup
}

teardown() {
  sandbox_teardown
}

@test "bin/egloff-api is executable in the real repo checkout" {
  [ -x "${REPO_ROOT}/bin/egloff-api" ]
}

@test "egloff-api/assets/egloff-api.sh no longer exists (no shim/alias)" {
  [ ! -e "${REPO_ROOT}/egloff-api/assets/egloff-api.sh" ]
}
