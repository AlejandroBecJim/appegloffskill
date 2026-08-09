#!/usr/bin/env bash
# install.sh — install the egloff-api Claude Code skill and CLI, globally or
# into a project. Works identically whether run from a local checkout
# (./install.sh) or piped (curl -fsSL <raw-url>/install.sh | bash).
#
# See `usage()` below or run with -h/--help.

set -euo pipefail

# --- Testability / configuration seams -------------------------------------
# All three default to production values below; tests override them so no
# real network calls or filesystem state outside a sandbox are touched.
EGLOFF_REPO_URL="${EGLOFF_REPO_URL:-https://github.com/AlejandroBecJim/appegloffskill.git}"
EGLOFF_INSTALL_ROOT="${EGLOFF_INSTALL_ROOT:-${HOME}/.local/share/egloff-api-skill}"
EGLOFF_BIN_DIR="${EGLOFF_BIN_DIR:-${HOME}/.local/bin}"
EGLOFF_STATE_ROOT="${EGLOFF_STATE_ROOT:-${EGLOFF_INSTALL_ROOT}-state}"

usage() {
  cat <<'EOF'
Usage:
  ./install.sh                    Install globally (~/.claude/skills/egloff-api)
  ./install.sh --project PATH     Install into PATH/.claude/skills/egloff-api
  ./install.sh --copy             Copy files instead of symlinking (default: symlink)
  ./install.sh -h|--help          Show this help

Also works piped, without cloning first:
  curl -fsSL <raw-url>/install.sh | bash

Requires jq unconditionally (used to record/update the per-project install
manifest, even without --project). --project installs are tracked at
<EGLOFF_INSTALL_ROOT>-state/projects.json by default, overridable via the
EGLOFF_STATE_ROOT env var; 'egloff-api update' reads this manifest to
repair or prune project installs automatically.
EOF
}

# --- Arg parsing -------------------------------------------------------------
mode="symlink"
target=""
project_root=""

while [ $# -gt 0 ]; do
  case "$1" in
    --project)
      project_root="${2:?--project requires a path}"
      target="${project_root}/.claude/skills/egloff-api"
      shift 2
      ;;
    --copy)
      mode="copy"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument '$1'" >&2
      exit 1
      ;;
  esac
done

if [ -z "$target" ]; then
  target="${HOME}/.claude/skills/egloff-api"
fi

# --- Functions ---------------------------------------------------------------

require_git() {
  if ! command -v git >/dev/null 2>&1; then
    echo "error: git is required to install egloff-api via curl | bash but was not found on PATH — install git and re-run" >&2
    exit 1
  fi
}

require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "error: jq is required to install egloff-api but was not found on PATH — install jq and re-run" >&2
    exit 1
  fi
}

# Prints "local" or "bootstrap" on stdout.
detect_mode() {
  local script_path="${BASH_SOURCE[0]:-}"
  if [ -n "$script_path" ] && [ -r "$script_path" ]; then
    local script_dir
    script_dir="$(cd "$(dirname "$script_path")" && pwd)"
    if [ -d "${script_dir}/skills/egloff-api" ]; then
      echo "local"
      return 0
    fi
  fi
  echo "bootstrap"
}

# Clones or updates EGLOFF_REPO_URL into EGLOFF_INSTALL_ROOT and sets
# SOURCE_DIR to it.
bootstrap_source() {
  require_git

  if [ -d "${EGLOFF_INSTALL_ROOT}/.git" ] && git -C "$EGLOFF_INSTALL_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Updating existing install at ${EGLOFF_INSTALL_ROOT}..."
    if git -C "$EGLOFF_INSTALL_ROOT" fetch --depth=1 origin main -- \
      && git -C "$EGLOFF_INSTALL_ROOT" reset --hard origin/main -- ; then
      SOURCE_DIR="$EGLOFF_INSTALL_ROOT"
      return 0
    fi
    echo "warning: existing install at ${EGLOFF_INSTALL_ROOT} appears corrupt — reinstalling" >&2
    rm -rf "$EGLOFF_INSTALL_ROOT"
  elif [ -e "$EGLOFF_INSTALL_ROOT" ]; then
    echo "warning: ${EGLOFF_INSTALL_ROOT} exists but is not a valid git repo — reinstalling" >&2
    rm -rf "$EGLOFF_INSTALL_ROOT"
  fi

  echo "Cloning egloff-api into ${EGLOFF_INSTALL_ROOT}..."
  local tmp_clone
  tmp_clone="$(mktemp -d "${TMPDIR:-/tmp}/egloff-api-clone.XXXXXX")"
  git clone --depth=1 -- "$EGLOFF_REPO_URL" "$tmp_clone"
  mkdir -p "$(dirname "$EGLOFF_INSTALL_ROOT")"
  mv "$tmp_clone" "$EGLOFF_INSTALL_ROOT"
  SOURCE_DIR="$EGLOFF_INSTALL_ROOT"
}

# install_skill SOURCE_DIR TARGET_PATH MODE
install_skill() {
  local source_dir="$1"
  local target_path="$2"
  local install_mode="$3"
  local skill_source="${source_dir}/skills/egloff-api"

  if [ ! -d "$skill_source" ]; then
    echo "error: expected ${skill_source} to exist" >&2
    exit 1
  fi

  mkdir -p "$(dirname "$target_path")"

  if [ -e "$target_path" ] || [ -L "$target_path" ]; then
    echo "note: ${target_path} already exists — removing before reinstall"
    rm -rf "$target_path"
  fi

  if [ "$install_mode" = "copy" ]; then
    cp -R "$skill_source" "$target_path"
    echo "Copied to ${target_path}"
  else
    ln -s "$skill_source" "$target_path"
    echo "Symlinked ${target_path} -> ${skill_source}"
  fi
}

# link_cli SOURCE_DIR BIN_DIR RESOLVED_MODE
link_cli() {
  local source_dir="$1"
  local bin_dir="$2"
  local resolved_mode="$3"
  local cli_source="${source_dir}/bin/egloff-api"
  local cli_target="${bin_dir}/egloff-api"

  if [ ! -f "$cli_source" ]; then
    echo "warning: ${cli_source} not found — skipping CLI symlink (skill is still installed)" >&2
    return 0
  fi

  mkdir -p "$bin_dir"

  if [ -e "$cli_target" ] && [ ! -L "$cli_target" ]; then
    echo "warning: ${cli_target} already exists and is not managed by this installer — refusing to overwrite it" >&2
    return 0
  fi

  # Only chmod in bootstrap mode, where source_dir is our own managed clone
  # (EGLOFF_INSTALL_ROOT). In local mode source_dir is the user's actual git
  # checkout — mutating its tracked file permissions would dirty their
  # working tree with an unrelated mode change.
  if [ "$resolved_mode" = "bootstrap" ]; then
    chmod +x "$cli_source"
  elif [ ! -x "$cli_source" ]; then
    echo "warning: ${cli_source} is not executable and this installer won't chmod a local checkout — fix its permissions in git (chmod +x && git add) and reinstall" >&2
    return 0
  fi

  ln -sfn "$cli_source" "$cli_target"
  echo "Linked ${cli_target} -> ${cli_source}"
}

# record_project_install PROJECT_ROOT MODE — upserts (path, mode,
# installed_at) into ${EGLOFF_STATE_ROOT}/projects.json, deduped by
# canonical path. Writes atomically (mkdir -p, mktemp in the same dir under
# a scoped umask 077, chmod 600, mv -f), mirroring bin/egloff-api's
# write_config(). Never fails the install: on any jq/write error it warns
# and returns 0 (the symlink/copy already succeeded).
record_project_install() {
  local path="$1" install_mode="$2"
  local canon_path ts existing filter tmp_file

  if ! canon_path="$(cd -P "$path" 2>/dev/null && pwd)"; then
    echo "warning: could not canonicalize project path '${path}' — skipping manifest update" >&2
    return 0
  fi

  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  mkdir -p "$EGLOFF_STATE_ROOT" 2>/dev/null || {
    echo "warning: could not create ${EGLOFF_STATE_ROOT} — skipping manifest update" >&2
    return 0
  }

  local manifest_file="${EGLOFF_STATE_ROOT}/projects.json"
  if [ -r "$manifest_file" ] && existing="$(jq -e . "$manifest_file" 2>/dev/null)"; then
    :
  else
    if [ -r "$manifest_file" ]; then
      echo "warning: project manifest at ${manifest_file} is corrupt — replacing with a fresh manifest (previous entries lost)" >&2
    fi
    existing='{"version":1,"projects":[]}'
  fi

  filter='.version=1 | .projects=(((.projects//[])|map(select(.path!=$p)))+[{path:$p,mode:$m,installed_at:$t}])'

  (
    umask 077
    tmp_file="$(mktemp "${EGLOFF_STATE_ROOT}/.projects.json.XXXXXX")" || exit 1
    if ! printf '%s' "$existing" | jq --arg p "$canon_path" --arg m "$install_mode" --arg t "$ts" "$filter" > "$tmp_file"; then
      rm -f "$tmp_file"
      exit 1
    fi
    chmod 600 "$tmp_file"
    mv -f "$tmp_file" "$manifest_file"
  ) || echo "warning: could not update project manifest at ${manifest_file}" >&2

  return 0
}

# path_notice BIN_DIR
path_notice() {
  local bin_dir="$1"
  case ":$PATH:" in
    *":${bin_dir}:"*)
      ;;
    *)
      cat <<EOF

Note: ${bin_dir} is not on your PATH.
Add it manually (this installer never edits shell config files), e.g.:

  export PATH="${bin_dir}:\$PATH"

Add that line to your shell's rc file (~/.bashrc, ~/.zshrc, or ~/.profile)
if you want it to persist across sessions.
EOF
      ;;
  esac
}

# --- Main flow ----------------------------------------------------------------

require_jq

resolved_mode="$(detect_mode)"

if [ "$resolved_mode" = "local" ]; then
  SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  bootstrap_source
fi

install_skill "$SOURCE_DIR" "$target" "$mode"

if [ -n "$project_root" ]; then
  record_project_install "$project_root" "$mode"
fi

link_cli "$SOURCE_DIR" "$EGLOFF_BIN_DIR" "$resolved_mode"
path_notice "$EGLOFF_BIN_DIR"

cat <<EOF

Installed. Next steps:

  export EGLOFF_API_TOKEN="the-sanctum-token"   # Panel -> API Token page

The API URL is preset to https://app.egloff.com.mx, so a token is all you
need. Alternatively, run 'egloff-api' for the interactive setup assistant
(token-only prompt, persists to ~/.config/egloff-api/config).

  export EGLOFF_API_URL="https://your-instance.example.com"   # optional: point at another instance

Then ask Claude Code (in a session that loads this skill) to push or read
tasks/context entries, or call the CLI directly:

  egloff-api tasks:list
EOF
