---
name: adr-format
description: "Trigger: create ADR, write ADR, crea un ADR, registrar decisión de arquitectura, architecture decision record, docs/adr. Write ADRs in a simple, consistent format across repos."
license: Apache-2.0
metadata:
  author: "AlejandroBecJim"
  version: "1.0"
---

## Activation Contract

Use whenever you record an architecture decision in any repo. Prose in neutral Spanish; code identifiers in English. The template lives here: never copy it into the target repo. An ADR records a decision already taken (the "what we chose and why"); the proposal that led to it, if any, is an RFC (see `rfc-format`).

## Location and numbering

- `docs/adr/NNNN-titulo-corto.md`, `NNNN` = next free 4-digit number, `titulo-corto` in kebab-case.
- If `docs/adr/README.md` is missing, create it with the index table `| ADR | Título | Estado |`; add one row per ADR and keep it updated.
- ADRs are immutable once `aceptada`: only the state line may change.

## States

`propuesta` -> `aceptada` -> `reemplazada por ADR-NNNN`.

## Supersede flow

1. Create the new ADR (state `propuesta` or `aceptada`) and explain in `Contexto` which ADR it replaces and why.
2. In the old ADR change only the state to `reemplazada por ADR-NNNN`.
3. Update both rows in `docs/adr/README.md`.

## Template

```markdown
# ADR NNNN: <decisión>

- **Estado:** propuesta | aceptada | reemplazada por ADR-NNNN
- **Fecha:** AAAA-MM-DD
- **RFC relacionada:** NNNN (si aplica)

## Contexto
## Decisión
## Alternativas consideradas
## Consecuencias
Positivas, negativas y deuda que deja.
```

## Command

No CLI. Write the file and add the row to `docs/adr/README.md`.

## Output Contract

Report the ADR path, its number and state, and the ADR it supersedes if any.
