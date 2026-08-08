#!/usr/bin/env bats
# egloff-setup-assistant: `doctor` is a read-only, human-readable renderer.

load 'helpers/setup'

CLI="${BATS_TEST_DIRNAME}/../bin/egloff-api"

setup() {
  sandbox_setup
  unset EGLOFF_API_URL EGLOFF_API_TOKEN
}

teardown() {
  sandbox_teardown
}

@test "doctor with no config and no env vars: non-zero exit, human-readable text, creates no files" {
  run bash "$CLI" doctor
  [ "$status" -ne 0 ]
  [[ "$output" == *"dependencies"* ]]
  [[ "$output" == *"url: https://app.egloff.com.mx (source: default)"* ]]
  [[ "$output" == *"token: not set"* ]]
  [[ "$output" != *'{"'* ]]
  [ ! -d "${HOME}/.config/egloff-api" ]
}

@test "doctor reports all three URL provenance labels correctly" {
  # default
  run bash "$CLI" doctor
  [[ "$output" == *"(source: default)"* ]]

  # env
  run bash -c "export EGLOFF_API_URL=https://env.example EGLOFF_API_TOKEN=envtoken; bash '${CLI}' doctor"
  [[ "$output" == *"(source: env EGLOFF_API_URL)"* ]]

  # file
  write_cfg "https://file.example" "filetoken"
  run bash "$CLI" doctor
  [[ "$output" == *"(source: ${HOME}/.config/egloff-api/config)"* ]]
}

@test "doctor does not support --json" {
  run bash "$CLI" doctor --json
  [[ "$output" != *'"dependencies"'* ]]
}

@test "doctor with a healthy config reports ok connectivity" {
  write_cfg "https://good.example" "goodtoken"
  stub_bin curl 'echo "{\"data\":[]}"; echo 200'

  run bash "$CLI" doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"[ok]"* ]]
  [[ "$output" == *"connectivity"* ]]
}

@test "doctor with default URL and a token set via env exits 0 and never fails on URL state" {
  stub_bin curl 'echo "{\"data\":[]}"; echo 200'

  run bash -c "export EGLOFF_API_TOKEN=envtoken; bash '${CLI}' doctor"
  [ "$status" -eq 0 ]
  [[ "$output" == *"url: https://app.egloff.com.mx (source: default)"* ]]
  [[ "$output" == *"token: loaded"* ]]
}
