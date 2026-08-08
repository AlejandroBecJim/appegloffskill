---
name: egloff-api
description: "Trigger: push/save/upload tasks or pendientes to app-egloff, sync context entries, subir pendientes, guardar en engram remoto, call the app-egloff API. Talk to a live app-egloff instance's /api/tasks and /api/context-entries over Sanctum."
license: Apache-2.0
metadata:
  author: "AlejandroBecJim"
  version: "1.0"
---

## Contrato de activación

Cargar cuando se pida enviar, sincronizar o leer tareas/pendientes/entradas de contexto contra una instancia **en vivo y desplegada** de app-egloff a través de su API HTTP — no para trabajo local de BD/modelos (usa `laravel-testing` y lee los modelos Eloquent directamente para eso).

## Reglas estrictas

- Nunca hardcodear un token en un comando, archivo o commit. La base URL ya viene preconfigurada por default (`https://app.egloff.com.mx`); lo único que hay que resolver es el token, desde la variable de entorno `EGLOFF_API_TOKEN`, con fallback a un `~/.config/egloff-api/config` persistido (escrito por el asistente de configuración interactivo de `egloff-api`). Si no hay token disponible, dile al usuario que ejecute `egloff-api` (sin argumentos) para configurarlo, o cómo obtener uno (página Panel → API Token) — no le pidas que lo pegue en el chat. `EGLOFF_API_URL` solo hace falta si necesitás apuntar a otra instancia.
- Esto habla con un despliegue **real, posiblemente de producción** de app-egloff. Trata cada llamada `POST`/`PUT`/`DELETE` como una mutación de datos en vivo: indica qué endpoint y payload estás por enviar antes de ejecutarla, igual que con cualquier otra acción riesgosa.
- `context:create` sin `--topic_key` siempre crea una fila nueva (sin dedup). Para update-or-create, pasa el mismo `--topic_key` cada vez — ver `references/endpoints.md` para la semántica exacta.
- Todos los endpoints están scoped por tenant automáticamente según el token; un token incorrecto/expirado falla con 401, un id de otro tenant falla con 404 — nunca asumas que 403 significa "existe pero está prohibido."
- `created_by`/`tenant_id` son asignados por el servidor; no intentes pasarlos.

## Puertas de decisión

| Cuándo | Usar |
|---|---|
| Crear/actualizar/eliminar una tarea remotamente | `tasks:create`, `tasks:update`, `tasks:delete` |
| Listar/buscar tareas | `tasks:list` |
| Guardar una memoria/decisión/nota de contexto remotamente (estilo Engram) | `context:create --topic_key=...` (upsert) o sin él (siempre crea una nueva) |
| Listar/buscar entradas de contexto | `context:list --search=...` |
| Reglas exactas de campos, enums de status/type, formas de error | `references/endpoints.md` |

## Pasos de ejecución

1. Confirma que el token esté disponible: ejecuta `egloff-api doctor`, o revisa `test -n "$EGLOFF_API_TOKEN"` / un `~/.config/egloff-api/config` persistido. Si no hay token, detente y dile al usuario que ejecute `egloff-api` (sin argumentos) para configurarlo, o que exporte `EGLOFF_API_TOKEN`.
2. Ejecuta `egloff-api <subcommand> [--key=value ...]` — ver el comentario de cabecera de `bin/egloff-api` para la lista completa de subcomandos.
3. Lee la respuesta JSON; un status no-2xx imprime el cuerpo del error del servidor textualmente en stderr, más una pista de una línea `run \`egloff-api doctor\`` — muestra los campos `message`/`errors` al usuario, no digas solo que "falló."
4. Para cualquier cosa no cubierta por un subcomando (filtros personalizados, paginación más allá de la página 1), recurre a `curl` plano siguiendo el mismo patrón de cabecera de autenticación, según `references/endpoints.md`.

## Contrato de salida

Cada llamada reporta: qué endpoint se llamó, el status HTTP, y los campos relevantes de la respuesta (id, timestamps de creación/actualización) — no solo "listo."

## Referencias

- `bin/egloff-api` — la CLI (wrapper de curl/jq + asistente de configuración); lee su comentario de cabecera para el uso completo.
- `references/endpoints.md` — contrato de API campo por campo (refleja `GET /api/docs`).
