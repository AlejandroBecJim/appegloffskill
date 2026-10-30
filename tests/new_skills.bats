#!/usr/bin/env bats
# Structural checks for the general-purpose skills added under skills/.

load 'helpers/setup'

NEW_SKILLS=(architecture-patterns)

setup() {
  sandbox_setup
}

teardown() {
  sandbox_teardown
}

@test "each new skill has a SKILL.md with matching name and Apache-2.0 license" {
  for s in "${NEW_SKILLS[@]}"; do
    f="${REPO_ROOT}/skills/${s}/SKILL.md"
    [ -f "$f" ]
    grep -q "^name: ${s}$" "$f"
    grep -q '^description: "Trigger: ' "$f"
    grep -q '^license: Apache-2.0$' "$f"
    grep -q '^## Activation Contract' "$f"
    grep -q '^## Output Contract' "$f"
  done
}

@test "architecture-patterns ships stack references, restructure guide, budget and escalation" {
  d="${REPO_ROOT}/skills/architecture-patterns"
  [ -f "${d}/SKILL.md" ]
  for r in laravel-php angular react csharp python restructure; do
    [ -f "${d}/references/${r}.md" ]
  done
  grep -q '^## File budget' "${d}/SKILL.md"
  grep -q '^## Escalation' "${d}/SKILL.md"
}
