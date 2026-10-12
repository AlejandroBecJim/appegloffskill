---
name: constitution
description: "Trigger: create constitution, constitución del proyecto, docs/constitution.md, define project principles, amend constitution, enmendar la constitución. Guide the creation of a project constitution by asking one question at a time."
license: Apache-2.0
metadata:
  author: "AlejandroBecJim"
  version: "1.0"
---

## Activation Contract

Use when a repo has no `docs/constitution.md` and the user wants one, or when amending it. Prose in neutral Spanish; code identifiers in English. The schema lives here; the repo keeps only its own constitution.

## Interview rules

- Ask ONE question at a time, then STOP and wait for the answer. Never batch questions or assume answers.
- Walk the sections in order; propose a short default when the repo makes one obvious (read `README`, `composer.json`/`package.json`, CI config first) and let the user confirm or correct.
- Write the file only after all 10 sections are answered; show it for approval before saving.

## Schema of `docs/constitution.md`

1. Propósito y alcance.
2. Principios.
3. Restricciones actuales (hosting, versión del framework). Separate from principles because they can change.
4. Áreas críticas e invariantes, ordered by criticality.
5. Datos personales y privacidad.
6. Calidad: mandatory tests, CI and branch protection.
7. Proceso de cambio: when an RFC is required, when an ADR, who approves (see `rfc-format` and `adr-format`).
8. Agentes de IA: what they may do alone and what needs approval.
9. Idioma de la documentación.
10. Cómo se enmienda la constitución.

## Resulting docs structure

```text
docs/
├── constitution.md
├── rfc/
│   ├── README.md
│   └── NNNN-titulo-corto.md
└── adr/
    ├── README.md
    └── NNNN-titulo-corto.md
```

Create `rfc/` and `adr/` only when the first document is written.

## Command

No CLI. Write `docs/constitution.md`; amendments follow section 10 of the constitution itself (normally an RFC).

## Output Contract

Report the file path and the list of the 10 sections with any left as "pendiente".
