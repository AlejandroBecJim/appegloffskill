# tests/helpers/setup.bash — shared bats helper.
#
# Sandboxes HOME/TMPDIR per test, builds a fixture bare git remote with
# skills/egloff-api/ (+ optionally bin/egloff-api) committed, and exports the
# installer's env-override seams so tests never touch the real filesystem
# or the network.

REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
INSTALL_SH="${REPO_ROOT}/install.sh"

# add_fixture_skill TREE_DIR NAME
# Writes a minimal synthetic skill tree at TREE_DIR/skills/NAME/ (SKILL.md +
# assets/), matching the shape build_fixture_remote uses for egloff-api.
# Used both directly (against a plain checkout dir) and by the git-remote
# builders below (against a work_dir, before it's committed).
add_fixture_skill() {
  local tree_dir="$1" name="$2"

  mkdir -p "${tree_dir}/skills/${name}/assets"
  cat > "${tree_dir}/skills/${name}/SKILL.md" <<EOF
# fixture skill: ${name}
EOF
  cat > "${tree_dir}/skills/${name}/assets/${name}.sh" <<EOF
#!/usr/bin/env bash
echo "fixture asset: ${name}"
EOF
  chmod +x "${tree_dir}/skills/${name}/assets/${name}.sh"
}

# push_fixture_skill BARE_DIR NAME
# Adds a new fixture skill to an already-pushed bare remote, by cloning it,
# writing the skill tree with add_fixture_skill, committing, and pushing —
# mirrors advance_remote (tests/cli_update.bats), but for adding a skill
# rather than an empty commit. Used to simulate "a skill was added upstream
# since this project/checkout was last installed/updated".
push_fixture_skill() {
  local bare_dir="$1" name="$2"
  local tmp_clone
  tmp_clone="$(mktemp -d "${SANDBOX_TMP}/push-skill.XXXXXX")"
  git clone -q "$bare_dir" "$tmp_clone"
  add_fixture_skill "$tmp_clone" "$name"
  git -C "$tmp_clone" -c user.email="test@example.com" -c user.name="bats" add -A
  git -C "$tmp_clone" -c user.email="test@example.com" -c user.name="bats" commit -q -m "add fixture skill ${name}"
  git -C "$tmp_clone" push -q origin main
  rm -rf "$tmp_clone"
}

# build_fixture_remote BARE_DIR [with-cli|without-cli]
# Creates a bare git repo at BARE_DIR containing a committed skills/egloff-api/
# skill tree, and bin/egloff-api unless "without-cli" is passed. Also
# includes any skills named in EGLOFF_FIXTURE_EXTRA_SKILLS (space-separated),
# so tests can opt a fixture remote into a multi-skill tree without changing
# this function's positional signature.
build_fixture_remote() {
  local bare_dir="$1"
  local include_cli="${2:-with-cli}"
  local work_dir
  work_dir="$(mktemp -d "${SANDBOX_TMP}/fixture-src.XXXXXX")"

  mkdir -p "${work_dir}/skills/egloff-api/assets"
  cat > "${work_dir}/skills/egloff-api/SKILL.md" <<'EOF'
# fixture skill
EOF
  cat > "${work_dir}/skills/egloff-api/assets/egloff-api.sh" <<'EOF'
#!/usr/bin/env bash
echo "fixture asset"
EOF
  chmod +x "${work_dir}/skills/egloff-api/assets/egloff-api.sh"

  if [ "$include_cli" = "with-cli" ]; then
    mkdir -p "${work_dir}/bin"
    cat > "${work_dir}/bin/egloff-api" <<'EOF'
#!/usr/bin/env bash
echo "fixture cli"
EOF
    chmod +x "${work_dir}/bin/egloff-api"
  fi

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

# build_local_checkout DEST_DIR [with-cli|without-cli]
# Copies the real install.sh + skills/egloff-api/ into DEST_DIR (and
# optionally a fixture bin/egloff-api), so local-mode detection (sibling
# skills/egloff-api/ present, BASH_SOURCE readable) triggers on a controlled
# tree.
build_local_checkout() {
  local dest_dir="$1"
  local include_cli="${2:-without-cli}"

  mkdir -p "${dest_dir}/skills"
  cp "$INSTALL_SH" "${dest_dir}/install.sh"
  cp -R "${REPO_ROOT}/skills/egloff-api" "${dest_dir}/skills/egloff-api"

  if [ "$include_cli" = "with-cli" ]; then
    mkdir -p "${dest_dir}/bin"
    cat > "${dest_dir}/bin/egloff-api" <<'EOF'
#!/usr/bin/env bash
echo "fixture cli"
EOF
    chmod +x "${dest_dir}/bin/egloff-api"
  fi
}

# Call from each test file's setup().
sandbox_setup() {
  SANDBOX_HOME="$(mktemp -d)"
  SANDBOX_TMP="$(mktemp -d)"
  export HOME="$SANDBOX_HOME"
  export TMPDIR="$SANDBOX_TMP"

  export EGLOFF_INSTALL_ROOT="${HOME}/.local/share/egloff-api-skill"
  export EGLOFF_BIN_DIR="${HOME}/.local/bin"

  FIXTURE_REMOTE="${SANDBOX_TMP}/fixture-remote.git"
  build_fixture_remote "$FIXTURE_REMOTE"
  export EGLOFF_REPO_URL="$FIXTURE_REMOTE"

  : > "${HOME}/.bashrc"
  : > "${HOME}/.zshrc"
  : > "${HOME}/.profile"
}

# Call from each test file's teardown().
sandbox_teardown() {
  if [ -n "${SANDBOX_HOME:-}" ] && [ -d "${SANDBOX_HOME}" ]; then
    rm -rf "${SANDBOX_HOME}"
  fi
  if [ -n "${SANDBOX_TMP:-}" ] && [ -d "${SANDBOX_TMP}" ]; then
    rm -rf "${SANDBOX_TMP}"
  fi
}

# stub_bin NAME BODY
# Writes an executable fake "$NAME" script (with BODY as its content) into a
# sandbox-local directory prepended to PATH, ahead of any real binary with
# the same name. Used to stub `curl` (and, if ever needed, `jq`) so tests
# never touch the network.
stub_bin() {
  local name="$1" body="$2"
  local stub_dir="${SANDBOX_TMP}/stubbin"
  mkdir -p "$stub_dir"
  {
    printf '#!/usr/bin/env bash\n'
    printf '%s\n' "$body"
  } > "${stub_dir}/${name}"
  chmod +x "${stub_dir}/${name}"
  export PATH="${stub_dir}:${PATH}"
}

# stub_bin_absent NAME
# Removes NAME from PATH by shadowing every directory that provides it with
# a directory containing symlinks to every OTHER binary in that directory —
# so `command -v NAME` fails while every other tool bash/bats/the script
# under test needs keeps working. Mirrors hide_git_from_path's approach,
# generalized to any binary name.
stub_bin_absent() {
  local name="$1"
  local shadow_root="${SANDBOX_TMP}/no-${name}-bin"
  mkdir -p "$shadow_root"
  local newpath="" dir n=0 f base shadow_dir
  IFS=':' read -ra dirs <<< "$PATH"
  for dir in "${dirs[@]}"; do
    if [ -x "${dir}/${name}" ]; then
      n=$((n + 1))
      shadow_dir="${shadow_root}/${n}"
      mkdir -p "$shadow_dir"
      for f in "$dir"/*; do
        base="$(basename "$f")"
        [ "$base" = "$name" ] && continue
        [ -e "$f" ] && ln -sf "$f" "${shadow_dir}/${base}"
      done
      newpath="${newpath:+$newpath:}${shadow_dir}"
    else
      newpath="${newpath:+$newpath:}$dir"
    fi
  done
  export PATH="$newpath"
}

# write_projects_manifest JSON
# Writes JSON as the projects manifest at
# ${EGLOFF_STATE_ROOT:-${EGLOFF_INSTALL_ROOT}-state}/projects.json.
write_projects_manifest() {
  local json="$1"
  local dir="${EGLOFF_STATE_ROOT:-${EGLOFF_INSTALL_ROOT}-state}"
  mkdir -p -- "$dir"
  printf '%s' "$json" > "${dir}/projects.json"
}

# manifest_entry_json PATH [MODE] [TIMESTAMP]
# Prints a one-entry projects manifest JSON document.
manifest_entry_json() {
  local path="$1" mode="${2:-symlink}" ts="${3:-2020-01-01T00:00:00Z}"
  jq -n --arg p "$path" --arg m "$mode" --arg t "$ts" \
    '{version:1, projects:[{path:$p, mode:$m, installed_at:$t}]}'
}

# break_project_link PROJECT_DIR
# Creates PROJECT_DIR/.claude/skills/egloff-api as a broken symlink.
break_project_link() {
  local project_dir="$1"
  mkdir -p -- "${project_dir}/.claude/skills"
  ln -s "/nonexistent/egloff-api" "${project_dir}/.claude/skills/egloff-api"
}

# write_cfg URL TOKEN
# Writes a fixture ~/.config/egloff-api/config-equivalent file (honoring
# XDG_CONFIG_HOME if set) under the sandboxed HOME, mode 0600.
write_cfg() {
  local url="$1" token="$2"
  local dir="${XDG_CONFIG_HOME:-${HOME}/.config}/egloff-api"
  mkdir -p "$dir"
  (
    umask 077
    {
      printf 'EGLOFF_API_URL=%s\n' "$url"
      printf 'EGLOFF_API_TOKEN=%s\n' "$token"
    } > "${dir}/config"
  )
  chmod 600 "${dir}/config"
}
