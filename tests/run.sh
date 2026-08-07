#!/usr/bin/env bash
# tests/run.sh — run the bats-core suite.
#
# Prefers a `bats` already on PATH (e.g. `brew install bats-core`); falls
# back to the git-submodule copy at tests/bats/bin/bats when not found.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if command -v bats >/dev/null 2>&1; then
  BATS_BIN="bats"
elif [ -x "${SCRIPT_DIR}/bats/bin/bats" ]; then
  BATS_BIN="${SCRIPT_DIR}/bats/bin/bats"
else
  echo "error: bats not found on PATH and ${SCRIPT_DIR}/bats/bin/bats does not exist." >&2
  echo "Install it with 'brew install bats-core', or run:" >&2
  echo "  git submodule update --init --recursive" >&2
  exit 1
fi

exec "$BATS_BIN" "${SCRIPT_DIR}"/*.bats
