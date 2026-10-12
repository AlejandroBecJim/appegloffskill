#!/usr/bin/env bats
# rfc-format, adr-format and constitution: the skills shipped in this repo are
# discovered by install.sh like any other skill (linked under ~/.claude/skills
# and listed in the managed agent-registration block) and carry their contract.

load 'helpers/setup'

NEW_SKILLS=(rfc-format adr-format constitution)

setup() {
  sandbox_setup
  CHECKOUT="${SANDBOX_TMP}/checkout"
  build_local_checkout "$CHECKOUT" with-cli
  local s
  for s in "${NEW_SKILLS[@]}"; do
    cp -R "${REPO_ROOT}/skills/${s}" "${CHECKOUT}/skills/${s}"
  done
}

teardown() {
  chmod -R u+w "${SANDBOX_HOME}" 2>/dev/null || true
  sandbox_teardown
}

@test "each new skill has a SKILL.md whose frontmatter name matches its directory" {
  local s
  for s in "${NEW_SKILLS[@]}"; do
    [ -f "${REPO_ROOT}/skills/${s}/SKILL.md" ]
    grep -qx "name: ${s}" "${REPO_ROOT}/skills/${s}/SKILL.md"
  done
}

@test "install.sh links the new skills like the existing ones" {
  run bash "${CHECKOUT}/install.sh"
  [ "$status" -eq 0 ]
  local s
  for s in "${NEW_SKILLS[@]}"; do
    [ -L "${HOME}/.claude/skills/${s}" ]
    [ -f "${HOME}/.claude/skills/${s}/SKILL.md" ]
  done
}

@test "the managed CLAUDE.md block lists the new skills" {
  run bash "${CHECKOUT}/install.sh"
  [ "$status" -eq 0 ]
  local s
  for s in "${NEW_SKILLS[@]}"; do
    grep -qF "**${s}**" "${HOME}/.claude/CLAUDE.md"
    grep -qF "${HOME}/.claude/skills/${s}/SKILL.md" "${HOME}/.claude/CLAUDE.md"
  done
}

@test "rfc-format carries the full and the short template" {
  local f="${REPO_ROOT}/skills/rfc-format/SKILL.md"
  grep -q '## Plan de reversa' "$f"
  grep -q '## Cambio visual' "$f"
}

@test "adr-format carries its template" {
  local f="${REPO_ROOT}/skills/adr-format/SKILL.md"
  grep -q '## Contexto' "$f"
  grep -q '## Consecuencias' "$f"
}

@test "constitution asks one question at a time" {
  grep -qi 'one question at a time' "${REPO_ROOT}/skills/constitution/SKILL.md"
}
