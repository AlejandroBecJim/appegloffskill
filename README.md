# appegloffskill

Una [Skill](https://docs.claude.com/en/docs/claude-code/skills) de Claude Code
para hablar con una instancia en vivo de [app-egloff](https://github.com/AlejandroBecJim/app-egloff)
a través de su API de Sanctum — `/api/tasks` y `/api/context-entries` (ADR-0009).

Sin servidor MCP, sin daemon: un contrato de instrucciones `SKILL.md` más un
pequeño wrapper de `curl`/`jq`. Un solo consumidor (Claude Code), cero
infraestructura extra que ejecutar o mantener.

## Instalación

```bash
curl -fsSL https://raw.githubusercontent.com/AlejandroBecJim/appegloffskill/main/install.sh | bash
```

Esto clona la skill en `~/.local/share/egloff-api-skill` y la enlaza
mediante symlink en `~/.claude/skills/egloff-api`. Variantes:

```bash
curl -fsSL https://raw.githubusercontent.com/AlejandroBecJim/appegloffskill/main/install.sh | bash -s -- --project /path/to/repo  # project-local: /path/to/repo/.claude/skills/egloff-api
curl -fsSL https://raw.githubusercontent.com/AlejandroBecJim/appegloffskill/main/install.sh | bash -s -- --copy                    # copy files instead of symlinking (default: symlink)
```

El enlace simbólico (opción por defecto) permite actualizar en el mismo
lugar: vuelve a ejecutar el instalador para obtener las nuevas versiones.
Ejecuta `curl -fsSL .../install.sh | bash -s -- --help` para ver la lista
completa de flags (o `./install.sh --help` desde una copia local).

> **Actualizar desde una instalación creada antes de este cambio**: vuelve a
> ejecutar el instalador una vez. Las instalaciones antiguas apuntan
> (symlink) a una ruta que ya no existe tras este cambio, por lo que Claude
> Code dejará de encontrar la skill silenciosamente hasta que vuelvas a
> ejecutar `install.sh`.

## Configuración

**Recomendado — una sola vez, queda funcionando siempre:** corre el
asistente interactivo. Te va a pedir la URL de tu instancia de app-egloff
y un token (página Panel → API Token), probar la conectividad, y guardar
todo en `~/.config/egloff-api/config` (permisos `600`). No necesitás
volver a hacer nada en sesiones de shell nuevas ni al reiniciar el equipo:

```bash
egloff-api
```

`egloff-api doctor` diagnostica una configuración rota (dependencias,
credenciales, conectividad) sin modificar nada. `egloff-api config
show|set-url|set-token` gestiona la config guardada directamente, sin
pasar por el asistente completo.

**Alternativa — override de una sola sesión:** exportar las variables de
entorno tiene prioridad sobre la config guardada y solo dura mientras esa
terminal esté abierta (útil para probar otra instancia sin tocar tu config
persistida). Nunca confirmes el token en un commit ni lo pegues en el chat:

```bash
export EGLOFF_API_URL="https://your-instance.example.com"
export EGLOFF_API_TOKEN="the-sanctum-token"
```

## Uso

Una vez instalada y configurada, pídele a Claude Code que envíe o lea tareas /
entradas de contexto contra tu instancia — cargará `skills/egloff-api/SKILL.md`
y manejará la CLI `egloff-api` por ti. Para llamarla directamente:

```bash
egloff-api tasks:create --title="Buy milk" --on_radar_today=true
egloff-api context:create --type=decision --title="..." --content="..." --topic_key="sdd/foo"
egloff-api context:list --search=deploy
```

Consulta `skills/egloff-api/SKILL.md` y `skills/egloff-api/references/endpoints.md`
para el contrato completo.

## Requisitos

- `curl`, `jq`
- Una instancia de app-egloff en ejecución y un token de API de Sanctum válido

## Licencia

Apache-2.0 — ver `LICENSE`.
