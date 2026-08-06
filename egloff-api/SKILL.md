---
name: egloff-api
description: "Trigger: push/save/upload tasks or pendientes to app-egloff, sync context entries, subir pendientes, guardar en engram remoto, call the app-egloff API. Talk to a live app-egloff instance's /api/tasks and /api/context-entries over Sanctum."
license: Apache-2.0
metadata:
  author: "AlejandroBecJim"
  version: "1.0"
---

## Activation Contract

Load when asked to push, sync, or read tasks/pendientes/context entries against a **live, deployed** app-egloff instance via its HTTP API — not for local DB/model work (use `laravel-testing` and read the Eloquent models directly for that).

## Hard Rules

- Never hardcode a token or base URL in a command, file, or commit. Require `EGLOFF_API_URL` and `EGLOFF_API_TOKEN` as environment variables the user has already exported in their shell; if unset, tell the user how to get a token (Panel → API Token page) and stop — do not ask them to paste it into chat.
- This talks to a **real, possibly production** app-egloff deployment. Treat every `POST`/`PUT`/`DELETE` call as a live-data mutation: state which endpoint and payload you're about to send before running it, same as any other risky action.
- `context:create` without `--topic_key` always creates a new row (no dedup). To update-or-create, pass the same `--topic_key` every time — see `references/endpoints.md` for exact semantics.
- All endpoints are tenant-scoped automatically by the token; a wrong/expired token fails with 401, a cross-tenant id fails with 404 — never assume 403 means "exists but forbidden."
- `created_by`/`tenant_id` are server-assigned; don't try to pass them.

## Decision Gates

| Need | Use |
|---|---|
| Create/update/delete a task remotely | `tasks:create`, `tasks:update`, `tasks:delete` |
| List/search tasks | `tasks:list` |
| Save a memory/decision/context note remotely (Engram-style) | `context:create --topic_key=...` (upsert) or without it (always-new) |
| List/search context entries | `context:list --search=...` |
| Exact field rules, status/type enums, error shapes | `references/endpoints.md` |

## Execution Steps

1. Confirm `EGLOFF_API_URL` and `EGLOFF_API_TOKEN` are set: `test -n "$EGLOFF_API_TOKEN"`. If not, stop and ask the user to export them (or get a token first).
2. Run `assets/egloff-api.sh <subcommand> [--key=value ...]` — see the script's header comment for the full subcommand list.
3. Read the JSON response; a non-2xx status prints `error: HTTP <code>` on stderr and the response body on stdout — surface the `message`/`errors` fields to the user, don't just say "it failed."
4. For anything not covered by a subcommand (custom filters, pagination beyond page 1), fall back to plain `curl` following the same auth header pattern, per `references/endpoints.md`.

## Output Contract

Every call reports: which endpoint was hit, the HTTP status, and the relevant response fields (id, created/updated timestamps) — not just "done."

## References

- `assets/egloff-api.sh` — the actual curl/jq wrapper; read its header comment for full usage.
- `references/endpoints.md` — field-by-field API contract (mirrors `GET /api/docs`).
