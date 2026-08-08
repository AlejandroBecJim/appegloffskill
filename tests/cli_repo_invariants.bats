#!/usr/bin/env bats
# Repo-level invariants for the consolidated CLI: bin/egloff-api must be
# committed executable.

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
