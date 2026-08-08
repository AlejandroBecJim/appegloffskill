# appegloffskill

A Claude Code [Skill](https://docs.claude.com/en/docs/claude-code/skills) for
talking to a live [app-egloff](https://github.com/AlejandroBecJim/app-egloff)
instance's Sanctum API — `/api/tasks` and `/api/context-entries` (ADR-0009).

No MCP server, no daemon: a `SKILL.md` instruction contract plus a small
`curl`/`jq` wrapper script. One consumer (Claude Code), zero extra
infrastructure to run or maintain.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/AlejandroBecJim/appegloffskill/main/install.sh | bash
```

This clones the skill into `~/.local/share/egloff-api-skill` and symlinks it
into `~/.claude/skills/egloff-api`. Variants:

```bash
curl -fsSL https://raw.githubusercontent.com/AlejandroBecJim/appegloffskill/main/install.sh | bash -s -- --project /path/to/repo  # project-local: /path/to/repo/.claude/skills/egloff-api
curl -fsSL https://raw.githubusercontent.com/AlejandroBecJim/appegloffskill/main/install.sh | bash -s -- --copy                    # copy files instead of symlinking (default: symlink)
```

Symlinking (the default) means an update in place — re-run the installer to
pick up new versions. Run `curl -fsSL .../install.sh | bash -s -- --help`
for the full flag list (or `./install.sh --help` from a local checkout).

> **Upgrading from an install created before this change**: re-run the
> installer once. Old installs symlink to a path that no longer exists after
> this change, so Claude Code will silently stop finding the skill until you
> re-run `install.sh`.

## Configure

Get a token from your app-egloff instance's Panel → API Token page, then
export it in your shell (never commit it, never paste it into chat):

```bash
export EGLOFF_API_URL="https://your-instance.example.com"
export EGLOFF_API_TOKEN="the-sanctum-token"
```

## Use

Once installed and configured, ask Claude Code to push or read tasks /
context entries against your instance — it will load `skills/egloff-api/SKILL.md`
and drive the `egloff-api` CLI for you. To call it directly:

```bash
egloff-api tasks:create --title="Buy milk" --on_radar_today=true
egloff-api context:create --type=decision --title="..." --content="..." --topic_key="sdd/foo"
egloff-api context:list --search=deploy
```

Run `egloff-api` with no arguments for an interactive setup assistant that
persists your URL/token to `~/.config/egloff-api/config`, or `egloff-api
doctor` to diagnose a broken setup.

See `skills/egloff-api/SKILL.md` and `skills/egloff-api/references/endpoints.md`
for the full contract.

## Requirements

- `curl`, `jq`
- A running app-egloff instance and a valid Sanctum API token

## License

Apache-2.0 — see `LICENSE`.
