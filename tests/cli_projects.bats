#!/usr/bin/env bats
# egloff-cli: projects:list — raw envelope pass-through, --search forwarding,
# and the same credential-failure exit codes as every other list subcommand.

load 'helpers/setup'

CLI="${BATS_TEST_DIRNAME}/../bin/egloff-api"

setup() {
  sandbox_setup
  unset EGLOFF_API_URL EGLOFF_API_TOKEN
}

teardown() {
  sandbox_teardown
}

@test "projects:list against a 200 prints the raw data/links/meta envelope" {
  write_cfg "https://api.example" "goodtoken"
  stub_bin curl 'echo "{\"data\":[{\"id\":7,\"name\":\"Acme\"}]}"; echo 200'

  run bash "$CLI" projects:list < /dev/null
  [ "$status" -eq 0 ]
  [[ "$output" == *'"name": "Acme"'* ]]
}

@test "projects:list --search=Acme forwards ?search=Acme in the request URL" {
  write_cfg "https://api.example" "goodtoken"
  stub_bin curl 'printf "%s\n" "$@" > "${TMPDIR}/curl-args"; echo "{\"data\":[]}"; echo 200'

  run bash "$CLI" projects:list --search=Acme < /dev/null
  [ "$status" -eq 0 ]
  grep -q '/api/projects?search=Acme' "${TMPDIR}/curl-args"
}

@test "projects:list with no stored credentials exits 2 with an actionable message" {
  run bash "$CLI" projects:list < /dev/null
  [ "$status" -eq 2 ]
  [[ "$output" == *"EGLOFF_API_TOKEN"* ]]
  [[ "$output" == *"egloff-api doctor"* ]]
}

@test "projects:list against a 401 prints the server body verbatim plus exactly one doctor hint" {
  write_cfg "https://bad.example" "badtoken"
  stub_bin curl 'echo "{\"message\":\"Unauthenticated.\"}"; echo 401'

  run bash "$CLI" projects:list < /dev/null
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unauthenticated."* ]]

  local hint_count
  hint_count=$(printf '%s\n' "$output" | grep -c 'egloff-api doctor')
  [ "$hint_count" -eq 1 ]
}
