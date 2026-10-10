---
name: issue-pr-format
description: "Trigger: create issue, open issue, gh issue create, create PR, open pull request, gh pr create, PR body. Write GitHub issues and pull requests in a simple, consistent format across repos."
license: Apache-2.0
metadata:
  author: "AlejandroBecJim"
  version: "1.0"
---

## Activation Contract

Use whenever you create a GitHub issue or a pull request, in any repo. It defines the body structure, labels and language. It does not cover branches or commits.

Prose of issues and PRs is written in Spanish, short and easy to read. If the repo has its own templates under `.github/`, they must follow this structure; if they conflict, this skill wins unless the user says otherwise.

## Labels

Check what the repo defines first (`gh label list`). Use only labels that exist; if one is missing, skip it and say so instead of creating it.

- `status:approved` on every issue from the start. NEVER `status:needs-triage`.
- One priority label by kind of issue: error -> `priority:high`, feature -> `priority:medium`, follow-up (chore, docs, refactor, seguimiento) -> `priority:low`.
- The issue type is plain text on the first line, not a checklist: `**Tipo:** fix | feature | chore | docs | refactor`.
- A PR carries exactly one `type:*` label if the repo uses them (CI may require it). It is a label only: the PR body has no type section.

## Issues

Body, in this order:

1. `## Descripción` — the problem or need, and for whom.
2. `## Cómo reproducir` — numbered steps and the expected result. Only if applicable (bugs).
3. `## Posible solución` — what to do and the considerations.
4. `## Criterios de aceptación` — checklist (`- [ ]`) that closes the issue.

No checkboxes for the type, no priority dropdown. With the CLI: `gh issue create --body-file F --label status:approved --label priority:X`.

## Pull requests

The body links the issue with `Closes #N`. No file-by-file table: context over inventory.

Body, in this order:

1. `## Issue relacionado` — `Closes #N`.
2. `## Resumen` — 1-3 bullets: what the PR does and why.
3. `## Decisiones tomadas` — what was done and why; whether anything the issue asked for was changed and why; any extra problem added beyond the issue and why.
4. `## Riesgos conocidos` — what could fail or stayed out of scope; "Ninguno" if none.
5. `## Cómo se validó` — checklist with the real checks run (linters, test suite with real counts, manual test of the affected flow; leave unchecked what was not done).
6. `## Criterios del issue resueltos` — the issue's acceptance criteria as a checklist, marking the ones this PR resolves.

Use `gh pr create --body-file F --head BRANCH`, explicit when running from a worktree or another branch.

## Decision Gates

| Need | Action |
|------|--------|
| New issue | Pick the kind -> priority label + `status:approved` + 4-section body |
| New PR | `Closes #N`, one `type:*` label if used, the 6-section body |
| Label not defined in the repo | Skip it and mention it |
| Already open issues/PRs in the old format | Leave them as they are |

## Output Contract

Report the issue/PR URL, its labels, and anything left unchecked (for example the manual test).
