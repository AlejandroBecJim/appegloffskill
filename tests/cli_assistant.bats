#!/usr/bin/env bats
# egloff-setup-assistant: interactive control flow (fresh setup, healthy
# re-run, bad-config recovery). is_interactive() and tty_read() are
# overridden after sourcing so no real /dev/tty is required.

load 'helpers/setup'

CLI="${BATS_TEST_DIRNAME}/../bin/egloff-api"

setup() {
  sandbox_setup
  unset EGLOFF_API_URL EGLOFF_API_TOKEN
}

teardown() {
  sandbox_teardown
}

@test "fresh setup: no config, prompts for URL/token, persists, verifies, offers skill install" {
  stub_bin curl 'echo "{\"data\":[]}"; echo 200'

  run bash -c "
    source '${CLI}'
    is_interactive() { return 0; }
    TTY_QUEUE=('https://fresh.example' 'freshtoken' 's')
    TTY_IDX=0
    tty_read() {
      local __varname=\"\$1\"
      printf -v \"\$__varname\" '%s' \"\${TTY_QUEUE[\$TTY_IDX]:-}\"
      TTY_IDX=\$((TTY_IDX + 1))
    }
    cmd_assistant
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"Connectivity verified"* ]]
  [[ "$output" == *"Install the egloff-api Claude Code skill"* ]]

  [ -f "${HOME}/.config/egloff-api/config" ]
  run bash -c "source '${CLI}'; read_config; printf '%s|%s' \"\$EGLOFF_API_URL\" \"\$EGLOFF_API_TOKEN\""
  [ "$output" = "https://fresh.example|freshtoken" ]
}

@test "healthy re-run: valid config prints config OK and skips straight to skill offer" {
  write_cfg "https://healthy.example" "healthytoken"
  stub_bin curl 'echo "{\"data\":[]}"; echo 200'

  run bash -c "
    source '${CLI}'
    is_interactive() { return 0; }
    TTY_QUEUE=('s')
    TTY_IDX=0
    tty_read() {
      local __varname=\"\$1\"
      printf -v \"\$__varname\" '%s' \"\${TTY_QUEUE[\$TTY_IDX]:-}\"
      TTY_IDX=\$((TTY_IDX + 1))
    }
    cmd_assistant
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"config OK"* ]]
  [[ "$output" == *"Install the egloff-api Claude Code skill"* ]]
  [[ "$output" != *"Enter EGLOFF_API_URL"* ]]
}

@test "bad saved config: shows failure and offers re-prompt/overwrite" {
  write_cfg "https://bad.example" "badtoken"
  stub_bin curl 'echo "{\"message\":\"Unauthenticated.\"}"; echo 401'

  run bash -c "
    source '${CLI}'
    is_interactive() { return 0; }
    TTY_QUEUE=('y' 'https://recovered.example' 'recoveredtoken' 's')
    TTY_IDX=0
    tty_read() {
      local __varname=\"\$1\"
      printf -v \"\$__varname\" '%s' \"\${TTY_QUEUE[\$TTY_IDX]:-}\"
      TTY_IDX=\$((TTY_IDX + 1))
    }
    cmd_assistant
  "
  [[ "$output" == *"Stored configuration failed"* ]]
  [[ "$output" == *"Re-enter URL/token now?"* ]]
}
