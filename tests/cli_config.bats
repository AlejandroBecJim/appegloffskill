#!/usr/bin/env bats
# egloff-config: env>file precedence, non-executing parser, secure atomic
# write, and `config show|set-url|set-token` subcommands.

load 'helpers/setup'

CLI="${BATS_TEST_DIRNAME}/../bin/egloff-api"

setup() {
  sandbox_setup
  unset EGLOFF_API_URL EGLOFF_API_TOKEN
}

teardown() {
  sandbox_teardown
}

# --- Adversarial cases (security-critical, written first) ------------------

@test "config file with command substitution payload in URL is never executed" {
  local marker="${SANDBOX_TMP}/marker"
  write_cfg 'https://example.test$(touch '"${marker}"')' "sometoken"

  run bash -c "source '${CLI}'; read_config; printf '%s' \"\$EGLOFF_API_URL\""
  [ "$status" -eq 0 ]
  [ ! -e "$marker" ]
  [[ "$output" == *'$(touch'* ]]
}

@test "config file with backtick payload in TOKEN is never executed" {
  local marker="${SANDBOX_TMP}/marker-bt"
  write_cfg "https://example.test" "tok\`touch ${marker}\`end"

  run bash -c "source '${CLI}'; read_config; printf '%s' \"\$EGLOFF_API_TOKEN\""
  [ "$status" -eq 0 ]
  [ ! -e "$marker" ]
  [[ "$output" == *'`touch'* ]]
}

@test "config file with a semicolon-chained rm payload is stored inertly" {
  local marker="${SANDBOX_TMP}/marker-semi"
  touch "$marker"
  write_cfg "https://example.test" "tok;rm -f ${marker}"

  run bash -c "source '${CLI}'; read_config; printf '%s' \"\$EGLOFF_API_TOKEN\""
  [ "$status" -eq 0 ]
  [ -e "$marker" ]
  [[ "$output" == *';rm -f'* ]]
}

# --- Precedence / resolution -------------------------------------------------

@test "env vars take precedence over a valid file" {
  write_cfg "https://file.example" "filetoken"
  export EGLOFF_API_URL="https://env.example"
  export EGLOFF_API_TOKEN="envtoken"

  run bash -c "source '${CLI}'; read_config; printf '%s|%s|%s' \"\$EGLOFF_API_URL\" \"\$EGLOFF_API_TOKEN\" \"\$CONFIG_SOURCE\""
  [ "$status" -eq 0 ]
  [ "$output" = "https://env.example|envtoken|env" ]
}

@test "file-only resolution when no env vars are set" {
  write_cfg "https://file.example" "filetoken"

  run bash -c "source '${CLI}'; read_config; printf '%s|%s|%s' \"\$EGLOFF_API_URL\" \"\$EGLOFF_API_TOKEN\" \"\$CONFIG_SOURCE\""
  [ "$status" -eq 0 ]
  [ "$output" = "https://file.example|filetoken|file" ]
}

@test "no config and no env resolves to CONFIG_SOURCE=none" {
  run bash -c "source '${CLI}'; read_config; printf '%s' \"\$CONFIG_SOURCE\""
  [ "$status" -eq 0 ]
  [ "$output" = "none" ]
}

# --- Secure atomic write -----------------------------------------------------

@test "write_config persists mode 0600 and no stray temp file remains" {
  run bash -c "source '${CLI}'; write_config 'https://new.example' 'newtoken'"
  [ "$status" -eq 0 ]

  local cfg_dir="${HOME}/.config/egloff-api"
  [ -f "${cfg_dir}/config" ]
  local perms
  perms=$(stat -f '%Lp' "${cfg_dir}/config" 2>/dev/null || stat -c '%a' "${cfg_dir}/config")
  [ "$perms" = "600" ]

  # No leftover mktemp artifact in the config dir.
  local extra
  extra=$(find "$cfg_dir" -type f ! -name config)
  [ -z "$extra" ]
}

@test "set-url writes new URL and preserves existing token from file" {
  write_cfg "https://old.example" "keeptoken"

  run bash -c "source '${CLI}'; main config set-url https://new.example"
  [ "$status" -eq 0 ]

  run bash -c "source '${CLI}'; read_config; printf '%s|%s' \"\$EGLOFF_API_URL\" \"\$EGLOFF_API_TOKEN\""
  [ "$output" = "https://new.example|keeptoken" ]
}

@test "set-token writes new token and preserves existing URL from file" {
  write_cfg "https://keep.example" "oldtoken"

  run bash -c "source '${CLI}'; main config set-token newtoken"
  [ "$status" -eq 0 ]

  run bash -c "source '${CLI}'; read_config; printf '%s|%s' \"\$EGLOFF_API_URL\" \"\$EGLOFF_API_TOKEN\""
  [ "$output" = "https://keep.example|newtoken" ]
}

@test "set-url does not persist an active env-only token override" {
  write_cfg "https://old.example" "filetoken"

  # A session-only override must never leak into the persisted file.
  run bash -c "export EGLOFF_API_TOKEN=temp-session-token; source '${CLI}'; main config set-url https://new.example"
  [ "$status" -eq 0 ]

  run bash -c "unset EGLOFF_API_TOKEN; source '${CLI}'; read_config; printf '%s|%s' \"\$EGLOFF_API_URL\" \"\$EGLOFF_API_TOKEN\""
  [ "$output" = "https://new.example|filetoken" ]
}

@test "set-token does not persist an active env-only URL override" {
  write_cfg "https://old.example" "filetoken"

  run bash -c "export EGLOFF_API_URL=https://temp-session.example; source '${CLI}'; main config set-token newtoken"
  [ "$status" -eq 0 ]

  run bash -c "unset EGLOFF_API_URL; source '${CLI}'; read_config; printf '%s|%s' \"\$EGLOFF_API_URL\" \"\$EGLOFF_API_TOKEN\""
  [ "$output" = "https://old.example|newtoken" ]
}

# --- config show --------------------------------------------------------------

@test "config show reveals only the last 4 characters of the token" {
  write_cfg "https://show.example" "abcd1234wxyz"

  run bash -c "source '${CLI}'; main config show"
  [ "$status" -eq 0 ]
  [[ "$output" == *"https://show.example"* ]]
  [[ "$output" == *"wxyz"* ]]
  [[ "$output" != *"abcd1234wxyz"* ]]
}
