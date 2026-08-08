#!/usr/bin/env bats
# Local-mode regression: default install, --project, --copy, unknown arg,
# -h/--help. Runs the real install.sh directly from the checkout (local
# mode: BASH_SOURCE readable + sibling skills/egloff-api/ present).

load 'helpers/setup'

setup() {
  sandbox_setup
}

teardown() {
  sandbox_teardown
}

@test "default install symlinks into ~/.claude/skills/egloff-api" {
  run bash "$INSTALL_SH"
  [ "$status" -eq 0 ]
  [ -L "${HOME}/.claude/skills/egloff-api" ]
  [ "$(readlink "${HOME}/.claude/skills/egloff-api")" = "${REPO_ROOT}/skills/egloff-api" ]
}

@test "--project PATH installs into PATH/.claude/skills/egloff-api" {
  local project_dir="${SANDBOX_TMP}/my-project"
  mkdir -p "$project_dir"

  run bash "$INSTALL_SH" --project "$project_dir"
  [ "$status" -eq 0 ]
  [ -L "${project_dir}/.claude/skills/egloff-api" ]
}

@test "--copy copies files instead of symlinking" {
  run bash "$INSTALL_SH" --copy
  [ "$status" -eq 0 ]
  [ -d "${HOME}/.claude/skills/egloff-api" ]
  [ ! -L "${HOME}/.claude/skills/egloff-api" ]
  [ -f "${HOME}/.claude/skills/egloff-api/SKILL.md" ]
}

@test "unknown argument exits 1 with an error" {
  run bash "$INSTALL_SH" --bogus-flag
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown argument"* ]]
}

@test "-h/--help prints usage via heredoc, not BASH_SOURCE sed" {
  run bash "$INSTALL_SH" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"./install.sh"* ]]

  run bash "$INSTALL_SH" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "re-running install is idempotent (no failure on existing target)" {
  run bash "$INSTALL_SH"
  [ "$status" -eq 0 ]
  run bash "$INSTALL_SH"
  [ "$status" -eq 0 ]
  [ -L "${HOME}/.claude/skills/egloff-api" ]
}
