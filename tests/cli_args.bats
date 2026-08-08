#!/usr/bin/env bats
# egloff-cli: args_to_json / args_to_query typing and encoding, carried over
# verbatim from egloff-api/assets/egloff-api.sh.

load 'helpers/setup'

CLI="${BATS_TEST_DIRNAME}/../bin/egloff-api"

setup() {
  sandbox_setup
}

teardown() {
  sandbox_teardown
}

@test "args_to_json: boolean value stays a JSON boolean, not a string" {
  run bash -c "source '${CLI}'; args_to_json --on_radar_today=true"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -c '.on_radar_today')" = "true" ]
}

@test "args_to_json: bare integer becomes a JSON number" {
  run bash -c "source '${CLI}'; args_to_json --sort_order=42"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -c '.sort_order')" = "42" ]
}

@test "args_to_json: ordinary string stays a JSON string" {
  run bash -c "source '${CLI}'; args_to_json --title=\"Buy milk\""
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.title')" = "Buy milk" ]
}

@test "args_to_json: non --k=v args are skipped" {
  run bash -c "source '${CLI}'; args_to_json positional --title=x --bogus"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -c 'keys')" = '["title"]' ]
}

@test "args_to_query: builds a @uri-encoded query string" {
  run bash -c "source '${CLI}'; args_to_query --search=\"hello world\""
  [ "$status" -eq 0 ]
  [ "$output" = "search=hello%20world" ]
}

@test "args_to_query: multiple pairs joined with &" {
  run bash -c "source '${CLI}'; args_to_query --search=foo --type=bar"
  [ "$status" -eq 0 ]
  [ "$output" = "search=foo&type=bar" ]
}
