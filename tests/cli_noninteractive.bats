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
  [[ "$output" == *"EGLOFF_API_TOKEN"* ]] || [[ "$output" == *"interactive"* ]]
}

@test "credential-less subcommand with stdin from /dev/null exits non-zero promptly, no prompt" {
  run timeout 5 bash "$CLI" tasks:list < /dev/null
  [ "$status" -ne 0 ]
  [[ "$output" == *"EGLOFF_API_TOKEN"* ]]
}

@test "token via env with no URL config: non-interactive subcommand reaches the default URL and succeeds" {
  stub_bin curl 'echo "{\"data\":[]}"; echo 200'
  run timeout 5 bash -c "export EGLOFF_API_TOKEN=envtoken; bash '${CLI}' tasks:list" < /dev/null
  [ "$status" -eq 0 ]
}
