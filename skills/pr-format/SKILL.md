---
name: pr-format
description: "Trigger: create PR, open pull request, crea un PR, abre el PR, haz el PR, gh pr create, PR body. Write GitHub pull requests in a simple, consistent format across repos."
license: Apache-2.0
metadata:
  author: "AlejandroBecJim"
  version: "1.0"
---

## Activation Contract

Use whenever you create a pull request, in any repo. Prose in Spanish, short and easy to read. It does not cover branches or commits. If the repo has its own PR template, it must follow this structure; if they conflict, this skill wins unless the user says otherwise.

## Rules

- The body links the issue with `Closes #N`.
- Exactly one `type:*` label if the repo uses them (CI may require it). It is a label only: the body has NO type section. Check `gh label list` first and skip labels the repo lacks.
- NO file-by-file table of changes: context over inventory.

## Body, in this order

1. `## Issue relacionado` — `Closes #N`.
2. `## Resumen` — 1-3 bullets: what the PR does and why.
3. `## Decisiones tomadas` — what was done and why; whether anything the issue asked for was changed and why; any extra problem added beyond the issue and why.
4. `## Riesgos conocidos` — what could fail or stayed out of scope; "Ninguno" if none.
5. `## Cómo se validó` — checklist with the real checks run (linters, test suite with real counts, manual test of the affected flow; leave unchecked what was not done).
6. `## Criterios del issue resueltos` — the issue's acceptance criteria as a checklist, marking the ones this PR resolves.

## Command

`gh pr create --base main --head BRANCH --title T --body-file F --label type:X` (pass `--head` explicitly when running from a worktree or another branch).

## Output Contract

Report the PR URL, its labels, and anything left unchecked (for example the manual test).
