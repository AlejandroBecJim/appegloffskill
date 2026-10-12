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

`egloff-api update` también repara automáticamente las instalaciones
`--project PATH` registradas: cada `install.sh --project PATH` deja un
registro en un manifiesto JSON (`{version, projects: [{path, mode,
installed_at}]}`) en `${EGLOFF_STATE_ROOT:-<EGLOFF_INSTALL_ROOT>-state}/projects.json`
(un directorio hermano de la instalación, nunca dentro de ella). En cada
`egloff-api update` (modo global o local) se recorre ese manifiesto:
symlinks de proyecto rotos o ausentes se reinstalan automáticamente, las
rutas de proyecto que ya no existen se eliminan del manifiesto y se
reportan, y se imprime un resumen (`Project installs: N ok, M repaired, K
pruned`). Un manifiesto ausente o corrupto nunca hace fallar `update`.

## Agent registration

Agents that don't scan `~/.claude/skills` (Codex, OpenCode, Gemini) would
never see the installed skills, so `install.sh` also writes a managed block
(skill name, trigger description and the absolute path of its installed
`SKILL.md`) between `<!-- egloff-skills:start -->` and
`<!-- egloff-skills:end -->` markers. The block tells the agent to read that
`SKILL.md` whenever a request matches a trigger.

- Global install: `~/.claude/CLAUDE.md` always, plus `~/.codex/AGENTS.md`,
  `~/.config/opencode/AGENTS.md` and `~/.gemini/GEMINI.md` only when that
  agent's config directory already exists (agent config dirs are never
  created).
- `--project PATH`: `PATH/CLAUDE.md` and `PATH/AGENTS.md`. These files are
  usually committed, so entries use the relative path
  `.claude/skills/<skill>/SKILL.md`; no absolute local path is written there
  (global blocks do use absolute paths).
- Antigravity does not read those files: it only loads skills from the
  `entries` of a `skills.json`. So the installed clone's `skills/` directory
  (absolute path) is also merged into `~/.gemini/config/skills.json` (only
  when `~/.gemini` exists) and, with `--project PATH`, into
  `PATH/.agents/skills.json`. Existing entries and other keys are kept, the
  entry is added once (re-running or `egloff-api update` does not duplicate
  or rewrite it), the write is atomic, and a file that is not a JSON object
  with an `entries` array is left untouched with a warning. The same opt-outs
  apply as for the managed block. Project `skills.json` files hold an
  absolute local path, so add `.agents/skills.json` to `.gitignore` if the
  project is shared.
- `skills.json` entries are not removed automatically if the clone is moved or
  deleted, or after a later `--no-register` (same as the managed block):
  remove stale entries by hand.
- Content outside the markers is never touched; re-running replaces the block
  in place (idempotent). A file with unbalanced markers is skipped with a
  warning. Registration never fails the install.
- `egloff-api update` regenerates the block for the global targets and every
  project in the manifest, so skills removed from the repo drop out.
- Opt out with `--no-register` or `EGLOFF_NO_REGISTER=1`. The choice is
  remembered, so `egloff-api update` keeps honoring it: a global opt-out is a
  `no-register` marker file in the state dir
  (`${EGLOFF_STATE_ROOT:-<EGLOFF_INSTALL_ROOT>-state}`), a `--project` opt-out
  is `"register": false` on that project's manifest entry. Re-running
  `install.sh` without the opt-out clears it. `EGLOFF_NO_REGISTER=1` is also
  honored directly by `update`.
- Descriptions are copied from each `SKILL.md` frontmatter into files agents
  load on every session (and `update` copies them from the upstream repo), so
  they are sanitized: control characters and newlines are removed, whitespace
  is collapsed, HTML-comment sequences (`<!--`, `-->`) are defused so a
  description cannot forge or break the markers, and each name/description is
  capped at 300 characters with a trailing `...`. Review upstream changes
  to `skills/*/SKILL.md` as you would any instruction file.

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

## Otras skills incluidas

Además de `egloff-api`, el repo trae skills de uso general; `install.sh` instala
todas las que haya bajo `skills/` y `egloff-api update` las mantiene al día.

- `issue-format` — formato de issues (aprobados desde el inicio, prioridad como label), para cualquier repo.
- `pr-format` — formato de PRs (resumen, decisiones tomadas, riesgos, cómo se validó y criterios del issue
  resueltos), para cualquier repo.
- `rfc-format` — formato de RFCs en `docs/rfc/` (plantilla completa y corta para cambios visuales, numeración,
  estados e índice), para cualquier repo.
- `adr-format` — formato de ADRs en `docs/adr/` (plantilla, numeración, índice y flujo de reemplazo), para
  cualquier repo.
- `constitution` — guía la creación de `docs/constitution.md` preguntando una cosa a la vez, con un esquema de
  10 secciones.

Son skills separadas a propósito: cada una se carga solo cuando se pide crear un issue, un PR, un RFC, un ADR
o la constitución.

## Requisitos

- `curl`, `jq` — `install.sh` requiere `jq` incondicionalmente (incluso sin
  `--project`) para poder mantener el manifiesto de instalaciones por
  proyecto
- `git` (solo para `egloff-api update`)
- Una instancia de app-egloff en ejecución y un token de API de Sanctum válido

## Licencia

Apache-2.0 — ver `LICENSE`.
