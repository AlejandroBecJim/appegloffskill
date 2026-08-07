#!/usr/bin/env bats
# egloff-setup-assistant: single is_interactive() TTY gate — no prompt ever
# blocks under bats/CI/pipes.

load 'helpers/setup'

CLI="${BATS_TEST_DIRNAME}/../bin/egloff-api"

setup() {
  sandbox_setup
  unset EGLOFF_API_URL EGLOFF_API_TOKEN
}

teardown() {
  sandbox_teardown
}

@test "no-args invocation with no config, stdin from /dev/null, exits non-zero promptly with an actionable message" {
  run timeout 5 bash "$CLI" < /dev/null
  [ "$status" -ne 0 ]
  [[ "$output" == *"no configuration"* ]] || [[ "$output" == *"interactive"* ]]
}

@test "credential-less subcommand with stdin from /dev/null exits non-zero promptly, no prompt" {
  run timeout 5 bash "$CLI" tasks:list < /dev/null
  [ "$status" -ne 0 ]
  [[ "$output" == *"no credentials"* ]] || [[ "$output" == *"EGLOFF_API"* ]]
}
