#!/usr/bin/env bash
# install.sh — install every Claude Code skill under skills/ (egloff-api and
# any others) and the egloff-api CLI, globally or into a project. Works
# identically whether run from a local checkout (./install.sh) or piped
# (curl -fsSL <raw-url>/install.sh | bash).
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

# Delimiters of the managed block written into agent instruction files.
SKILLS_BLOCK_START="<!-- egloff-skills:start -->"
SKILLS_BLOCK_END="<!-- egloff-skills:end -->"

usage() {
  cat <<'EOF'
Usage:
  ./install.sh                    Install all skills globally (~/.claude/skills)
  ./install.sh --project PATH     Install all skills into PATH/.claude/skills
  ./install.sh --copy             Copy files instead of symlinking (default: symlink)
  ./install.sh --no-register      Do not write the skills block into agent instruction files
  ./install.sh -h|--help          Show this help

Also works piped, without cloning first:
  curl -fsSL <raw-url>/install.sh | bash

Requires jq unconditionally (used to record/update the per-project install
manifest, even without --project). --project installs are tracked at
<EGLOFF_INSTALL_ROOT>-state/projects.json by default, overridable via the
EGLOFF_STATE_ROOT env var; 'egloff-api update' reads this manifest to
repair or prune project installs automatically.

Agent registration: after installing, a managed block listing every skill
(name, trigger, installed SKILL.md path) is written between
<!-- egloff-skills:start --> / <!-- egloff-skills:end --> markers into
~/.claude/CLAUDE.md and, only when the agent's config dir already exists,
~/.codex/AGENTS.md, ~/.config/opencode/AGENTS.md and ~/.gemini/GEMINI.md
(--project: PATH/CLAUDE.md and PATH/AGENTS.md). Content outside the markers
is never touched. Opt out with --no-register or EGLOFF_NO_REGISTER=1.
EOF
}

# --- Arg parsing -------------------------------------------------------------
mode="symlink"
dest_root=""
project_root=""
register="yes"

# Env-var opt-out (any non-empty value other than "0"); --no-register below
# does the same per invocation.
case "${EGLOFF_NO_REGISTER:-}" in
  ""|0) ;;
  *) register="no" ;;
esac

while [ $# -gt 0 ]; do
  case "$1" in
    --project)
      project_root="${2:?--project requires a path}"
      dest_root="${project_root}/.claude/skills"
      shift 2
      ;;
    --copy)
      mode="copy"
      shift
      ;;
    --no-register)
      register="no"
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

if [ -z "$dest_root" ]; then
  dest_root="${HOME}/.claude/skills"
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

# discover_skills SOURCE_DIR — prints one skill name per line for every
# directory (not file) directly under SOURCE_DIR/skills/. Sorted, POSIX
# glob-based (no `ls -1`/`find` name-parsing pitfalls); `*/` already skips
# dotfiles, and the `-d` guard handles the literal-glob no-match case
# without needing a global `shopt -s nullglob`.
discover_skills() {
  local source_dir="$1"
  local d
  for d in "${source_dir}"/skills/*/ ; do
    [ -d "$d" ] || continue
    basename "${d%/}"
  done
}

# install_skill SOURCE_DIR SKILL_NAME DEST_ROOT MODE
install_skill() {
  local source_dir="$1"
  local skill_name="$2"
  local dest_root="$3"
  local install_mode="$4"
  local skill_source="${source_dir}/skills/${skill_name}"
  local target_path="${dest_root}/${skill_name}"

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

# record_project_install PROJECT_ROOT MODE REGISTER — upserts (path, mode,
# installed_at, and register:false when REGISTER is "no") into ${EGLOFF_STATE_ROOT}/projects.json, deduped by
# canonical path. Writes atomically (mkdir -p, mktemp in the same dir under
# a scoped umask 077, chmod 600, mv -f), mirroring bin/egloff-api's
# write_config(). Never fails the install: on any jq/write error it warns
# and returns 0 (the symlink/copy already succeeded).
record_project_install() {
  local path="$1" install_mode="$2" reg="${3:-yes}"
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

  filter='.version=1 | .projects=(((.projects//[])|map(select(.path!=$p)))+[({path:$p,mode:$m,installed_at:$t}+(if $r=="no" then {register:false} else {} end))])'

  (
    umask 077
    tmp_file="$(mktemp "${EGLOFF_STATE_ROOT}/.projects.json.XXXXXX")" || exit 1
    if ! printf '%s' "$existing" | jq --arg p "$canon_path" --arg m "$install_mode" --arg t "$ts" --arg r "$reg" "$filter" > "$tmp_file"; then
      rm -f "$tmp_file"
      exit 1
    fi
    chmod 600 "$tmp_file"
    mv -f "$tmp_file" "$manifest_file"
  ) || echo "warning: could not update project manifest at ${manifest_file}" >&2

  return 0
}

# skill_frontmatter_field FILE KEY — prints the value of a top-level
# `KEY: value` line from FILE's YAML frontmatter (the block between the
# leading `---` lines), with one layer of surrounding single or double quotes
# removed. Prints nothing when FILE has no frontmatter or no such key. Only
# single-line scalar values are supported (all that SKILL.md files use here).
skill_frontmatter_field() {
  local file="$1" key="$2" value
  value="$(awk -v key="$key" '
    { sub(/\r$/, "") }
    NR == 1 { if ($0 != "---") exit; next }
    $0 == "---" { exit }
    index($0, key ":") == 1 {
      v = substr($0, length(key) + 2)
      sub(/^[ \t]+/, "", v)
      sub(/[ \t]+$/, "", v)
      print v
      exit
    }
  ' "$file" 2>/dev/null)" || value=""

  case "$value" in
    \"?*\")
      value="${value#\"}"
      value="${value%\"}"
      value="${value//\\\"/\"}"
      ;;
    \'?*\')
      value="${value#\'}"
      value="${value%\'}"
      value="${value//\'\'/\'}"
      ;;
  esac
  printf '%s' "$value"
}

# sanitize_block_text VALUE — prints VALUE made safe for the always-loaded
# instruction files: control characters and newlines dropped/turned into
# spaces, whitespace runs collapsed, HTML-comment delimiters defused (so a
# description can never forge or break the block markers) and the result
# capped at 300 characters with a trailing "...".
sanitize_block_text() {
  local v
  v="$(printf '%s' "$1" | tr '\n\r\t' '   ' | tr -d '\000-\010\013\014\016-\037\177' | tr -s ' ')"
  v="${v# }"
  v="${v% }"
  while [[ "$v" == *"<!--"* || "$v" == *"-->"* ]]; do
    v="${v//<!--/< !--}"
    v="${v//-->/-- >}"
  done
  if [ "${#v}" -gt 300 ]; then
    v="${v:0:297}..."
  fi
  printf '%s' "$v"
}

# build_skills_block SOURCE_DIR DEST_ROOT — prints the managed block (markers
# included, no trailing newline) listing every skill under SOURCE_DIR/skills/
# with its sanitized frontmatter name + description and the INSTALLED path
# DEST_ROOT/<skill>/SKILL.md (absolute for global installs, relative to the
# project root for --project so no local path leaks into a shared file). The block is rebuilt from scratch every time,
# so a skill removed from skills/ simply disappears from it.
build_skills_block() {
  local source_dir="$1" dest_root="$2"
  local skill_name skill_md name desc

  printf '%s\n' "$SKILLS_BLOCK_START"
  printf '%s\n' "## Egloff skills (managed by egloff-api — do not edit between the markers)"
  printf '\n'
  printf '%s\n' "When a request matches a skill trigger below, read that SKILL.md before answering."
  printf '\n'
  while IFS= read -r skill_name; do
    [ -n "$skill_name" ] || continue
    skill_md="${source_dir}/skills/${skill_name}/SKILL.md"
    name="$(sanitize_block_text "$(skill_frontmatter_field "$skill_md" name)")"
    desc="$(sanitize_block_text "$(skill_frontmatter_field "$skill_md" description)")"
    printf -- '- **%s**' "${name:-$skill_name}"
    [ -n "$desc" ] && printf ' — %s' "$desc"
    printf '\n'
    printf '  SKILL.md: %s/%s/SKILL.md\n' "$dest_root" "$skill_name"
  done <<< "$(discover_skills "$source_dir")"
  printf '%s' "$SKILLS_BLOCK_END"
}

# write_managed_block FILE BLOCK — replaces the marker-delimited block in
# FILE in place, or appends it when absent (creating FILE if needed). Bytes
# outside the markers are preserved exactly; a symlinked FILE is written
# through to its target; the file mode is kept. Atomic: mktemp in the same
# dir + mv -f. A lone/duplicated/out-of-order marker, or any I/O problem,
# warns on stderr, leaves FILE untouched and returns 1.
write_managed_block() {
  local file="$1" block="$2"
  local target="$file" hop=0 link dir content="" new before after rest tmp_file

  # Resolve symlinks (dotfile managers often link CLAUDE.md) so mv replaces
  # the real file instead of clobbering the link. Capped as a cycle guard.
  while [ -L "$target" ]; do
    hop=$((hop + 1))
    if [ "$hop" -gt 40 ]; then
      echo "warning: too many symlink hops resolving ${file} — skipping agent registration there" >&2
      return 1
    fi
    link="$(readlink "$target")"
    case "$link" in
      /*) target="$link" ;;
      *) target="$(dirname "$target")/${link}" ;;
    esac
  done

  dir="$(dirname "$target")"
  if [ -e "$target" ]; then
    if [ ! -f "$target" ] || ! content="$(cat -- "$target"; printf x)"; then
      echo "warning: cannot read ${file} as a regular file — skipping agent registration there" >&2
      return 1
    fi
    content="${content%x}"
  fi

  if [[ "$content" == *"$SKILLS_BLOCK_START"* || "$content" == *"$SKILLS_BLOCK_END"* ]]; then
    before="${content%%"$SKILLS_BLOCK_START"*}"
    after="${content#*"$SKILLS_BLOCK_START"}"
    rest="${after#*"$SKILLS_BLOCK_END"}"
    if [[ "$content" != *"$SKILLS_BLOCK_START"* || "$after" != *"$SKILLS_BLOCK_END"* \
       || "${after%%"$SKILLS_BLOCK_END"*}" == *"$SKILLS_BLOCK_START"* \
       || "$rest" == *"$SKILLS_BLOCK_START"* || "$rest" == *"$SKILLS_BLOCK_END"* ]]; then
      echo "warning: ${file} has unbalanced egloff-skills markers — leaving it untouched; fix or remove them and re-run" >&2
      return 1
    fi
    new="${before}${block}${rest}"
  elif [ -z "$content" ]; then
    new="${block}"$'\n'
  else
    [ "${content%$'\n'}" = "$content" ] && content="${content}"$'\n'
    new="${content}"$'\n'"${block}"$'\n'
  fi

  if [ -f "$target" ] && [ "$new" = "$content" ]; then
    return 0
  fi

  if ! mkdir -p "$dir" 2>/dev/null \
    || ! tmp_file="$(mktemp "${dir}/.egloff-skills.XXXXXX" 2>/dev/null)"; then
    echo "warning: cannot write to ${dir} — skipping agent registration for ${file}" >&2
    return 1
  fi
  # cp -p seeds the temp file with the original mode; new files get 0644.
  if { if [ -f "$target" ]; then cp -p "$target" "$tmp_file"; else chmod 644 "$tmp_file"; fi; } \
    && printf '%s' "$new" > "$tmp_file" \
    && mv -f "$tmp_file" "$target"; then
    return 0
  fi
  rm -f "$tmp_file"
  echo "warning: could not update ${file} — skipping agent registration there" >&2
  return 1
}

# register_skills SOURCE_DIR DEST_ROOT PROJECT_ROOT — writes the managed
# skills block into every agent instruction file that applies. Global
# (PROJECT_ROOT empty): ~/.claude/CLAUDE.md always, plus ~/.codex/AGENTS.md,
# ~/.config/opencode/AGENTS.md and ~/.gemini/GEMINI.md only when that
# agent's config dir already exists (an agent we never create the dir for).
# Project: PROJECT_ROOT/CLAUDE.md and PROJECT_ROOT/AGENTS.md. Never fails
# the install: every problem is a warning.
register_skills() {
  local source_dir="$1" dest_root="$2" proj="$3"
  local targets=() block file updated=()

  if [ -n "$proj" ]; then
    targets=("${proj}/CLAUDE.md" "${proj}/AGENTS.md")
  else
    targets=("${HOME}/.claude/CLAUDE.md")
    [ -d "${HOME}/.codex" ] && targets+=("${HOME}/.codex/AGENTS.md")
    [ -d "${HOME}/.config/opencode" ] && targets+=("${HOME}/.config/opencode/AGENTS.md")
    [ -d "${HOME}/.gemini" ] && targets+=("${HOME}/.gemini/GEMINI.md")
  fi

  if [ -z "$(discover_skills "$source_dir")" ]; then
    return 0
  fi
  block="$(build_skills_block "$source_dir" "$dest_root")" || {
    echo "warning: could not build the skills block — skipping agent registration" >&2
    return 0
  }

  for file in "${targets[@]}"; do
    if write_managed_block "$file" "$block"; then
      updated+=("$file")
    fi
  done

  if [ "${#updated[@]}" -gt 0 ]; then
    echo "Registered skills for agents in:"
    for file in "${updated[@]}"; do
      echo "  ${file}"
    done
  fi
  return 0
}

# record_register_pref REGISTER — remembers a global opt-out as the marker
# file ${EGLOFF_STATE_ROOT}/no-register (created for "no", removed otherwise)
# so 'egloff-api update' keeps honoring it. Per-project opt-outs live in the
# manifest instead (record_project_install). Never fails the install.
record_register_pref() {
  local marker="${EGLOFF_STATE_ROOT}/no-register"
  if [ "$1" = "no" ]; then
    if ! { mkdir -p "$EGLOFF_STATE_ROOT" && : > "$marker"; } 2>/dev/null; then
      echo "warning: could not record the --no-register preference at ${marker}" >&2
    fi
  else
    rm -f "$marker" 2>/dev/null || true
  fi
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
  SOURCE_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  bootstrap_source
fi

skill_names="$(discover_skills "$SOURCE_DIR")"
if [ -z "$skill_names" ]; then
  echo "warning: no skill directories found under ${SOURCE_DIR}/skills — nothing to install" >&2
else
  while IFS= read -r skill_name; do
    [ -n "$skill_name" ] || continue
    install_skill "$SOURCE_DIR" "$skill_name" "$dest_root" "$mode"
  done <<< "$skill_names"
fi

if [ -n "$project_root" ]; then
  record_project_install "$project_root" "$mode" "$register"
else
  record_register_pref "$register"
fi

if [ "$register" = "yes" ]; then
  reg_project=""
  reg_dest="$dest_root"
  if [ -n "$project_root" ]; then
    if reg_project="$(cd -P "$project_root" 2>/dev/null && pwd)"; then
      reg_dest=".claude/skills"
    else
      echo "warning: could not canonicalize project path '${project_root}' — skipping agent registration" >&2
      reg_project=""
      register="no"
    fi
  fi
  if [ "$register" = "yes" ]; then
    register_skills "$SOURCE_DIR" "$reg_dest" "$reg_project" || true
  fi
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
