# tests/helpers/setup.bash — shared bats helper.
#
# Sandboxes HOME/TMPDIR per test, builds a fixture bare git remote with
# egloff-api/ (+ optionally bin/egloff-api) committed, and exports the
# installer's env-override seams so tests never touch the real filesystem
# or the network.

REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
INSTALL_SH="${REPO_ROOT}/install.sh"

# build_fixture_remote BARE_DIR [with-cli|without-cli]
# Creates a bare git repo at BARE_DIR containing a committed egloff-api/
# skill tree, and bin/egloff-api unless "without-cli" is passed.
build_fixture_remote() {
  local bare_dir="$1"
  local include_cli="${2:-with-cli}"
  local work_dir
  work_dir="$(mktemp -d "${SANDBOX_TMP}/fixture-src.XXXXXX")"

  mkdir -p "${work_dir}/egloff-api/assets"
  cat > "${work_dir}/egloff-api/SKILL.md" <<'EOF'
# fixture skill
EOF
  cat > "${work_dir}/egloff-api/assets/egloff-api.sh" <<'EOF'
#!/usr/bin/env bash
echo "fixture asset"
EOF
  chmod +x "${work_dir}/egloff-api/assets/egloff-api.sh"

  if [ "$include_cli" = "with-cli" ]; then
    mkdir -p "${work_dir}/bin"
    cat > "${work_dir}/bin/egloff-api" <<'EOF'
#!/usr/bin/env bash
echo "fixture cli"
EOF
    chmod +x "${work_dir}/bin/egloff-api"
  fi

  git init -q "$work_dir"
  git -C "$work_dir" -c user.email="test@example.com" -c user.name="bats" add -A
  git -C "$work_dir" -c user.email="test@example.com" -c user.name="bats" commit -q -m "fixture commit"
  git -C "$work_dir" branch -M main

  git init -q --bare "$bare_dir"
  git -C "$work_dir" push -q "$bare_dir" main
  git -C "$bare_dir" symbolic-ref HEAD refs/heads/main
}

# build_local_checkout DEST_DIR [with-cli|without-cli]
# Copies the real install.sh + egloff-api/ into DEST_DIR (and optionally a
# fixture bin/egloff-api), so local-mode detection (sibling egloff-api/
# present, BASH_SOURCE readable) triggers on a controlled tree.
build_local_checkout() {
  local dest_dir="$1"
  local include_cli="${2:-without-cli}"

  mkdir -p "$dest_dir"
  cp "$INSTALL_SH" "${dest_dir}/install.sh"
  cp -R "${REPO_ROOT}/egloff-api" "${dest_dir}/egloff-api"

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
