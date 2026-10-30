---
name: architecture-patterns
description: "Trigger: vamos con el issue, implementa el issue, resuelve el issue, ahora el issue <num>, resolver issue, resolve issue, implement issue, implementar feature, new endpoint, nuevo endpoint, nueva pantalla, nuevo CRUD, dónde pongo este código, cuántos archivos crear, estructura de carpetas, audit architecture, auditar repo, reestructurar, archivo demasiado grande. Impose ONE architecture (MVC at the edge + one use case per class) across Laravel, PHP, Angular, C#, Python and React, with file budgets and size limits."
license: Apache-2.0
metadata:
  author: "AlejandroBecJim"
  version: "1.0"
---

## Activation Contract

Load whenever a task creates or moves files, resolves an issue, or asks to audit or restructure a repo. Prose in Spanish, identifiers in English. The architecture is fixed: do not adapt it to each repo and do not propose alternatives, except through the escalation criteria below. Load only `references/<stack>.md` for the stack in use (`laravel-php`, `angular`, `react`, `csharp`, `python`). For "audit" or "restructure" also load `references/restructure.md`.

Goal: avoid both "a million files" and "god files".

## Layers

1. Edge (MVC/presentation): controller, router, view, component, page. It parses input, calls ONE use case and shapes the response. No business logic.
2. Core: one use case per class, with a single public entry method (`handle()` / `execute()`). It holds the business rules and orchestrates models and ports.
3. Model/entities: data, relations and trivial accessors only. No orchestration, no I/O to third parties.
4. Ports (interfaces): ONLY for real external integrations (payments, mail, third-party APIs, queues). Never one port per repository or class. The adapter lives next to the port.

Dependencies point inward: edge -> use case -> model/port. A use case never imports edge code.

## File budget

Maximum files created or modified per issue type (tests and migrations counted apart):

| Issue type | Max files | Plus |
| --- | --- | --- |
| New endpoint / screen | 4 | migration + test |
| Bugfix | 2 | regression test |
| New CRUD | ~6 | migration + tests |
| Refactor step | one PR, one concern | tests unchanged |
| Config / copy change | 1 | none |

If an issue needs more than its budget, justify the exception in the PR (`Decisiones tomadas`) or split the issue.

## Size limits

- ~250 lines per file and ~30 lines per method are triggers to extract, not targets to reach.
- Rule of 3: create an abstraction (base class, helper, interface) only when the same shape appears 3 times.
- No one-line wrapper classes. No layer that only forwards calls to the next one.
- A use case that only calls one model method does not need its own class: keep it in the edge until it holds a rule.

## Escalation to hexagonal

Move to full hexagonal only if at least one holds, and record it as an ADR (see `adr-format`):

- Complex, long-lived domain with rules that outlive frameworks.
- 3 or more interchangeable external integrations behind the same contract.
- Large team that needs strict, enforced module boundaries.

Without one of these, hexagonal is over-engineering for this skill.

## Workflow

1. Identify the issue type from the budget table.
2. Plan the exact files BEFORE writing any: path, layer, purpose. Check the count against the budget.
3. Implement following `references/<stack>.md` (layout, naming, Do not list).
4. Self-check: count files, scan files over ~250 lines and methods over ~30, confirm no logic in the edge or in models, no forwarding-only layers, no port without a real integration.

## Audit and restructure

Never big-bang. New code follows the rules; old code moves only when touched or in dedicated small steps, one PR per step (strangler style). Procedure and report template in `references/restructure.md`.

## Output Contract

Report: files created or modified versus the budget for the issue type (for example "4/4 + migration + test"), any justified exception, and any pending violation found but left out of scope. For an audit, use the report template of `references/restructure.md`.
