# app-egloff API reference

Source of truth: `GET /api/docs` on any running instance, and
`app/Http/Controllers/Api/DocsController.php` in this repo. This file is a
convenience mirror — if the two disagree, trust `/api/docs`.

All routes below require `Authorization: Bearer <token>` (Laravel Sanctum)
and are automatically scoped to the token owner's tenant. Cross-tenant
records return `404`, never `403` (existence itself is not leaked).

## Tasks — `/api/tasks`

| Method | Path | Notes |
|---|---|---|
| GET | `/api/tasks` | Paginated list, current tenant only |
| POST | `/api/tasks` | Create. `tenant_id` set automatically |
| GET | `/api/tasks/{task}` | 404 if not in your tenant |
| PUT/PATCH | `/api/tasks/{task}` | 404 if not in your tenant |
| DELETE | `/api/tasks/{task}` | 404 if not in your tenant |

Body fields (POST):

| Field | Rule |
|---|---|
| `project_id` | integer, nullable |
| `title` | string, required, max:255 |
| `description` | string, nullable |
| `context` | string, nullable |
| `status` | enum: `pendiente\|en_proceso\|en_pausa\|en_revision\|completada\|cancelada` |
| `priority` | enum: `baja\|media\|alta\|urgente` |
| `due_date` | date, nullable |
| `sort_order` | integer, nullable |
| `on_radar_today` | boolean, nullable |

## Context Entries — `/api/context-entries`

| Method | Path | Notes |
|---|---|---|
| GET | `/api/context-entries` | Paginated. `?search=` matches `title` OR `content`. `?type=`, `?task_id=`, `?topic_key=` filter exactly |
| POST | `/api/context-entries` | See upsert semantics below |
| GET | `/api/context-entries/{context_entry}` | 404 if not in your tenant |
| PUT/PATCH | `/api/context-entries/{context_entry}` | 404 if not in your tenant |
| DELETE | `/api/context-entries/{context_entry}` | 404 if not in your tenant |

Body fields (POST):

| Field | Rule |
|---|---|
| `task_id` | integer, nullable, must belong to your tenant |
| `type` | required, one of: `decision`, `architecture`, `bugfix`, `pattern`, `config`, `discovery`, `preference`, `session_summary`, `manual` |
| `title` | string, required, max:255 |
| `content` | string, required |
| `topic_key` | string, nullable |

**Upsert semantics**: with `topic_key`, the server does
`updateOrCreate(['topic_key' => ...], ...)` scoped to your tenant — same
`topic_key` again updates the existing row (`200`) instead of duplicating it.
Without `topic_key`, every call always creates a new row (`201`); this is
intentional, not a bug — do not rely on a missing `topic_key` to deduplicate.

`created_by` and `tenant_id` are always set server-side from the
authenticated token; sending them in the body has no effect.

## Errors

| Status | Meaning |
|---|---|
| 401 | Missing/invalid/revoked token |
| 404 | Record doesn't exist, or exists in a different tenant |
| 422 | Validation failed — body has `message` + `errors` per field |
