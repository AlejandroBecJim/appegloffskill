#!/usr/bin/env bats
# egloff-cli: server error surfaced verbatim + exactly one doctor hint line,
# no interactive prompt, on subcommand failure.

load 'helpers/setup'

CLI="${BATS_TEST_DIRNAME}/../bin/egloff-api"

setup() {
  sandbox_setup
  unset EGLOFF_API_URL EGLOFF_API_TOKEN
  write_cfg "https://bad.example" "badtoken"
  stub_bin curl 'echo "{\"message\":\"Unauthenticated.\"}"; echo 401'
}

teardown() {
  sandbox_teardown
}

@test "tasks:list against a 401 prints the server body verbatim plus exactly one doctor hint" {
  run bash "$CLI" tasks:list < /dev/null
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unauthenticated."* ]]

  local hint_count
  hint_count=$(printf '%s\n' "$output" | grep -c 'egloff-api doctor')
  [ "$hint_count" -eq 1 ]

  [[ "$output" != *"Enter EGLOFF_API"* ]]
  [[ "$output" != *"[y/N]"* ]]
}
