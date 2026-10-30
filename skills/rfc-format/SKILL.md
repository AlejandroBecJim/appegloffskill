---
name: rfc-format
description: "Trigger: create RFC, write RFC, crea un RFC, escribe una RFC, propuesta de cambio, docs/rfc. Write RFCs (full or short template) in a simple, consistent format across repos."
license: Apache-2.0
metadata:
  author: "AlejandroBecJim"
  version: "1.0"
---

## Activation Contract

Use whenever you create or update an RFC in any repo. Prose in neutral Spanish; code identifiers (classes, tables, commands) in English. The format lives here: never copy the templates into the target repo, only the RFCs themselves. If the repo's `docs/constitution.md` defines when an RFC is required, it wins over the defaults below.

## When an RFC is required

Default (configurable per repo in its constitution):

- New features, improvements, modules or tools.
- Migrations and schema changes.
- Architecture changes.
- Visual changes (short template).
- Bugs only if they need architecture or database changes.

## Location and numbering

- `docs/rfc/NNNN-titulo-corto.md`, `NNNN` = next free 4-digit number, `titulo-corto` in kebab-case.
- If `docs/rfc/README.md` is missing, create it with the index table `| RFC | Título | Estado |`; add one row per RFC and keep it updated.

## States

`borrador` -> `en revisión` -> `aceptada` | `rechazada` | `reemplazada` (full template only; point to the replacing RFC). Only the approver moves an RFC to `aceptada`.

## Full template

```markdown
# RFC NNNN: <título>

- **Estado:** borrador | en revisión | aceptada | rechazada | reemplazada
- **Autor:** <nombre>
- **Aprobador:** <dueño del proyecto o quien designe>
- **Fecha:** AAAA-MM-DD
- **Issue relacionado:** #N

## Resumen
Una o dos frases: qué se propone.

## Motivación
Problema o necesidad, y para quién.

## Alcance
- Incluye:
- No incluye:

## Propuesta
Qué se hará y cómo, con el nivel de detalle suficiente para implementarla.

## Alternativas consideradas
Qué más se evaluó y por qué se descartó.

## Impacto
- Datos y migraciones:
- Áreas críticas (ventas, órdenes de trabajo, pagos, inventario):
- Seguridad y privacidad:
- Rendimiento y hosting:

## Plan de pruebas
Tests nuevos o actualizados. En áreas críticas son obligatorios.

## Plan de reversa
Cómo deshacer el cambio si sale mal.

## Preguntas abiertas
```

## Short template (visual changes only)

```markdown
# RFC NNNN: <título>

- **Estado:** borrador | en revisión | aceptada | rechazada
- **Aprobador:** <dueño o designado>
- **Fecha:** AAAA-MM-DD

## Resumen
## Motivación
## Cambio visual
Descripción y, si aplica, captura o boceto.
## Impacto
¿Toca arquitectura, datos o áreas críticas? Si sí, usar la plantilla completa.
## Plan de pruebas
```

Adapt the "Áreas críticas" examples to the repo's constitution. Use the short template only when the impact section is "no" on architecture, data and critical areas; otherwise use the full one.

## Command

No CLI. Write the file, add the row to `docs/rfc/README.md`, and link the RFC from the related issue.

## Output Contract

Report the RFC path, its number, state and which template was used.
