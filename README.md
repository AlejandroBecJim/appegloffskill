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

Obtén un token desde la página Panel → API Token de tu instancia de
app-egloff, y luego expórtalo en tu shell (nunca lo confirmes en un commit,
nunca lo pegues en el chat):

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

Ejecuta `egloff-api` sin argumentos para un asistente de configuración
interactivo que guarda tu URL/token en `~/.config/egloff-api/config`, o `egloff-api
doctor` para diagnosticar una configuración rota.

Consulta `skills/egloff-api/SKILL.md` y `skills/egloff-api/references/endpoints.md`
para el contrato completo.

## Requisitos

- `curl`, `jq`
- Una instancia de app-egloff en ejecución y un token de API de Sanctum válido

## Licencia

Apache-2.0 — ver `LICENSE`.
