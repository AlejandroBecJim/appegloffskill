# appegloffskill

A Claude Code [Skill](https://docs.claude.com/en/docs/claude-code/skills) for
talking to a live [app-egloff](https://github.com/AlejandroBecJim/app-egloff)
instance's Sanctum API — `/api/tasks` and `/api/context-entries` (ADR-0009).

No MCP server, no daemon: a `SKILL.md` instruction contract plus a small
`curl`/`jq` wrapper script. One consumer (Claude Code), zero extra
infrastructure to run or maintain.

## Install

```bash
git clone https://github.com/AlejandroBecJim/appegloffskill.git
cd appegloffskill

./install.sh                        # global: ~/.claude/skills/egloff-api
./install.sh --project /path/to/repo  # project-local: /path/to/repo/.claude/skills/egloff-api
./install.sh --copy [...]           # copy files instead of symlinking (default: symlink)
```

Symlinking (the default) means `git pull` in this repo updates every
install in place. Run `./install.sh --help` for the full flag list.

## Configure

Get a token from your app-egloff instance's Panel → API Token page, then
export it in your shell (never commit it, never paste it into chat):

```bash
export EGLOFF_API_URL="https://your-instance.example.com"
export EGLOFF_API_TOKEN="the-sanctum-token"
```

## Use

Once installed and configured, ask Claude Code to push or read tasks /
context entries against your instance — it will load `egloff-api/SKILL.md`
and drive the `egloff-api` CLI for you. To call it directly:

```bash
egloff-api tasks:create --title="Buy milk" --on_radar_today=true
egloff-api context:create --type=decision --title="..." --content="..." --topic_key="sdd/foo"
egloff-api context:list --search=deploy
```

Run `egloff-api` with no arguments for an interactive setup assistant that
persists your URL/token to `~/.config/egloff-api/config`, or `egloff-api
doctor` to diagnose a broken setup.

See `egloff-api/SKILL.md` and `egloff-api/references/endpoints.md` for the
full contract.

## Requirements

- `curl`, `jq`
- A running app-egloff instance and a valid Sanctum API token

## License

Apache-2.0 — see `LICENSE`.
