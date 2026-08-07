#!/usr/bin/env bats
# Bootstrap mode: clone into EGLOFF_INSTALL_ROOT on first run, update in
# place (fetch --depth=1 && reset --hard) on subsequent runs, and recover
# from a corrupt existing install root. Uses the fixture bare remote only
# — no real network calls.

load 'helpers/setup'

setup() {
  sandbox_setup
}

teardown() {
  sandbox_teardown
}

# Runs the installer in bootstrap mode by piping its bytes through bash
# (no BASH_SOURCE[0] file on disk => mode detection resolves to bootstrap,
# same as curl | bash).
run_piped() {
  bash < "$INSTALL_SH" "$@"
}

@test "first-time bootstrap clones the fixture remote into EGLOFF_INSTALL_ROOT" {
  run run_piped
  [ "$status" -eq 0 ]
  [ -d "${EGLOFF_INSTALL_ROOT}/.git" ]
  [ -d "${EGLOFF_INSTALL_ROOT}/egloff-api" ]
  [ -L "${HOME}/.claude/skills/egloff-api" ]
}

@test "repeated bootstrap updates in place without duplication, exits 0 both times" {
  run run_piped
  [ "$status" -eq 0 ]

  local first_git_dir
  first_git_dir="$(cd "${EGLOFF_INSTALL_ROOT}" && git rev-parse --git-dir)"

  run run_piped
  [ "$status" -eq 0 ]

  # Still exactly one clone at EGLOFF_INSTALL_ROOT, no sibling duplicate dir.
  [ -d "${EGLOFF_INSTALL_ROOT}/.git" ]
  [ ! -d "${EGLOFF_INSTALL_ROOT}-1" ]
  local count
  count="$(find "$(dirname "$EGLOFF_INSTALL_ROOT")" -maxdepth 1 -type d -name "$(basename "$EGLOFF_INSTALL_ROOT")*" | wc -l | tr -d ' ')"
  [ "$count" -eq 1 ]
}

@test "corrupt install root is removed and recloned" {
  mkdir -p "$EGLOFF_INSTALL_ROOT"
  echo "not a git repo" > "${EGLOFF_INSTALL_ROOT}/garbage"

  run run_piped
  [ "$status" -eq 0 ]
  [ -d "${EGLOFF_INSTALL_ROOT}/.git" ]
  [ -d "${EGLOFF_INSTALL_ROOT}/egloff-api" ]
  [ ! -f "${EGLOFF_INSTALL_ROOT}/garbage" ]
}

@test "bootstrap works from an unrelated cwd" {
  cd /
  run run_piped
  [ "$status" -eq 0 ]
  [ -d "${EGLOFF_INSTALL_ROOT}/.git" ]
}
