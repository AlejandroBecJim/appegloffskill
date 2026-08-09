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
lugar. Ejecuta `curl -fsSL .../install.sh | bash -s -- --help` para ver la
lista completa de flags (o `./install.sh --help` desde una copia local).

> **Actualizar desde una instalación creada antes de este cambio**: vuelve a
> ejecutar el instalador una vez. Las instalaciones antiguas apuntan
> (symlink) a una ruta que ya no existe tras este cambio, por lo que Claude
> Code dejará de encontrar la skill silenciosamente hasta que vuelvas a
> ejecutar `install.sh`.

## Actualización

Una vez instalado, la forma recomendada de actualizar es el propio CLI:

```bash
egloff-api update
```

Detecta automáticamente si la instalación es global (curl-instalada) o un
checkout local (clon de desarrollo), y actualiza cada una de forma segura:
en checkouts locales nunca descarta cambios sin confirmar (aborta si hay
cambios sin commitear, `HEAD` desacoplado, sin upstream configurado, o si
la rama divergió). El one-liner de `curl | bash` sigue documentado como
alternativa/fallback y como forma de instalación inicial:

```bash
curl -fsSL https://raw.githubusercontent.com/AlejandroBecJim/appegloffskill/main/install.sh | bash
```

> **Limitación conocida**: `egloff-api update` en modo local solo repara
> automáticamente los symlinks globales por defecto (`~/.local/bin/egloff-api`
> y `~/.claude/skills/egloff-api`). Una instalación hecha solo con
> `--project PATH` cuyo symlink de proyecto quede roto no se auto-repara
> todavía — reinstala manualmente con `install.sh --project PATH` (seguimiento
> en el issue #15).

## Configuración

La URL de la API ya viene preconfigurada (`https://app.egloff.com.mx`) —
en el uso normal lo único que tenés que configurar es tu token.

**Recomendado — una sola vez, queda funcionando siempre:** corre el
asistente interactivo. Te va a pedir únicamente un token (página Panel →
API Token), probar la conectividad, y guardarlo en
`~/.config/egloff-api/config` (permisos `600`). No necesitás volver a
hacer nada en sesiones de shell nuevas ni al reiniciar el equipo:

```bash
egloff-api
```

`egloff-api doctor` diagnostica una configuración rota (dependencias,
token, conectividad) y muestra el origen de la URL resuelta (`default`,
`env` o el archivo de config), sin modificar nada. `egloff-api config
show|set-url|set-token` gestiona la config guardada directamente, sin
pasar por el asistente completo.

**Alternativa — apuntar a otra instancia (testing):** `egloff-api config
set-url URL` persiste un override permanente, o exportá `EGLOFF_API_URL`
para un override de una sola sesión (tiene prioridad sobre la config
guardada y sobre el default, y solo dura mientras esa terminal esté
abierta). Un `EGLOFF_API_URL=""` explícito se comporta igual que no
exportarla — cae al default, no es un error. Nunca confirmes el token en
un commit ni lo pegues en el chat:

```bash
export EGLOFF_API_URL="https://your-instance.example.com"  # opcional: solo para apuntar a otra instancia
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
- `git` (solo para `egloff-api update`)
- Una instancia de app-egloff en ejecución y un token de API de Sanctum válido

## Licencia

Apache-2.0 — ver `LICENSE`.
