#!/usr/bin/env bash
# install.sh — install the egloff-api Claude Code skill globally or into a project.
#
# Usage:
#   ./install.sh                    Install globally (~/.claude/skills/egloff-api)
#   ./install.sh --project PATH     Install into PATH/.claude/skills/egloff-api
#   ./install.sh --copy [...]       Copy files instead of symlinking (default: symlink)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="${SCRIPT_DIR}/egloff-api"

mode="symlink"
target=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)
      target="${2:?--project requires a path}/.claude/skills/egloff-api"
      shift 2
      ;;
    --copy)
      mode="copy"
      shift
      ;;
    -h|--help)
      sed -n '2,7p' "${BASH_SOURCE[0]}"
      exit 0
      ;;
    *)
      echo "error: unknown argument '$1'" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$target" ]]; then
  target="${HOME}/.claude/skills/egloff-api"
fi

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "error: expected ${SOURCE_DIR} to exist — run this script from the repo root" >&2
  exit 1
fi

mkdir -p "$(dirname "$target")"

if [[ -e "$target" || -L "$target" ]]; then
  echo "note: ${target} already exists — removing before reinstall"
  rm -rf "$target"
fi

if [[ "$mode" == "copy" ]]; then
  cp -R "$SOURCE_DIR" "$target"
  echo "Copied to ${target}"
else
  ln -s "$SOURCE_DIR" "$target"
  echo "Symlinked ${target} -> ${SOURCE_DIR}"
fi

chmod +x "${target}/assets/egloff-api.sh" 2>/dev/null || true

cat <<EOF

Installed. Next steps:

  export EGLOFF_API_URL="https://your-instance.example.com"
  export EGLOFF_API_TOKEN="the-sanctum-token"   # Panel -> API Token page

Then ask Claude Code (in a session that loads this skill) to push or read
tasks/context entries, or call the script directly:

  ${target}/assets/egloff-api.sh tasks:list
EOF
