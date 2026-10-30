# Audit and restructure

Use when asked to audit a repo or to restructure it towards the architecture of `SKILL.md`. Read-only until the user approves the plan.

## Audit mode

Scan the repo (any stack) and collect:

1. Files over 250 lines.
2. Methods or functions over 30 lines.
3. Business logic in the edge (controllers, routers, components, pages) or in models (queries across entities, calls to third parties, orchestration).
4. Layers that only forward calls (service that wraps a repository, handler that calls one method and returns).
5. Missing use case: edge code that holds rules with no class of its own.
6. Ports without a real external integration (one interface per repository or class).
7. File count per feature (folder or module) and the average lines per file.

Useful starting commands: `find . -name '*.<ext>' | xargs wc -l | sort -rn | head -30`, plus a search for `new <Http client>`, raw queries and `fetch`/`HttpClient` inside edge folders.

## Audit report template

```
# Audit de arquitectura: <repo>

## Resumen
- Stack: <stack>
- Archivos analizados: N
- Violaciones: N (alta X, media Y, baja Z)

## Violaciones
| # | Regla | Ubicación | Detalle | Severidad |
| --- | --- | --- | --- | --- |
| 1 | File >250 lines | path | 612 líneas | alta |

## Archivos por feature
| Feature | Archivos | Líneas medias | Observación |
| --- | --- | --- | --- |

## Plan de migración
1. <paso> — alcance, archivos, riesgo
```

Severity: high = god files, logic in the edge on critical flows; medium = forwarding layers, missing use cases; low = naming, ports without integration.

## Migration plan (ordered, one PR per step)

1. Safety net: tests (characterization tests) on the flows about to move. No structural change.
2. Fix the rules for new code: layout and naming from `references/<stack>.md`. Document in the repo.
3. Extract use cases from the largest god controllers/components, one flow per PR.
4. Move logic out of models into the use cases that own it.
5. Delete forwarding layers once the callers use the use case directly.
6. Collapse ports that have no real external integration into plain calls.
7. Split remaining files over 250 lines, one file per PR.

Rules:

- Strangler style: old code is moved only when touched by an issue or in one of the dedicated steps above. Never a repo-wide move.
- Each PR changes structure OR behavior, never both.
- Each PR stays within the file budget of a "Refactor step" and keeps the suite green.
- Stop after any step if the user decides the remaining violations are acceptable; record them as pending in the report.
