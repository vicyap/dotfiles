# Kagi configuration as code

This tool makes the managed parts of a Kagi account match `kagi.toml`:
domain rankings, custom lenses, built-in lens enablement, and custom assistants.
The config is the complete desired state for those resources. Removing a domain
restores its neutral rank; removing a custom lens or assistant deletes it;
removing a built-in lens disables it. Other account settings, including video
channel rankings, are outside this tool's scope.

## How to reason about a change

`cli.py` connects three steps: load desired state → read live state → diff.
`plan` prints the diff. `apply` computes its own fresh diff, performs the writes,
then reads and diffs again. There is no saved plan or persistent resource-state
file; browser storage holds authentication only. A previously inspected plan
does not freeze what a later apply will do.

- `config.py` defines immutable desired-state values and validates TOML,
  domain syntax, lens caps, and assistant-to-lens references before browser work.
- `plan.py` compares those values with `LiveState` without doing I/O. Domains
  identify ranking rules; names identify lenses and assistants. Renaming a
  resource therefore means delete/create. Kagi IDs are discovered on each read
  and used only to address writes. Unknown built-in names fail during planning.
- `kagi.py` translates between that model and Kagi's web interfaces. Rankings
  and lenses use settings-page DOM reads and form posts; assistants use the
  web app's JSON API at `assistant.kagi.com/api`. Inspect `JS_*`, `lens_form`,
  `assistant_json`, and their parsers for selectors and wire fields. These are
  website integration details that can change independently of this package.

The policy lives in `kagi.toml`: global ranks express preferences, selective
exclude-only lenses preserve discovery, and assistant instructions guide how
evidence is evaluated. Edit that file for personalization. Type `!engblogs` or
`!compare` followed by a query in Kagi's search box to launch the assistants.
A matching account config proves settings were stored, not that a model will
obey every instruction; verify answer behavior separately.

## Write semantics that matter

- Writes are sequential, not transactional. Rankings are applied first, then
  removed assistants and lenses, then lens changes, then assistant creates and
  updates. Lens IDs are refreshed before binding assistants. Deleting a lens
  while a surviving assistant still references it is not live-tested.
- Built-in changes rendered as `+`/`-` toggle enablement. `/lenses/subscribe`
  is a toggle, so `_set_active` checks current state first; enabling also needs
  `next_index`. Replaying a toggle blindly can undo a successful write.
- Kagi can return HTTP 504 after a write has landed. `_check` tolerates 504;
  the post-apply diff decides whether the account converged. Other HTTP errors
  can stop a partially completed apply. Inspect a fresh plan after failure.
- Equality covers only modeled fields. `lens_form` sends defaults for unmodeled
  fields such as description, date range, file type, and shortcut. Those fields
  reset when a lens is created or updated; drift in them alone produces no diff.
- Adding a managed field requires agreement between the config value, live
  parser, and write payload. Otherwise a successful write can leave a permanent
  diff. `tests/test_kagi.py` checks mapping round trips; `tests/test_plan.py`
  checks reconciliation semantics.

## Local usage and privacy

Run commands from `tools/kagi`. Python and dependencies are declared in
`pyproject.toml` and locked by `uv.lock`. Implementation modules live under
`src/kagi_config/`.

```bash
uv sync
uv run playwright install chromium  # initial browser setup
uv run kagi read                    # read live state and print resource counts
uv run kagi plan                    # inspect all changes, especially removals
uv run kagi apply                   # write changes and require an empty diff
uv run kagi plan                    # independently confirm convergence
```

`--config /path/to/config.toml` and `--headed` precede the subcommand.
Every browser session requires `KAGI_SESSION_LINK` in the environment, sourced
from `~/.secrets`. It is a bearer credential: never print it. Login navigation
errors redact the link; preserve that protection when changing authentication.

`paths.py` keeps session storage, history snapshots, reports, and proposals under
`~/.local/state/kagi/` (or `$XDG_STATE_HOME/kagi/`). Keep account-derived data,
probe configs, screenshots, and thread exports outside this public repository.
The saved session is `kagi-session-token.json`; manual exports go in `exports/`.

`uv run kagi mine` is a separate, explicitly invoked proposal workflow. It copies
Brave's History SQLite database, associates direct `visits.from_visit` children
with Kagi queries, and proposes global raises from click counts. It never edits
the config or account. The default history path is macOS-specific; `--history`
selects another file. New-tab attribution is unverified. Export handling only
reports file structure/counts; it does not extract recommendations from threads.
Review proposals and merge desired entries by hand.

## Verification

```bash
uv run pytest
uv run ruff check
uv run ruff format --check
uv run ty check
```

The tests cover validation, diffs, data mappings, CLI parsing, and synthetic
history mining; they do not exercise the live website. For integration changes,
inspect a live plan, apply within the authorized scope, and require a fresh
empty plan. Exercise affected lenses and assistant bangs when their behavior
changes. Documentation-only edits need no account writes or history mining.
