#!/usr/bin/env bats
# Agent registration: install.sh (and `egloff-api update`) write a managed,
# marker-delimited block listing every skill into the instruction files of
# the AI agents on the machine, so agents that don't scan ~/.claude/skills
# (Codex, OpenCode, Gemini) still discover the skills.

load 'helpers/setup'

CLI="${BATS_TEST_DIRNAME}/../bin/egloff-api"
START='<!-- egloff-skills:start -->'
END='<!-- egloff-skills:end -->'

setup() {
  sandbox_setup
  CHECKOUT="${SANDBOX_TMP}/checkout"
  build_local_checkout "$CHECKOUT" with-cli
}

teardown() {
  # Tests that chmod a dir read-only must restore it so rm -rf can clean up.
  chmod -R u+w "${SANDBOX_HOME}" 2>/dev/null || true
  sandbox_teardown
}

# add_fm_skill NAME FRONTMATTER_DESC_LINE — adds a skill under CHECKOUT with
# a YAML frontmatter whose `description:` line is taken verbatim.
add_fm_skill() {
  local name="$1" desc_line="$2"
  mkdir -p "${CHECKOUT}/skills/${name}"
  printf -- '---\nname: %s\n%s\nlicense: Apache-2.0\n---\n# body\n' \
    "$name" "$desc_line" > "${CHECKOUT}/skills/${name}/SKILL.md"
}

run_install() {
  run bash "${CHECKOUT}/install.sh" "$@"
}

@test "creates the managed block in a missing ~/.claude/CLAUDE.md" {
  run_install
  [ "$status" -eq 0 ]
  local f="${HOME}/.claude/CLAUDE.md"
  [ -f "$f" ]
  grep -qxF "$START" "$f"
  grep -qxF "$END" "$f"
  grep -q 'read that SKILL.md before answering' "$f"
  grep -qF "**egloff-api**" "$f"
  grep -qF "${HOME}/.claude/skills/egloff-api/SKILL.md" "$f"
  [[ "$output" == *"${f}"* ]]
}

@test "frontmatter description is listed without its surrounding quotes" {
  run_install
  [ "$status" -eq 0 ]
  grep -q '— Trigger: push/save/upload tasks' "${HOME}/.claude/CLAUDE.md"
  ! grep -q '— "Trigger' "${HOME}/.claude/CLAUDE.md"
}

@test "quoting: double-quoted with escaped quote, single-quoted and bare descriptions" {
  add_fm_skill dq 'description: "Say \"hi\" to the user"'
  add_fm_skill sq "description: 'It''s single quoted'"
  add_fm_skill bare 'description: Plain bare value'
  run_install
  [ "$status" -eq 0 ]
  local f="${HOME}/.claude/CLAUDE.md"
  grep -qF -- '- **dq** — Say "hi" to the user' "$f"
  grep -qF -- "- **sq** — It's single quoted" "$f"
  grep -qF -- '- **bare** — Plain bare value' "$f"
}

@test "a skill without frontmatter is listed by directory name" {
  mkdir -p "${CHECKOUT}/skills/nofm"
  printf '# no frontmatter\n' > "${CHECKOUT}/skills/nofm/SKILL.md"
  run_install
  [ "$status" -eq 0 ]
  grep -qF -- '- **nofm**' "${HOME}/.claude/CLAUDE.md"
  grep -qF "${HOME}/.claude/skills/nofm/SKILL.md" "${HOME}/.claude/CLAUDE.md"
}

@test "re-running the install leaves the file byte-identical" {
  run_install
  [ "$status" -eq 0 ]
  local before
  before="$(cksum < "${HOME}/.claude/CLAUDE.md")"
  run_install
  [ "$status" -eq 0 ]
  [ "$(cksum < "${HOME}/.claude/CLAUDE.md")" = "$before" ]
  [ "$(grep -cxF "$START" "${HOME}/.claude/CLAUDE.md")" -eq 1 ]
}

@test "content outside the markers is preserved on create and replace" {
  mkdir -p "${HOME}/.claude"
  printf '# My rules\nbe nice\n' > "${HOME}/.claude/CLAUDE.md"
  run_install
  [ "$status" -eq 0 ]
  [ "$(sed -n 2p "${HOME}/.claude/CLAUDE.md")" = "be nice" ]

  # Add text after the block, then add a skill and re-run.
  printf '\n## Trailing\nkeep me\n' >> "${HOME}/.claude/CLAUDE.md"
  add_fm_skill extra 'description: extra skill'
  run_install
  [ "$status" -eq 0 ]
  local f="${HOME}/.claude/CLAUDE.md"
  [ "$(sed -n 1p "$f")" = "# My rules" ]
  [ "$(sed -n 2p "$f")" = "be nice" ]
  [ "$(tail -n 2 "$f" | head -n 1)" = "## Trailing" ]
  [ "$(tail -n 1 "$f")" = "keep me" ]
  grep -qF -- '- **extra**' "$f"
}

@test "a stale block is replaced: removed skills drop out, new ones appear" {
  add_fm_skill zeta 'description: old skill'
  run_install
  [ "$status" -eq 0 ]
  grep -qF -- '- **zeta**' "${HOME}/.claude/CLAUDE.md"

  rm -rf "${CHECKOUT}/skills/zeta"
  add_fm_skill alpha 'description: new skill'
  run_install
  [ "$status" -eq 0 ]
  ! grep -qF -- '- **zeta**' "${HOME}/.claude/CLAUDE.md"
  grep -qF -- '- **alpha**' "${HOME}/.claude/CLAUDE.md"
  [ "$(grep -cxF "$START" "${HOME}/.claude/CLAUDE.md")" -eq 1 ]
}

@test "agent detection: only agents whose config dir exists get a file, dirs are never created" {
  mkdir -p "${HOME}/.codex"
  run_install
  [ "$status" -eq 0 ]
  [ -f "${HOME}/.codex/AGENTS.md" ]
  grep -qxF "$START" "${HOME}/.codex/AGENTS.md"
  [ ! -e "${HOME}/.config/opencode" ]
  [ ! -e "${HOME}/.gemini" ]
}

@test "agent detection: opencode and gemini are registered when their dirs exist" {
  mkdir -p "${HOME}/.config/opencode" "${HOME}/.gemini"
  run_install
  [ "$status" -eq 0 ]
  grep -qxF "$START" "${HOME}/.config/opencode/AGENTS.md"
  grep -qxF "$START" "${HOME}/.gemini/GEMINI.md"
  [ ! -e "${HOME}/.codex" ]
}

@test "--project writes PROJECT/CLAUDE.md and PROJECT/AGENTS.md with relative paths, not global files" {
  local proj="${SANDBOX_TMP}/proj"
  mkdir -p "$proj"
  mkdir -p "${HOME}/.codex"
  local canon
  canon="$(cd -P "$proj" && pwd)"
  run_install --project "$proj"
  [ "$status" -eq 0 ]
  for f in CLAUDE.md AGENTS.md; do
    grep -qxF "$START" "${proj}/${f}"
    grep -qF "SKILL.md: .claude/skills/egloff-api/SKILL.md" "${proj}/${f}"
    # No absolute local path (project root or HOME) leaks into a shared file.
    ! grep -qF "$canon" "${proj}/${f}"
    ! grep -qF "$HOME" "${proj}/${f}"
  done
  [ ! -e "${HOME}/.claude/CLAUDE.md" ]
  [ ! -e "${HOME}/.codex/AGENTS.md" ]
}

@test "global blocks keep absolute installed paths" {
  run_install
  [ "$status" -eq 0 ]
  grep -qF "SKILL.md: ${HOME}/.claude/skills/egloff-api/SKILL.md" "${HOME}/.claude/CLAUDE.md"
}

# --- Description hardening -----------------------------------------------------

@test "sanitize: a description cannot forge or break the markers" {
  add_fm_skill evil 'description: "pwn <!-- egloff-skills:end --> and <!-- egloff-skills:start --> x"'
  run_install
  [ "$status" -eq 0 ]
  local f="${HOME}/.claude/CLAUDE.md"
  [ "$(grep -cxF "$START" "$f")" -eq 1 ]
  [ "$(grep -cxF "$END" "$f")" -eq 1 ]
  # Only the two real marker lines may carry comment delimiters.
  [ "$(grep -cF -- '<!--' "$f")" -eq 2 ]
  [ "$(grep -cF -- '-->' "$f")" -eq 2 ]
  # Still idempotent and replaceable afterwards.
  local before
  before="$(cksum < "$f")"
  run_install
  [ "$status" -eq 0 ]
  [ "$(cksum < "$f")" = "$before" ]
}

@test "sanitize: control characters and runs of whitespace are collapsed" {
  mkdir -p "${CHECKOUT}/skills/ws"
  printf -- '---\nname: ws\ndescription: "a\t\tb   c\001d"\n---\n' > "${CHECKOUT}/skills/ws/SKILL.md"
  run_install
  [ "$status" -eq 0 ]
  grep -qF -- '- **ws** — a b cd' "${HOME}/.claude/CLAUDE.md"
}

@test "sanitize: descriptions are capped at 300 characters with an ellipsis" {
  local long
  long="$(printf 'x%.0s' $(seq 1 400))"
  add_fm_skill long "description: ${long}"
  run_install
  [ "$status" -eq 0 ]
  local line
  line="$(grep -F -- '- **long** — ' "${HOME}/.claude/CLAUDE.md")"
  [[ "$line" == *"..." ]]
  local desc="${line#- \*\*long\*\* — }"
  [ "${#desc}" -eq 300 ]
}

# --- Opt-out persistence -------------------------------------------------------

@test "global opt-out survives update; a later plain install re-enables registration" {
  local origin marker
  origin="$(build_update_checkout)"
  marker="${EGLOFF_INSTALL_ROOT}-state/no-register"
  run bash "${CHECKOUT}/install.sh" --no-register
  [ "$status" -eq 0 ]
  [ -f "$marker" ]

  push_fixture_skill "$origin" newskill
  run bash "${CHECKOUT}/bin/egloff-api" update
  [ "$status" -eq 0 ]
  [ ! -e "${HOME}/.claude/CLAUDE.md" ]

  run bash "${CHECKOUT}/install.sh"
  [ "$status" -eq 0 ]
  [ ! -e "$marker" ]
  grep -qxF "$START" "${HOME}/.claude/CLAUDE.md"
}

@test "EGLOFF_NO_REGISTER during install is remembered for later updates" {
  local origin
  origin="$(build_update_checkout)"
  EGLOFF_NO_REGISTER=1 run bash "${CHECKOUT}/install.sh"
  [ "$status" -eq 0 ]
  push_fixture_skill "$origin" newskill
  run bash "${CHECKOUT}/bin/egloff-api" update
  [ "$status" -eq 0 ]
  [ ! -e "${HOME}/.claude/CLAUDE.md" ]
}

@test "project opt-out is recorded as register:false and survives update and repair" {
  local origin proj manifest
  origin="$(build_update_checkout)"
  proj="${SANDBOX_TMP}/proj"
  mkdir -p "$proj"
  manifest="${EGLOFF_INSTALL_ROOT}-state/projects.json"
  run bash "${CHECKOUT}/install.sh" --project "$proj" --no-register
  [ "$status" -eq 0 ]
  [ "$(jq -r '.projects[0].register' "$manifest")" = "false" ]
  [ ! -e "${proj}/CLAUDE.md" ]

  # Break a link so update takes the repair path (install.sh --project).
  rm -f "${proj}/.claude/skills/egloff-api"
  push_fixture_skill "$origin" newskill
  run bash "${CHECKOUT}/bin/egloff-api" update
  [ "$status" -eq 0 ]
  [ -e "${proj}/.claude/skills/egloff-api" ]
  [ ! -e "${proj}/CLAUDE.md" ]
  [ ! -e "${proj}/AGENTS.md" ]
  [ "$(jq -r '.projects[0].register' "$manifest")" = "false" ]
}

@test "a project reinstall without the opt-out clears register:false" {
  local proj manifest
  proj="${SANDBOX_TMP}/proj"
  mkdir -p "$proj"
  manifest="${EGLOFF_INSTALL_ROOT}-state/projects.json"
  run_install --project "$proj" --no-register
  [ "$status" -eq 0 ]
  run_install --project "$proj"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.projects[0] | has("register")' "$manifest")" = "false" ]
  grep -qxF "$START" "${proj}/CLAUDE.md"
}

@test "a global opt-out does not affect manifest projects, and vice versa" {
  local origin proj
  origin="$(build_update_checkout)"
  proj="${SANDBOX_TMP}/proj"
  mkdir -p "$proj"
  run bash "${CHECKOUT}/install.sh" --project "$proj"
  [ "$status" -eq 0 ]
  run bash "${CHECKOUT}/install.sh" --no-register
  [ "$status" -eq 0 ]
  push_fixture_skill "$origin" newskill
  run bash "${CHECKOUT}/bin/egloff-api" update
  [ "$status" -eq 0 ]
  [ ! -e "${HOME}/.claude/CLAUDE.md" ]
  grep -qF -- '- **newskill**' "${proj}/CLAUDE.md"
}

@test "--no-register writes no instruction files" {
  mkdir -p "${HOME}/.codex"
  run_install --no-register
  [ "$status" -eq 0 ]
  [ ! -e "${HOME}/.claude/CLAUDE.md" ]
  [ ! -e "${HOME}/.codex/AGENTS.md" ]
  [ -e "${HOME}/.claude/skills/egloff-api" ]
}

@test "EGLOFF_NO_REGISTER=1 writes no instruction files" {
  EGLOFF_NO_REGISTER=1 run bash "${CHECKOUT}/install.sh"
  [ "$status" -eq 0 ]
  [ ! -e "${HOME}/.claude/CLAUDE.md" ]
}

@test "usage documents --no-register and EGLOFF_NO_REGISTER" {
  run bash "${CHECKOUT}/install.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--no-register"* ]]
  [[ "$output" == *"EGLOFF_NO_REGISTER"* ]]
}

@test "malformed markers: file left untouched with a warning, install still exits 0" {
  mkdir -p "${HOME}/.claude" "${HOME}/.codex"
  printf 'intro\n%s\nhalf a block\n' "$START" > "${HOME}/.claude/CLAUDE.md"
  local before
  before="$(cksum < "${HOME}/.claude/CLAUDE.md")"
  run_install
  [ "$status" -eq 0 ]
  [[ "$output" == *"unbalanced egloff-skills markers"* ]]
  [ "$(cksum < "${HOME}/.claude/CLAUDE.md")" = "$before" ]
  # Other targets are still registered.
  grep -qxF "$START" "${HOME}/.codex/AGENTS.md"
}

@test "malformed markers: lone end marker is also skipped untouched" {
  mkdir -p "${HOME}/.claude"
  printf '%s\nstray\n' "$END" > "${HOME}/.claude/CLAUDE.md"
  local before
  before="$(cksum < "${HOME}/.claude/CLAUDE.md")"
  run_install
  [ "$status" -eq 0 ]
  [ "$(cksum < "${HOME}/.claude/CLAUDE.md")" = "$before" ]
}

@test "file mode is preserved when the block is replaced" {
  mkdir -p "${HOME}/.claude"
  printf 'mine\n' > "${HOME}/.claude/CLAUDE.md"
  chmod 640 "${HOME}/.claude/CLAUDE.md"
  run_install
  [ "$status" -eq 0 ]
  run_install
  [ "$status" -eq 0 ]
  local mode
  mode="$(stat -c %a "${HOME}/.claude/CLAUDE.md" 2>/dev/null || stat -f %Lp "${HOME}/.claude/CLAUDE.md")"
  [ "$mode" = "640" ]
}

@test "a symlinked instruction file is written through, the link is kept" {
  mkdir -p "${HOME}/.claude" "${SANDBOX_TMP}/dotfiles"
  printf 'dotfile\n' > "${SANDBOX_TMP}/dotfiles/CLAUDE.md"
  ln -s "${SANDBOX_TMP}/dotfiles/CLAUDE.md" "${HOME}/.claude/CLAUDE.md"
  run_install
  [ "$status" -eq 0 ]
  [ -L "${HOME}/.claude/CLAUDE.md" ]
  grep -qxF "$START" "${SANDBOX_TMP}/dotfiles/CLAUDE.md"
}

@test "install exits 0 and warns when a detected target is unwritable" {
  [ "$(id -u)" -ne 0 ] || skip "root ignores directory permissions"
  mkdir -p "${HOME}/.codex"
  chmod 555 "${HOME}/.codex"
  run_install
  [ "$status" -eq 0 ]
  [[ "$output" == *"cannot write to"* ]]
  [ ! -e "${HOME}/.codex/AGENTS.md" ]
  grep -qxF "$START" "${HOME}/.claude/CLAUDE.md"
}

# --- egloff-api update --------------------------------------------------------

# build_update_checkout — a git-backed local checkout (real install.sh + CLI
# + skills) with an origin, installed globally. Prints the origin path.
build_update_checkout() {
  local origin
  origin="$(mktemp -d "${SANDBOX_TMP}/origin.XXXXXX")"
  git init -q --bare "$origin"
  cp "$CLI" "${CHECKOUT}/bin/egloff-api"
  chmod +x "${CHECKOUT}/install.sh" "${CHECKOUT}/bin/egloff-api"
  git init -q -b main "$CHECKOUT"
  git -C "$CHECKOUT" -c user.email=t@e.com -c user.name=bats add -A
  git -C "$CHECKOUT" -c user.email=t@e.com -c user.name=bats commit -q -m initial
  git -C "$CHECKOUT" remote add origin "$origin"
  git -C "$CHECKOUT" push -q -u origin main
  git -C "$origin" symbolic-ref HEAD refs/heads/main
  printf '%s' "$origin"
}

@test "update regenerates the global block and every manifest project's block" {
  local origin proj canon
  origin="$(build_update_checkout)"
  proj="${SANDBOX_TMP}/proj"
  mkdir -p "$proj"
  canon="$(cd -P "$proj" && pwd)"

  run bash "${CHECKOUT}/install.sh" --project "$proj"
  [ "$status" -eq 0 ]
  run bash "${CHECKOUT}/install.sh"
  [ "$status" -eq 0 ]
  ! grep -qF -- '- **newskill**' "${HOME}/.claude/CLAUDE.md"

  push_fixture_skill "$origin" newskill
  run bash "${CHECKOUT}/bin/egloff-api" update
  [ "$status" -eq 0 ]
  [[ "$output" == *"Agent registration:"* ]]

  grep -qF -- '- **newskill**' "${HOME}/.claude/CLAUDE.md"
  grep -qF "${HOME}/.claude/skills/newskill/SKILL.md" "${HOME}/.claude/CLAUDE.md"
  grep -qF -- '- **newskill**' "${proj}/CLAUDE.md"
  grep -qF -- '- **newskill**' "${proj}/AGENTS.md"
  grep -qF "SKILL.md: .claude/skills/newskill/SKILL.md" "${proj}/AGENTS.md"
  ! grep -qF "$canon" "${proj}/AGENTS.md"
}

@test "update drops a stale entry from the block when the skill left skills/" {
  local origin
  origin="$(build_update_checkout)"
  push_fixture_skill "$origin" doomed
  git -C "$CHECKOUT" pull -q --ff-only
  run bash "${CHECKOUT}/install.sh"
  [ "$status" -eq 0 ]
  grep -qF -- '- **doomed**' "${HOME}/.claude/CLAUDE.md"

  local tmp_clone="${SANDBOX_TMP}/rm-clone"
  git clone -q "$origin" "$tmp_clone"
  git -C "$tmp_clone" rm -rq skills/doomed
  git -C "$tmp_clone" -c user.email=t@e.com -c user.name=bats commit -q -m rm
  git -C "$tmp_clone" push -q origin main

  run bash "${CHECKOUT}/bin/egloff-api" update
  [ "$status" -eq 0 ]
  ! grep -qF -- '- **doomed**' "${HOME}/.claude/CLAUDE.md"
  grep -qF -- '- **egloff-api**' "${HOME}/.claude/CLAUDE.md"
}

@test "update respects EGLOFF_NO_REGISTER" {
  local origin
  origin="$(build_update_checkout)"
  run bash "${CHECKOUT}/install.sh" --no-register
  [ "$status" -eq 0 ]
  push_fixture_skill "$origin" newskill
  EGLOFF_NO_REGISTER=1 run bash "${CHECKOUT}/bin/egloff-api" update
  [ "$status" -eq 0 ]
  [ ! -e "${HOME}/.claude/CLAUDE.md" ]
}

@test "update does not promote a --project-only install to a global registration" {
  local origin proj
  origin="$(build_update_checkout)"
  proj="${SANDBOX_TMP}/proj"
  mkdir -p "$proj"
  run bash "${CHECKOUT}/install.sh" --project "$proj"
  [ "$status" -eq 0 ]
  push_fixture_skill "$origin" newskill
  run bash "${CHECKOUT}/bin/egloff-api" update
  [ "$status" -eq 0 ]
  [ ! -e "${HOME}/.claude/CLAUDE.md" ]
  grep -qF -- '- **newskill**' "${proj}/CLAUDE.md"
}

# --- Antigravity: skills.json -------------------------------------------------
# Antigravity discovers skills only from <project>/.agents/skills/<name>/ or
# from `entries[].path` declared in a skills.json: ~/.gemini/config/skills.json
# globally, PROJECT/.agents/skills.json per project. The entry points at the
# installed clone's skills/ dir (absolute) and is merged, never overwritten.

# skills_dir — canonical absolute skills/ dir of the local checkout.
skills_dir() {
  printf '%s/skills' "$(cd -P "$CHECKOUT" && pwd)"
}

@test "antigravity: ~/.gemini present creates config/skills.json with the absolute skills dir" {
  mkdir -p "${HOME}/.gemini"
  local f="${HOME}/.gemini/config/skills.json" sd
  sd="$(skills_dir)"
  run_install
  [ "$status" -eq 0 ]
  [ -f "$f" ]
  [ "$(jq -r '.entries | length' "$f")" -eq 1 ]
  [ "$(jq -r '.entries[0].path' "$f")" = "$sd" ]
  [[ "$output" == *"Registered skills for agents in:"* ]]
  [[ "$output" == *"$f"* ]]
}

@test "antigravity: no ~/.gemini means nothing is created" {
  run_install
  [ "$status" -eq 0 ]
  [ ! -e "${HOME}/.gemini" ]
}

@test "antigravity: existing entries and other keys are merged, not clobbered" {
  mkdir -p "${HOME}/.gemini/config"
  local f="${HOME}/.gemini/config/skills.json" sd
  sd="$(skills_dir)"
  printf '%s\n' '{"inherits":"base","entries":[{"path":"/other/skills","label":"x"}]}' > "$f"
  run_install
  [ "$status" -eq 0 ]
  [ "$(jq -r '.inherits' "$f")" = "base" ]
  [ "$(jq -r '.entries | length' "$f")" -eq 2 ]
  [ "$(jq -r '.entries[0].path' "$f")" = "/other/skills" ]
  [ "$(jq -r '.entries[0].label' "$f")" = "x" ]
  [ "$(jq -r '.entries[1].path' "$f")" = "$sd" ]
}

@test "antigravity: an existing object without entries gets the key added" {
  mkdir -p "${HOME}/.gemini/config"
  local f="${HOME}/.gemini/config/skills.json"
  printf '%s\n' '{"inherits":"base"}' > "$f"
  run_install
  [ "$status" -eq 0 ]
  [ "$(jq -r '.inherits' "$f")" = "base" ]
  [ "$(jq -r '.entries | length' "$f")" -eq 1 ]
}

@test "antigravity: re-running is idempotent, no duplicate entry and no rewrite" {
  mkdir -p "${HOME}/.gemini"
  local f="${HOME}/.gemini/config/skills.json" before
  run_install
  [ "$status" -eq 0 ]
  before="$(cat "$f")"
  touch -t 202001010000 "$f"
  run_install
  [ "$status" -eq 0 ]
  [ "$(cat "$f")" = "$before" ]
  [ "$(jq -r '.entries | length' "$f")" -eq 1 ]
  # Unchanged content is not rewritten: the old mtime survives.
  [ "$(date -r "$f" +%Y)" = "2020" ]
}

@test "antigravity: invalid JSON is left untouched with a warning, install exits 0" {
  mkdir -p "${HOME}/.gemini/config"
  local f="${HOME}/.gemini/config/skills.json"
  printf '%s' '{ not json' > "$f"
  run_install
  [ "$status" -eq 0 ]
  [[ "$output" == *"warning"* ]]
  [ "$(cat "$f")" = '{ not json' ]
  [ -f "${HOME}/.claude/CLAUDE.md" ]
}

@test "antigravity: a non-object or non-array entries is left untouched with a warning" {
  mkdir -p "${HOME}/.gemini/config"
  local f="${HOME}/.gemini/config/skills.json"
  printf '%s' '[1,2]' > "$f"
  run_install
  [ "$status" -eq 0 ]
  [[ "$output" == *"warning"* ]]
  [ "$(cat "$f")" = '[1,2]' ]
  printf '%s' '{"entries":"nope"}' > "$f"
  run_install
  [ "$status" -eq 0 ]
  [ "$(cat "$f")" = '{"entries":"nope"}' ]
}

@test "antigravity: file mode is preserved and a symlinked skills.json is written through" {
  mkdir -p "${HOME}/.gemini/config" "${SANDBOX_TMP}/dots"
  local real="${SANDBOX_TMP}/dots/skills.json" f="${HOME}/.gemini/config/skills.json"
  printf '%s\n' '{"entries":[]}' > "$real"
  chmod 600 "$real"
  ln -s "$real" "$f"
  run_install
  [ "$status" -eq 0 ]
  [ -L "$f" ]
  [ "$(jq -r '.entries | length' "$real")" -eq 1 ]
  [ "$(stat -f %Lp "$real" 2>/dev/null || stat -c %a "$real")" = "600" ]
}

@test "antigravity: --no-register and EGLOFF_NO_REGISTER skip skills.json" {
  mkdir -p "${HOME}/.gemini"
  run_install --no-register
  [ "$status" -eq 0 ]
  [ ! -e "${HOME}/.gemini/config/skills.json" ]
  EGLOFF_NO_REGISTER=1 run bash "${CHECKOUT}/install.sh"
  [ "$status" -eq 0 ]
  [ ! -e "${HOME}/.gemini/config/skills.json" ]
}

@test "antigravity: --project writes PROJECT/.agents/skills.json, not the global file" {
  mkdir -p "${HOME}/.gemini"
  local proj="${SANDBOX_TMP}/proj" sd
  mkdir -p "$proj"
  sd="$(skills_dir)"
  run_install --project "$proj"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.entries[0].path' "${proj}/.agents/skills.json")" = "$sd" ]
  [[ "$output" == *"${proj}/.agents/skills.json"* || "$output" == *"/.agents/skills.json"* ]]
  [ ! -e "${HOME}/.gemini/config/skills.json" ]
}

@test "antigravity: --project --no-register writes no .agents/skills.json" {
  local proj="${SANDBOX_TMP}/proj"
  mkdir -p "$proj"
  run_install --project "$proj" --no-register
  [ "$status" -eq 0 ]
  [ ! -e "${proj}/.agents" ]
}

@test "antigravity: update repairs the global and project skills.json" {
  local origin proj sd
  origin="$(build_update_checkout)"
  mkdir -p "${HOME}/.gemini"
  proj="${SANDBOX_TMP}/proj"
  mkdir -p "$proj"
  sd="$(skills_dir)"
  run bash "${CHECKOUT}/install.sh" --project "$proj"
  [ "$status" -eq 0 ]
  run bash "${CHECKOUT}/install.sh"
  [ "$status" -eq 0 ]
  rm -f "${HOME}/.gemini/config/skills.json" "${proj}/.agents/skills.json"

  push_fixture_skill "$origin" newskill
  run bash "${CHECKOUT}/bin/egloff-api" update
  [ "$status" -eq 0 ]
  [ "$(jq -r '.entries[0].path' "${HOME}/.gemini/config/skills.json")" = "$sd" ]
  [ "$(jq -r '.entries[0].path' "${proj}/.agents/skills.json")" = "$sd" ]
}

@test "antigravity: update honors the global opt-out and project register:false" {
  local origin proj
  origin="$(build_update_checkout)"
  mkdir -p "${HOME}/.gemini"
  proj="${SANDBOX_TMP}/proj"
  mkdir -p "$proj"
  run bash "${CHECKOUT}/install.sh" --project "$proj" --no-register
  [ "$status" -eq 0 ]
  run bash "${CHECKOUT}/install.sh" --no-register
  [ "$status" -eq 0 ]
  push_fixture_skill "$origin" newskill
  run bash "${CHECKOUT}/bin/egloff-api" update
  [ "$status" -eq 0 ]
  [ ! -e "${HOME}/.gemini/config/skills.json" ]
  [ ! -e "${proj}/.agents/skills.json" ]
}

@test "usage documents the Antigravity skills.json registration" {
  run bash "${CHECKOUT}/install.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"skills.json"* ]]
}
