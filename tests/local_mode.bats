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

@test "jq missing fails plain install with clear error" {
  stub_bin_absent jq

  run bash "$INSTALL_SH"
  [ "$status" -ne 0 ]
  [[ "$output" == *"jq"* ]]
}

@test "jq missing fails --project install with clear error" {
  stub_bin_absent jq
  local project_dir="${SANDBOX_TMP}/my-project"
  mkdir -p "$project_dir"

  run bash "$INSTALL_SH" --project "$project_dir"
  [ "$status" -ne 0 ]
  [[ "$output" == *"jq"* ]]
}

@test "--project install creates manifest with one entry (path, mode, installed_at)" {
  local project_dir="${SANDBOX_TMP}/my-project"
  mkdir -p "$project_dir"

  run bash "$INSTALL_SH" --project "$project_dir"
  [ "$status" -eq 0 ]

  local manifest="${EGLOFF_INSTALL_ROOT}-state/projects.json"
  [ -f "$manifest" ]

  local canon_project
  canon_project="$(cd -P "$project_dir" && pwd)"

  [ "$(jq -r '.version' "$manifest")" = "1" ]
  [ "$(jq -r '.projects | length' "$manifest")" = "1" ]
  [ "$(jq -r '.projects[0].path' "$manifest")" = "$canon_project" ]
  [ "$(jq -r '.projects[0].mode' "$manifest")" = "symlink" ]
  [ -n "$(jq -r '.projects[0].installed_at' "$manifest")" ]
  [ "$(jq -r '.projects[0].installed_at' "$manifest")" != "null" ]
}

@test "EGLOFF_STATE_ROOT override writes manifest under custom dir" {
  local custom_state="${SANDBOX_TMP}/custom-state"
  export EGLOFF_STATE_ROOT="$custom_state"
  local project_dir="${SANDBOX_TMP}/my-project"
  mkdir -p "$project_dir"

  run bash "$INSTALL_SH" --project "$project_dir"
  [ "$status" -eq 0 ]

  [ -f "${custom_state}/projects.json" ]
  [ ! -f "${EGLOFF_INSTALL_ROOT}-state/projects.json" ]
}

@test "reinstalling same --project path dedupes to one entry with refreshed installed_at" {
  local project_dir="${SANDBOX_TMP}/my-project"
  mkdir -p "$project_dir"
  local manifest="${EGLOFF_INSTALL_ROOT}-state/projects.json"

  run bash "$INSTALL_SH" --project "$project_dir"
  [ "$status" -eq 0 ]
  local first_ts
  first_ts="$(jq -r '.projects[0].installed_at' "$manifest")"

  sleep 1
  run bash "$INSTALL_SH" --project "$project_dir"
  [ "$status" -eq 0 ]

  [ "$(jq -r '.projects | length' "$manifest")" = "1" ]
  local second_ts
  second_ts="$(jq -r '.projects[0].installed_at' "$manifest")"
  [ "$second_ts" != "$first_ts" ]
}

@test "--project with --copy records mode:copy in manifest" {
  local project_dir="${SANDBOX_TMP}/my-project"
  mkdir -p "$project_dir"
  local manifest="${EGLOFF_INSTALL_ROOT}-state/projects.json"

  run bash "$INSTALL_SH" --project "$project_dir" --copy
  [ "$status" -eq 0 ]

  [ "$(jq -r '.projects[0].mode' "$manifest")" = "copy" ]
}

@test "manifest write failure warns but install still exits 0" {
  local project_dir="${SANDBOX_TMP}/my-project"
  mkdir -p "$project_dir"

  local readonly_parent="${SANDBOX_TMP}/readonly-parent"
  mkdir -p "$readonly_parent"
  export EGLOFF_STATE_ROOT="${readonly_parent}/state"
  chmod 500 "$readonly_parent"

  run bash "$INSTALL_SH" --project "$project_dir"
  chmod 700 "$readonly_parent"

  [ "$status" -eq 0 ]
  [[ "$output" == *"warning:"* ]]
  [ -L "${project_dir}/.claude/skills/egloff-api" ]
}

@test "corrupt manifest is replaced with a warning, not silently discarded" {
  local project_dir="${SANDBOX_TMP}/my-project"
  mkdir -p "$project_dir"
  write_projects_manifest '{not valid json'

  run bash "$INSTALL_SH" --project "$project_dir"
  [ "$status" -eq 0 ]
  [[ "$output" == *"warning: project manifest at"* ]]
  [[ "$output" == *"is corrupt"* ]]

  local manifest="${EGLOFF_INSTALL_ROOT}-state/projects.json"
  [ "$(jq -r '.projects | length' "$manifest")" = "1" ]
}
