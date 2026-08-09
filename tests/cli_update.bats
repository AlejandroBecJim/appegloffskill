#!/usr/bin/env bats
# egloff-api update: self-update the CLI/skill, in bootstrap (curl-installed)
# and local-checkout (developer clone) modes, without ever discarding user
# work. See skills/egloff-api's design doc / issue #12.

load 'helpers/setup'

CLI="${BATS_TEST_DIRNAME}/../bin/egloff-api"

setup() {
  sandbox_setup
}

teardown() {
  sandbox_teardown
}

# --- Update-specific fixtures ------------------------------------------------

# build_update_fixture_remote BARE_DIR
# Like build_fixture_remote, but bin/egloff-api is a real copy of the CLI
# under test (not the "fixture cli" stub) so a bootstrapped `egloff-api
# update` actually exercises cmd_update. Also includes any skills named in
# EGLOFF_FIXTURE_EXTRA_SKILLS (space-separated), same seam as
# build_fixture_remote.
build_update_fixture_remote() {
  local bare_dir="$1"
  local work_dir
  work_dir="$(mktemp -d "${SANDBOX_TMP}/upd-fixture-src.XXXXXX")"

  mkdir -p "${work_dir}/skills/egloff-api"
  cp -R "${REPO_ROOT}/skills/egloff-api/." "${work_dir}/skills/egloff-api/"
  cp "$INSTALL_SH" "${work_dir}/install.sh"
  mkdir -p "${work_dir}/bin"
  cp "$CLI" "${work_dir}/bin/egloff-api"
  chmod +x "${work_dir}/install.sh" "${work_dir}/bin/egloff-api"

  local extra_name
  for extra_name in ${EGLOFF_FIXTURE_EXTRA_SKILLS:-}; do
    add_fixture_skill "$work_dir" "$extra_name"
  done

  git init -q "$work_dir"
  git -C "$work_dir" -c user.email="test@example.com" -c user.name="bats" add -A
  git -C "$work_dir" -c user.email="test@example.com" -c user.name="bats" commit -q -m "fixture commit"
  git -C "$work_dir" branch -M main

  git init -q --bare "$bare_dir"
  git -C "$work_dir" push -q "$bare_dir" main
  git -C "$bare_dir" symbolic-ref HEAD refs/heads/main
}

# advance_remote BARE_DIR — adds an empty commit to a bare remote by pushing
# from a throwaway clone.
advance_remote() {
  local bare_dir="$1"
  local tmp_clone
  tmp_clone="$(mktemp -d "${SANDBOX_TMP}/adv.XXXXXX")"
  git clone -q "$bare_dir" "$tmp_clone"
  git -C "$tmp_clone" -c user.email="test@example.com" -c user.name="bats" commit -q --allow-empty -m "advance"
  git -C "$tmp_clone" push -q origin main
  rm -rf "$tmp_clone"
}

# bootstrap_update_fixture — points EGLOFF_REPO_URL at an update-capable
# fixture remote and bootstrap-installs it (populates EGLOFF_INSTALL_ROOT +
# symlinks), exactly like a first curl | bash run.
bootstrap_update_fixture() {
  UPD_REMOTE="${SANDBOX_TMP}/upd-fixture-remote.git"
  build_update_fixture_remote "$UPD_REMOTE"
  export EGLOFF_REPO_URL="$UPD_REMOTE"
  run bash < "$INSTALL_SH"
  [ "$status" -eq 0 ]
}

# build_git_local_checkout DEST_DIR — a local checkout (install.sh + skill +
# real CLI copy) with a real git history and an "origin" upstream, so
# _upd_detect_mode resolves to "local" and the local-mode git flow (fetch +
# ff-only merge) has something real to operate on. Also includes any skills
# named in EGLOFF_FIXTURE_EXTRA_SKILLS (space-separated), same seam as
# build_fixture_remote. Prints the origin bare repo path (no trailing
# newline).
build_git_local_checkout() {
  local dest_dir="$1"
  mkdir -p "${dest_dir}/skills" "${dest_dir}/bin"
  cp "$INSTALL_SH" "${dest_dir}/install.sh"
  cp -R "${REPO_ROOT}/skills/egloff-api" "${dest_dir}/skills/egloff-api"
  cp "$CLI" "${dest_dir}/bin/egloff-api"
  chmod +x "${dest_dir}/install.sh" "${dest_dir}/bin/egloff-api"

  local extra_name
  for extra_name in ${EGLOFF_FIXTURE_EXTRA_SKILLS:-}; do
    add_fixture_skill "$dest_dir" "$extra_name"
  done

  local origin_dir
  origin_dir="$(mktemp -d "${SANDBOX_TMP}/origin.XXXXXX")"
  git init -q --bare "$origin_dir"

  git init -q -b main "$dest_dir"
  git -C "$dest_dir" -c user.email="test@example.com" -c user.name="bats" add -A
  git -C "$dest_dir" -c user.email="test@example.com" -c user.name="bats" commit -q -m "initial"
  git -C "$dest_dir" remote add origin "$origin_dir"
  git -C "$dest_dir" push -q -u origin main
  git -C "$origin_dir" symbolic-ref HEAD refs/heads/main

  printf '%s' "$origin_dir"
}

# hide_git_from_path — removes `git` from every PATH directory that
# provides it (there can be more than one, e.g. Homebrew + Xcode CLT on
# macOS), each replaced by a shadow dir with symlinks to every OTHER binary
# in that directory — so `command -v git` fails while every other tool used
# by bats / bash / install.sh keeps working.
hide_git_from_path() {
  local shadow_root="${SANDBOX_TMP}/no-git-bin"
  mkdir -p "$shadow_root"
  local newpath="" dir n=0 f base shadow_dir
  IFS=':' read -ra dirs <<< "$PATH"
  for dir in "${dirs[@]}"; do
    if [ -x "${dir}/git" ]; then
      n=$((n + 1))
      shadow_dir="${shadow_root}/${n}"
      mkdir -p "$shadow_dir"
      for f in "$dir"/*; do
        base="$(basename "$f")"
        [ "$base" = "git" ] && continue
        [ -e "$f" ] && ln -sf "$f" "${shadow_dir}/${base}"
      done
      newpath="${newpath:+$newpath:}${shadow_dir}"
    else
      newpath="${newpath:+$newpath:}$dir"
    fi
  done
  export PATH="$newpath"
}

# =============================================================================
# Phase 1: Mode detection
# =============================================================================

@test "unit: _upd_detect_mode returns bootstrap under EGLOFF_INSTALL_ROOT symlink chain" {
  mkdir -p "${EGLOFF_INSTALL_ROOT}/bin"
  cp "$CLI" "${EGLOFF_INSTALL_ROOT}/bin/egloff-api"
  chmod +x "${EGLOFF_INSTALL_ROOT}/bin/egloff-api"
  mkdir -p "$EGLOFF_BIN_DIR"
  ln -s "${EGLOFF_INSTALL_ROOT}/bin/egloff-api" "${EGLOFF_BIN_DIR}/egloff-api"

  run bash -c "source '${EGLOFF_BIN_DIR}/egloff-api'; _upd_detect_mode"
  [ "$status" -eq 0 ]
  [ "$output" = "bootstrap" ]
}

@test "unit: _upd_detect_mode returns local for a sibling install.sh + .git checkout" {
  local checkout="${SANDBOX_TMP}/checkout"
  build_git_local_checkout "$checkout" >/dev/null

  run bash -c "source '${checkout}/bin/egloff-api'; _upd_detect_mode"
  [ "$status" -eq 0 ]
  [ "$output" = "local" ]
}

@test "unit: _upd_detect_mode fails and errors with a curl hint when undetectable" {
  local orphan="${SANDBOX_TMP}/orphan/bin"
  mkdir -p "$orphan"
  cp "$CLI" "${orphan}/egloff-api"
  chmod +x "${orphan}/egloff-api"

  run bash "${orphan}/egloff-api" update
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot determine how egloff-api was installed"* ]]
  [[ "$output" == *"curl -fsSL"* ]]
}

@test "git repository selection: update resolves SELF_ROOT even from an unrelated cwd" {
  bootstrap_update_fixture

  cd /
  run bash "${EGLOFF_BIN_DIR}/egloff-api" update
  [ "$status" -eq 0 ]
}

# =============================================================================
# Phase 2: Bootstrap-mode flow
# =============================================================================

@test "bootstrap update behind remote: pipes install.sh via stdin, reports before/after SHA, recreates symlinks" {
  bootstrap_update_fixture
  advance_remote "$UPD_REMOTE"

  run bash "${EGLOFF_BIN_DIR}/egloff-api" update
  [ "$status" -eq 0 ]
  [[ "$output" == *"Updated "* ]]
  [[ "$output" == *" -> "* ]]
  [ -L "${HOME}/.claude/skills/egloff-api" ]
  [ -L "${EGLOFF_BIN_DIR}/egloff-api" ]
}

@test "bootstrap update already up to date makes no destructive change and exits 0" {
  bootstrap_update_fixture

  local before_sha
  before_sha="$(git -C "$EGLOFF_INSTALL_ROOT" rev-parse HEAD)"

  run bash "${EGLOFF_BIN_DIR}/egloff-api" update
  [ "$status" -eq 0 ]
  [[ "$output" == *"Already up to date"* ]] || [[ "$output" == *"Updated "* ]]

  local after_sha
  after_sha="$(git -C "$EGLOFF_INSTALL_ROOT" rev-parse HEAD)"
  [ "$before_sha" = "$after_sha" ]
}

@test "bootstrap update: subprocess composition uses fixed argv, no eval, and tolerates spaces in EGLOFF_INSTALL_ROOT" {
  export EGLOFF_INSTALL_ROOT="${HOME}/.local/share/egloff api skill with spaces"
  bootstrap_update_fixture

  run bash "${EGLOFF_BIN_DIR}/egloff-api" update
  [ "$status" -eq 0 ]
}

# =============================================================================
# Phase 3: Local-mode safety gate + update
# =============================================================================

@test "local update: staged change aborts with exit 1 and mutates nothing" {
  local checkout="${SANDBOX_TMP}/checkout"
  build_git_local_checkout "$checkout" >/dev/null
  echo "dirty" > "${checkout}/staged.txt"
  git -C "$checkout" add staged.txt

  local before_sha
  before_sha="$(git -C "$checkout" rev-parse HEAD)"

  run bash "${checkout}/bin/egloff-api" update
  [ "$status" -eq 1 ]
  [[ "$output" == *"uncommitted changes"* ]]

  [ "$(git -C "$checkout" rev-parse HEAD)" = "$before_sha" ]
}

@test "local update: unstaged change aborts with exit 1" {
  local checkout="${SANDBOX_TMP}/checkout"
  build_git_local_checkout "$checkout" >/dev/null
  echo "dirty" >> "${checkout}/install.sh"

  run bash "${checkout}/bin/egloff-api" update
  [ "$status" -eq 1 ]
  [[ "$output" == *"uncommitted changes"* ]]
}

@test "local update: untracked file aborts with exit 1" {
  local checkout="${SANDBOX_TMP}/checkout"
  build_git_local_checkout "$checkout" >/dev/null
  echo "new" > "${checkout}/untracked.txt"

  run bash "${checkout}/bin/egloff-api" update
  [ "$status" -eq 1 ]
  [[ "$output" == *"uncommitted changes"* ]]
}

@test "local update: detached HEAD aborts with exit 1 and instructs to check out a branch" {
  local checkout="${SANDBOX_TMP}/checkout"
  build_git_local_checkout "$checkout" >/dev/null
  git -C "$checkout" checkout -q --detach HEAD

  run bash "${checkout}/bin/egloff-api" update
  [ "$status" -eq 1 ]
  [[ "$output" == *"detached HEAD"* ]]
  [[ "$output" == *"checkout"* ]]
}

@test "local update: no upstream configured aborts with exit 1" {
  local checkout="${SANDBOX_TMP}/checkout"
  build_git_local_checkout "$checkout" >/dev/null
  git -C "$checkout" branch --unset-upstream

  run bash "${checkout}/bin/egloff-api" update
  [ "$status" -eq 1 ]
  [[ "$output" == *"no upstream"* ]]
}

@test "local update: diverged branches abort with exit 1 and name the remedy" {
  local checkout origin
  checkout="${SANDBOX_TMP}/checkout"
  origin="$(build_git_local_checkout "$checkout")"

  advance_remote "$origin"
  git -C "$checkout" -c user.email="test@example.com" -c user.name="bats" commit -q --allow-empty -m "local divergent commit"

  run bash "${checkout}/bin/egloff-api" update
  [ "$status" -eq 1 ]
  [[ "$output" == *"diverged"* ]]
}

@test "local update: ahead-only checkout is a no-op that exits 0" {
  local checkout
  checkout="${SANDBOX_TMP}/checkout"
  build_git_local_checkout "$checkout" >/dev/null
  git -C "$checkout" -c user.email="test@example.com" -c user.name="bats" commit -q --allow-empty -m "local-only commit"

  run bash "${checkout}/bin/egloff-api" update
  [ "$status" -eq 0 ]
  [[ "$output" == *"ahead"* ]]
}

@test "local update: clean/tracked/non-diverged checkout fetches and fast-forward merges, reports before/after SHA" {
  local checkout origin
  checkout="${SANDBOX_TMP}/checkout"
  origin="$(build_git_local_checkout "$checkout")"
  advance_remote "$origin"

  run bash "${checkout}/bin/egloff-api" update
  [ "$status" -eq 0 ]
  [[ "$output" == *"Updated "* ]]
  [[ "$output" == *" -> "* ]]

  local head_sha origin_sha
  head_sha="$(git -C "$checkout" rev-parse HEAD)"
  origin_sha="$(git -C "$origin" rev-parse main)"
  [ "$head_sha" = "$origin_sha" ]
}

@test "local update: conditional relink only fires when the managed symlink is broken" {
  local checkout origin
  checkout="${SANDBOX_TMP}/checkout"
  origin="$(build_git_local_checkout "$checkout")"
  advance_remote "$origin"

  mkdir -p "$EGLOFF_BIN_DIR"
  ln -s "/nonexistent/egloff-api" "${EGLOFF_BIN_DIR}/egloff-api"

  run bash "${checkout}/bin/egloff-api" update
  [ "$status" -eq 0 ]
  [ -L "${EGLOFF_BIN_DIR}/egloff-api" ]

  local canon_checkout
  canon_checkout="$(cd -P "$checkout" && pwd)"
  [ "$(readlink "${EGLOFF_BIN_DIR}/egloff-api")" = "${canon_checkout}/bin/egloff-api" ]
}

@test "local update: does not relink when there is no broken managed symlink" {
  local checkout origin
  checkout="${SANDBOX_TMP}/checkout"
  origin="$(build_git_local_checkout "$checkout")"
  advance_remote "$origin"

  # No global symlinks exist at all (e.g. a --project-only install) — must
  # not be unconditionally (re)installed globally.
  run bash "${checkout}/bin/egloff-api" update
  [ "$status" -eq 0 ]
  [ ! -e "${EGLOFF_BIN_DIR}/egloff-api" ]
  [ ! -e "${HOME}/.claude/skills/egloff-api" ]
}

# =============================================================================
# Phase 4: Error handling
# =============================================================================

@test "git absent: update exits 1 with a missing-dependency message and curl fallback" {
  local checkout
  checkout="${SANDBOX_TMP}/checkout"
  build_git_local_checkout "$checkout" >/dev/null
  hide_git_from_path

  run bash "${checkout}/bin/egloff-api" update
  [ "$status" -eq 1 ]
  [[ "$output" == *"git"* ]]
  [[ "$output" == *"curl -fsSL"* ]]
}

@test "check_deps() invariant: git is never added to the shared dependency check" {
  run bash -c "grep -A4 '^check_deps()' '$CLI'"
  [[ "$output" != *"git"* ]]
}

@test "doctor and assistant never require git even when it is absent" {
  local checkout
  checkout="${SANDBOX_TMP}/checkout"
  build_git_local_checkout "$checkout" >/dev/null
  hide_git_from_path

  run bash "$CLI" doctor
  [[ "$output" != *"missing dependencies: git"* ]]
  [[ "$output" != *"missing dependencies:"*"git"* ]]
}

@test "fetch failure: unreachable remote exits 1, prints git stderr, leaves checkout unmodified" {
  local checkout origin
  checkout="${SANDBOX_TMP}/checkout"
  origin="$(build_git_local_checkout "$checkout")"
  local before_sha
  before_sha="$(git -C "$checkout" rev-parse HEAD)"

  rm -rf "$origin"

  run bash "${checkout}/bin/egloff-api" update
  [ "$status" -eq 1 ]
  [[ "$output" == *"error:"* ]]

  [ "$(git -C "$checkout" rev-parse HEAD)" = "$before_sha" ]
}

# =============================================================================
# Phase 5: Dispatch & usage wiring
# =============================================================================

@test "usage listings mention update" {
  run bash "$CLI"
  run bash -c "grep -n 'update' '$CLI' | grep -i usage"
  run grep -c "update" "$CLI"
  [ "$output" -gt 0 ]
}

@test "unknown command usage string lists update as a valid subcommand" {
  run bash "$CLI" bogus-command
  [ "$status" -eq 1 ]
  [[ "$output" == *"update"* ]]
}

@test "doctor mentions egloff-api update as the way to refresh the installation" {
  run bash "$CLI" doctor
  [[ "$output" == *"egloff-api update"* ]]
}

# =============================================================================
# Phase 6: Project manifest reconciliation
# =============================================================================

@test "local update repairs broken project link" {
  local checkout origin
  checkout="${SANDBOX_TMP}/checkout"
  origin="$(build_git_local_checkout "$checkout")"
  advance_remote "$origin"

  local project_dir="${SANDBOX_TMP}/my-project"
  break_project_link "$project_dir"
  local canon_project
  canon_project="$(cd -P "$project_dir" && pwd)"
  write_projects_manifest "$(manifest_entry_json "$canon_project")"

  run bash "${checkout}/bin/egloff-api" update
  [ "$status" -eq 0 ]
  [ -e "${project_dir}/.claude/skills/egloff-api" ]
}

@test "bootstrap update repairs broken project link" {
  bootstrap_update_fixture
  advance_remote "$UPD_REMOTE"

  local project_dir="${SANDBOX_TMP}/my-project"
  break_project_link "$project_dir"
  local canon_project
  canon_project="$(cd -P "$project_dir" && pwd)"
  write_projects_manifest "$(manifest_entry_json "$canon_project")"

  run bash "${EGLOFF_BIN_DIR}/egloff-api" update
  [ "$status" -eq 0 ]
  [ -e "${project_dir}/.claude/skills/egloff-api" ]
}

@test "healthy manifest entry is a no-op during update" {
  local checkout origin
  checkout="${SANDBOX_TMP}/checkout"
  origin="$(build_git_local_checkout "$checkout")"
  advance_remote "$origin"

  local project_dir="${SANDBOX_TMP}/my-project"
  mkdir -p "$project_dir"
  run bash "$INSTALL_SH" --project "$project_dir"
  [ "$status" -eq 0 ]

  run bash "${checkout}/bin/egloff-api" update
  [ "$status" -eq 0 ]
  [[ "$output" == *"Project installs: 1 ok, 0 repaired, 0 pruned"* ]]
}

@test "deleted project root is pruned and reported in update summary" {
  local checkout origin
  checkout="${SANDBOX_TMP}/checkout"
  origin="$(build_git_local_checkout "$checkout")"
  advance_remote "$origin"

  local project_dir="${SANDBOX_TMP}/gone-project"
  mkdir -p "$project_dir"
  local canon_project
  canon_project="$(cd -P "$project_dir" && pwd)"
  write_projects_manifest "$(manifest_entry_json "$canon_project")"
  rm -rf "$project_dir"

  run bash "${checkout}/bin/egloff-api" update
  [ "$status" -eq 0 ]
  [[ "$output" == *"$canon_project"* ]]
  [[ "$output" == *"Project installs: 0 ok, 0 repaired, 1 pruned"* ]]

  local manifest="${EGLOFF_INSTALL_ROOT}-state/projects.json"
  [ "$(jq -r '.projects | length' "$manifest")" = "0" ]
}

@test "absent manifest: update completes normally, no error, no reconciliation output" {
  local checkout origin
  checkout="${SANDBOX_TMP}/checkout"
  origin="$(build_git_local_checkout "$checkout")"
  advance_remote "$origin"

  run bash "${checkout}/bin/egloff-api" update
  [ "$status" -eq 0 ]
  [[ "$output" != *"Project installs:"* ]]
}

@test "corrupt manifest: update prints warning, skips reconciliation, still completes" {
  local checkout origin
  checkout="${SANDBOX_TMP}/checkout"
  origin="$(build_git_local_checkout "$checkout")"
  advance_remote "$origin"

  write_projects_manifest '{not valid json'

  run bash "${checkout}/bin/egloff-api" update
  [ "$status" -eq 0 ]
  [[ "$output" == *"warning:"* ]]
  [[ "$output" != *"Project installs:"* ]]
}

@test "empty manifest ({version:1,projects:[]}): zero repairs, zero prunes, no error" {
  local checkout origin
  checkout="${SANDBOX_TMP}/checkout"
  origin="$(build_git_local_checkout "$checkout")"
  advance_remote "$origin"

  write_projects_manifest '{"version":1,"projects":[]}'

  run bash "${checkout}/bin/egloff-api" update
  [ "$status" -eq 0 ]
  [[ "$output" == *"Project installs: 0 ok, 0 repaired, 0 pruned"* ]]
}

@test "manifest entry path containing spaces is reconciled without word-splitting errors" {
  local checkout origin
  checkout="${SANDBOX_TMP}/checkout"
  origin="$(build_git_local_checkout "$checkout")"
  advance_remote "$origin"

  local project_dir="${SANDBOX_TMP}/my project with spaces"
  break_project_link "$project_dir"
  local canon_project
  canon_project="$(cd -P "$project_dir" && pwd)"
  write_projects_manifest "$(manifest_entry_json "$canon_project")"

  run bash "${checkout}/bin/egloff-api" update
  [ "$status" -eq 0 ]
  [ -e "${project_dir}/.claude/skills/egloff-api" ]
}

@test "manifest entry path with leading '-' and spaces is never interpreted as a flag during repair" {
  local checkout origin
  checkout="${SANDBOX_TMP}/checkout"
  origin="$(build_git_local_checkout "$checkout")"
  advance_remote "$origin"

  local project_dir="${SANDBOX_TMP}/-my project"
  mkdir -p -- "$project_dir"
  break_project_link "$project_dir"
  local canon_project
  canon_project="$(cd -P -- "$project_dir" && pwd)"
  write_projects_manifest "$(manifest_entry_json "$canon_project")"

  run bash "${checkout}/bin/egloff-api" update
  [ "$status" -eq 0 ]
  [ -e "${project_dir}/.claude/skills/egloff-api" ]
}

@test "update in local mode leaves git status --porcelain empty after reconciliation" {
  local checkout origin
  checkout="${SANDBOX_TMP}/checkout"
  origin="$(build_git_local_checkout "$checkout")"
  advance_remote "$origin"

  local project_dir="${SANDBOX_TMP}/my-project"
  break_project_link "$project_dir"
  local canon_project
  canon_project="$(cd -P "$project_dir" && pwd)"
  write_projects_manifest "$(manifest_entry_json "$canon_project")"

  run bash "${checkout}/bin/egloff-api" update
  [ "$status" -eq 0 ]

  local status_out
  status_out="$(git -C "$checkout" status --porcelain)"
  [ -z "$status_out" ]
}

# =============================================================================
# Phase 8: Multi-skill discovery — global repair, project reconciliation,
# orphan reporting
# =============================================================================

@test "local update repairs only the broken skill's global link, leaves the healthy one alone" {
  local checkout origin
  checkout="${SANDBOX_TMP}/checkout"
  EGLOFF_FIXTURE_EXTRA_SKILLS="second-skill" origin="$(build_git_local_checkout "$checkout")"

  run bash "${checkout}/install.sh"
  [ "$status" -eq 0 ]
  [ -L "${HOME}/.claude/skills/egloff-api" ]
  [ -L "${HOME}/.claude/skills/second-skill" ]

  local healthy_canon
  healthy_canon="$(cd -P "${HOME}/.claude/skills/egloff-api" && pwd)"

  rm -f "${HOME}/.claude/skills/second-skill"
  ln -s "/nonexistent/second-skill" "${HOME}/.claude/skills/second-skill"

  advance_remote "$origin"

  run bash "${checkout}/bin/egloff-api" update
  [ "$status" -eq 0 ]
  [ -L "${HOME}/.claude/skills/second-skill" ]
  [ -e "${HOME}/.claude/skills/second-skill" ]
  [ "$(cd -P "${HOME}/.claude/skills/egloff-api" && pwd)" = "$healthy_canon" ]
}

@test "local update: a --project-only skill install is never promoted to a global install (evidence gate)" {
  local checkout origin
  checkout="${SANDBOX_TMP}/checkout"
  EGLOFF_FIXTURE_EXTRA_SKILLS="second-skill" origin="$(build_git_local_checkout "$checkout")"
  advance_remote "$origin"

  local project_dir="${SANDBOX_TMP}/my-project"
  mkdir -p "$project_dir"
  run bash "${checkout}/install.sh" --project "$project_dir"
  [ "$status" -eq 0 ]
  [ -L "${project_dir}/.claude/skills/second-skill" ]
  [ ! -e "${HOME}/.claude/skills/second-skill" ]

  run bash "${checkout}/bin/egloff-api" update
  [ "$status" -eq 0 ]
  [ ! -e "${HOME}/.claude/skills/second-skill" ]
  [ ! -e "${HOME}/.claude/skills/egloff-api" ]
}

@test "local update: reconcile installs a newly-added skill into an already-registered project" {
  local checkout origin
  checkout="${SANDBOX_TMP}/checkout"
  origin="$(build_git_local_checkout "$checkout")"

  local project_dir="${SANDBOX_TMP}/my-project"
  mkdir -p "$project_dir"
  run bash "${checkout}/install.sh" --project "$project_dir"
  [ "$status" -eq 0 ]
  [ -L "${project_dir}/.claude/skills/egloff-api" ]
  [ ! -e "${project_dir}/.claude/skills/second-skill" ]

  push_fixture_skill "$origin" "second-skill"

  run bash "${checkout}/bin/egloff-api" update
  [ "$status" -eq 0 ]
  [ -e "${project_dir}/.claude/skills/second-skill" ]
  [[ "$output" == *"Project installs: 0 ok, 1 repaired, 0 pruned"* ]]
}

@test "bootstrap update reports a skill removed from the repo as orphaned but leaves it installed" {
  UPD_REMOTE="${SANDBOX_TMP}/upd-fixture-remote.git"
  EGLOFF_FIXTURE_EXTRA_SKILLS="second-skill" build_update_fixture_remote "$UPD_REMOTE"
  export EGLOFF_REPO_URL="$UPD_REMOTE"
  run bash < "$INSTALL_SH"
  [ "$status" -eq 0 ]
  [ -L "${HOME}/.claude/skills/second-skill" ]

  local tmp_clone
  tmp_clone="$(mktemp -d "${SANDBOX_TMP}/rm-skill.XXXXXX")"
  git clone -q "$UPD_REMOTE" "$tmp_clone"
  git -C "$tmp_clone" rm -rq skills/second-skill
  git -C "$tmp_clone" -c user.email="test@example.com" -c user.name="bats" commit -q -m "remove second-skill"
  git -C "$tmp_clone" push -q origin main
  rm -rf "$tmp_clone"

  run bash "${EGLOFF_BIN_DIR}/egloff-api" update
  [ "$status" -eq 0 ]
  [[ "$output" == *"second-skill"* ]]
  [[ "$output" == *"orphan"* ]]
  [ -L "${HOME}/.claude/skills/second-skill" ]
}

@test "local update reports a skill removed from the repo as orphaned for a --project install" {
  local checkout origin
  checkout="${SANDBOX_TMP}/checkout"
  EGLOFF_FIXTURE_EXTRA_SKILLS="second-skill" origin="$(build_git_local_checkout "$checkout")"

  local project_dir="${SANDBOX_TMP}/my-project"
  mkdir -p "$project_dir"
  run bash "${checkout}/install.sh" --project "$project_dir"
  [ "$status" -eq 0 ]
  [ -L "${project_dir}/.claude/skills/second-skill" ]

  local tmp_clone
  tmp_clone="$(mktemp -d "${SANDBOX_TMP}/rm-skill.XXXXXX")"
  git clone -q "$origin" "$tmp_clone"
  git -C "$tmp_clone" rm -rq skills/second-skill
  git -C "$tmp_clone" -c user.email="test@example.com" -c user.name="bats" commit -q -m "remove second-skill"
  git -C "$tmp_clone" push -q origin main
  rm -rf "$tmp_clone"

  advance_remote "$origin"

  run bash "${checkout}/bin/egloff-api" update
  [ "$status" -eq 0 ]
  [[ "$output" == *"second-skill"* ]]
  [[ "$output" == *"orphan"* ]]
  [ -L "${project_dir}/.claude/skills/second-skill" ]
}

@test "local update reports an orphaned skill even when the checkout path traverses a symlink" {
  mkdir -p "${SANDBOX_TMP}/real-dir"
  ln -s "${SANDBOX_TMP}/real-dir" "${SANDBOX_TMP}/symlinked-dir"

  local checkout origin
  checkout="${SANDBOX_TMP}/symlinked-dir/checkout"
  EGLOFF_FIXTURE_EXTRA_SKILLS="second-skill" origin="$(build_git_local_checkout "$checkout")"

  run bash "${checkout}/install.sh"
  [ "$status" -eq 0 ]
  [ -L "${HOME}/.claude/skills/second-skill" ]

  local tmp_clone
  tmp_clone="$(mktemp -d "${SANDBOX_TMP}/rm-skill.XXXXXX")"
  git clone -q "$origin" "$tmp_clone"
  git -C "$tmp_clone" rm -rq skills/second-skill
  git -C "$tmp_clone" -c user.email="test@example.com" -c user.name="bats" commit -q -m "remove second-skill"
  git -C "$tmp_clone" push -q origin main
  rm -rf "$tmp_clone"

  advance_remote "$origin"

  run bash "${checkout}/bin/egloff-api" update
  [ "$status" -eq 0 ]
  [[ "$output" == *"second-skill"* ]]
  [[ "$output" == *"orphan"* ]]
  [ -L "${HOME}/.claude/skills/second-skill" ]
}

@test "unrelated third-party skill directory under ~/.claude/skills/ is never reported as orphaned" {
  bootstrap_update_fixture
  mkdir -p "${HOME}/.claude/skills/third-party-skill"
  echo "not managed by us" > "${HOME}/.claude/skills/third-party-skill/SKILL.md"
  advance_remote "$UPD_REMOTE"

  run bash "${EGLOFF_BIN_DIR}/egloff-api" update
  [ "$status" -eq 0 ]
  [[ "$output" != *"third-party-skill"* ]]
  [ -d "${HOME}/.claude/skills/third-party-skill" ]
}

# =============================================================================
# Phase 7: Full-suite regression (spot check; full run happens via tests/run.sh)
# =============================================================================

@test "doctor still exits non-zero with no config (no regression)" {
  unset EGLOFF_API_URL EGLOFF_API_TOKEN
  run bash "$CLI" doctor
  [ "$status" -ne 0 ]
}
