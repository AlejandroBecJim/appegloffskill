# Referencia de la API de app-egloff

Fuente de verdad: `GET /api/docs` en cualquier instancia en ejecución, y
`app/Http/Controllers/Api/DocsController.php` en este repo. Este archivo es
un espejo de conveniencia — si ambos difieren, confía en `/api/docs`.

Todas las rutas de abajo requieren `Authorization: Bearer <token>` (Laravel
Sanctum) y quedan automáticamente scoped al tenant del dueño del token. Los
registros de otro tenant devuelven `404`, nunca `403` (la existencia en sí
no se filtra).

## Tareas — `/api/tasks`

| Method | Path | Notas |
|---|---|---|
| GET | `/api/tasks` | Lista paginada, solo el tenant actual |
| POST | `/api/tasks` | Crear. `tenant_id` se asigna automáticamente |
| GET | `/api/tasks/{task}` | 404 si no está en tu tenant |
| PUT/PATCH | `/api/tasks/{task}` | 404 si no está en tu tenant |
| DELETE | `/api/tasks/{task}` | 404 si no está en tu tenant |

Campos del body (POST):

| Campo | Regla |
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

## Entradas de contexto — `/api/context-entries`

| Method | Path | Notas |
|---|---|---|
| GET | `/api/context-entries` | Paginado. `?search=` coincide con `title` O `content`. `?type=`, `?task_id=`, `?topic_key=` filtran exactamente |
| POST | `/api/context-entries` | Ver la semántica de upsert más abajo |
| GET | `/api/context-entries/{context_entry}` | 404 si no está en tu tenant |
| PUT/PATCH | `/api/context-entries/{context_entry}` | 404 si no está en tu tenant |
| DELETE | `/api/context-entries/{context_entry}` | 404 si no está en tu tenant |

Campos del body (POST):

| Campo | Regla |
|---|---|
| `task_id` | integer, nullable, debe pertenecer a tu tenant |
| `type` | required, one of: `decision`, `architecture`, `bugfix`, `pattern`, `config`, `discovery`, `preference`, `session_summary`, `manual` |
| `title` | string, required, max:255 |
| `content` | string, required |
| `topic_key` | string, nullable |

**Semántica de upsert**: con `topic_key`, el servidor hace
`updateOrCreate(['topic_key' => ...], ...)` scoped a tu tenant — el mismo
`topic_key` de nuevo actualiza la fila existente (`200`) en lugar de
duplicarla. Sin `topic_key`, cada llamada siempre crea una fila nueva
(`201`); esto es intencional, no un bug — no confíes en la ausencia de
`topic_key` para deduplicar.

`created_by` y `tenant_id` siempre se asignan del lado del servidor desde el
token autenticado; enviarlos en el body no tiene efecto.

## Proyectos — `/api/projects`

| Method | Path | Notas |
|---|---|---|
| GET | `/api/projects` | Lista paginada, solo el tenant actual. `?search=` coincide parcialmente (case-insensitive) con `name`. Solo lectura: no hay POST/PUT/DELETE |

Campos de cada proyecto en la respuesta: `id` (integer), `name` (string),
`client_id` (integer), `description` (string, nullable), `status` (string),
`started_at` (date, nullable), `delivered_at` (date, nullable),
`created_at`/`updated_at` (timestamps ISO 8601).

## Errores

| Status | Significado |
|---|---|
| 401 | Token faltante/inválido/revocado |
| 404 | El registro no existe, o existe en un tenant distinto |
| 422 | Falló la validación — el body tiene `message` + `errors` por campo |
