---
name: issue-format
description: "Trigger: create issue, open issue, crea un issue, abre un issue, gh issue create, report a bug, request a feature. Write GitHub issues in a simple, consistent format across repos."
license: Apache-2.0
metadata:
  author: "AlejandroBecJim"
  version: "1.0"
---

## Activation Contract

Use whenever you create a GitHub issue, in any repo. Prose in Spanish, short and easy to read. If the repo has its own issue templates, they must follow this structure; if they conflict, this skill wins unless the user says otherwise.

## Labels

Check what the repo defines first (`gh label list`). Use only labels that exist; if one is missing, skip it and say so instead of creating it.

- `status:approved` from the start. NEVER `status:needs-triage`.
- One priority label by kind: error -> `priority:high`, feature -> `priority:medium`, follow-up (chore, docs, refactor, seguimiento) -> `priority:low`.
- The type is plain text on the first line, not a checklist and not a label: `**Tipo:** fix | feature | chore | docs | refactor`.

## Body, in this order

1. `## Descripción` — the problem or need, and for whom.
2. `## Cómo reproducir` — numbered steps and the expected result. Only if applicable (bugs).
3. `## Posible solución` — what to do and the considerations.
4. `## Criterios de aceptación` — checklist (`- [ ]`) that closes the issue.

No priority dropdown, no extra sections.

## Command

`gh issue create --title T --body-file F --label status:approved --label priority:X`

## Output Contract

Report the issue URL and its labels.
