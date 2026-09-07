# tools/kagi

Kagi search settings as code. `kagi.toml` declares personalized results
(block/lower/raise/pin), custom lenses, enabled built-in lenses, and custom
assistants. On `apply` the config is the full truth: resources on the account
that the file does not declare are deleted. `PLAN.md` holds the design and the
verified endpoints and field names; read it before touching `kagi.py`.

To use an assistant, type its bang in the Kagi search box: `!compare ÅNNELAND
vs Zinus queen`.

## Commands

```bash
uv sync                              # once per machine
uv run playwright install chromium   # once per machine, browser for read/apply
uv run kagi read                     # log in and count what the account holds
uv run kagi plan                     # diff live state against kagi.toml
uv run kagi apply                    # enforce kagi.toml, deletions included, then re-check
uv run kagi mine                     # propose raises from Brave history
uv run kagi --config /path/to/other.toml plan   # --config precedes the subcommand
uv run pytest
uv run ruff check && uv run ruff format --check
uv run ty check
```

## Privacy rule

This repo is public. Nothing derived from the account or from browsing ever
lands in the tree:

- Everything `mine` and the browser session write goes under
  `~/.local/state/kagi/` (`XDG_STATE_HOME` respected): the copied History
  sqlite, reports, proposals, and the Playwright storage state
  `kagi-session-token.json`. Probe configs for testing `apply` go there or
  in a scratch directory, never in the repo.
- Kagi Assistant thread exports you want mined go in
  `~/.local/state/kagi/exports/`, not here.
- `KAGI_SESSION_LINK` (Kagi Settings > Account > session link) lives in
  `~/.secrets`. Never print it; `kagi.py` redacts it from Playwright errors.
- `tools/kagi/.gitignore` is a backstop only. Run `git status` before staging.

## Layout

- `kagi.toml`: the config; edit by hand, merge `mine` proposals in by hand.
- `src/kagi_config/config.py`: schema, loader, and Kagi cap validation.
- `src/kagi_config/plan.py`: pure diff, no browser.
- `src/kagi_config/mine.py`: Brave history and export mining.
- `src/kagi_config/kagi.py`: Playwright login, `read` via DOM queries and
  the Assistant JSON API, `apply` via the same form posts the pages make.
- `src/kagi_config/cli.py`: the `kagi` entry point (`read`, `plan`, `apply`, `mine`).
