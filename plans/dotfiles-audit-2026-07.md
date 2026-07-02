# Dotfiles Audit — July 2026

Multi-agent audit of the whole repo (shell runtime, Nix/home-manager, installer,
tool configs, agent configs) with live measurements on rhinestone and
adversarial verification of every finding. Quick wins were applied, converged,
and committed individually (see git log for 2026-07-01); this file records the
measured results and everything intentionally left as a recommendation.

## Applied (committed 2026-07-01)

| Fix | Measured impact |
|---|---|
| zsh: `skip_global_compinit=1` + mtime-gated `compinit -C` | `/usr/bin/zsh -i` (what SSH/tmux spawn): **671ms → 86ms**; Nix zsh 102ms → 82ms |
| mise: `hook_env.chpwd_only = true` | per-prompt hook-env 15.5ms → 6.1ms; full eval still runs on `cd` |
| starship: disable default-enabled `netns` module | 1–3ms/prompt, output always empty outside a netns |
| direnv: `nix-direnv.enable` | `use flake` devShells now cached on flake.lock hash |
| atuin: `search_mode = "daemon-fuzzy"` | Ctrl-R queries daemon index instead of SQLite per keystroke |
| bash/zsh: trailing `[[ -f ... ]] &&` guard → `if` | `bash -i -c cmd` no longer starts with `$? = 1` |
| bash: add `~/.resend/bin` to PATH | parity with zsh `home.sessionPath` |
| tmux: `historyLimit` 1M → 100k, `extended-keys on` | bounded per-pane memory on the OOM-postmortem host |
| install: wire `hooks/pre-commit` via `core.hooksPath` | gitleaks scan actually runs now (was never installed) |
| install: `\|\| warn` guards on apt/curl/brew/atuin steps | transient network failure no longer aborts converge/refresh |
| install: drop `ensure_extra_tools` | `mise run update:tools` already runs the same six setup tasks — every `dotfiles update` built them twice |
| symlinks: per-package manifest + dangling-link prune | deleted/renamed sources no longer leave stale `$HOME` links |
| install: `sync_claude_rules` admits `-f` entries only | dangling rule sources were re-created in `~/.claude/rules` forever |
| zsh: `if`-guard the trailing ssh-opener block | fresh machines without ssh-opener started every zsh with `$? = 1` (caught in the nixtest VM) |
| dotfiles: `pull --rebase --autostash` | dirty tree no longer aborts pull/update with a raw rebase error |
| claude: `attribution` = no trailers, no session URL | enforces the AGENTS.md no-attribution rule at the harness level |
| codex: drop `PostToolUseFailure` hook; purge deployed `[otel]` | dead event removed; telemetry block from 451fe04 finally gone |
| nix: `services.home-manager.autoExpire` (rhinestone) | 30-day generation expiry + weekly store GC; / was 85% with 3911 dead paths |
| docs: CHEATSHEET fdfind/batcat caveats removed | stale since the Nix migration |

Deployed-state cleanup (no commits): removed orphaned pre-Nix plugin dirs
(`~/.zsh/plugins/{fast-syntax-highlighting,zsh-autosuggestions,fzf-tab.backup}`),
stale `~/.zcompdump-rhinestone-5.9{,.zwc}`, four dangling symlinks under
`~/.claude` and `~/.agents`, a stray `~/.direnvrc` (errored on every direnv
load), a go-installed `shfmt` shadowing the Nix one, and `mise prune` of
orphaned installs.

## Fresh-machine validation (vms/nixtest)

The full converge path was exercised in a throwaway nixtest VM (Ubuntu 24.04,
libvirt): provision → `converge` → `verify.sh`. Confirmed on a machine with no
prior state: gitleaks hook wired (`core.hooksPath = hooks`), all 10 symlink
manifests seeded, `skip_global_compinit` in the generated `~/.zshenv`, system
zsh startup ~120ms (no double compinit), `bash -i` and `zsh -i` both exit 0,
all home-manager symlinks and nix-profile tools present. The VM also caught
the ssh-opener guard bug listed above — rhinestone masks it because
ssh-opener is installed there. `refresh_upstream` was not run in the VM (its
`nix flake update` would test upstream currency, not these changes); its edits
are covered by shellcheck plus the `mise tasks deps update:tools` equivalence
check.

## Recommended, not applied

### merge-codex-config.py: allowlist preserved state (correctness, high)

The merger re-emits any top-level table/scalar from the previous generated
config that base/local don't define — forever. That is how the removed `[otel]`
block survived its deletion. The deployed copy was purged by hand, but the
mechanism remains: any table removed from base/local in the future will be
resurrected the same way. Fix: preserve only what Codex actually writes —
`RUNTIME_ALLOWLIST_TOPS = {"projects", "hooks", "tui", "notice"}` and
`RUNTIME_ALLOWLIST_SCALARS = {"service_tier"}` — instead of "everything
unmanaged". The same change fixes the line-level parser's multi-line-scalar
truncation risk (a preserved top-level array/multiline string would keep only
its first line today).

### mise binary self-update (currency, low)

`dotfiles update` upgrades mise-managed tools but never the mise binary itself
(2026.2.19 installed vs 2026.6.14 available, ~4 months drift). On Linux
(curl-script install) add `mise self-update --yes || true` to
`refresh_upstream`; on macOS mise is brew-owned, so `brew bundle` already
covers it — the step must be platform-conditional.

### zcompile the completion dump (perf, low)

`~/.zcompdump` has no `.zwc`. Compiling it after regeneration shaves parse time
off the remaining single compinit. Needs a race-safe hook (concurrent shell
starts), so it was deliberately left out of the compinit fix. Only worth doing
if shell start ever feels slow again; the big win is already banked.

### lazygit light/dark theme integration (structure, low)

lazygit is the one switcher-covered-adjacent tool with a hardcoded Mocha
palette. Right mechanism (verified against lazygit 0.61.1): `LG_CONFIG_FILE`
accepts a comma-separated list with later files overriding earlier ones — point
it at `config.yml,~/.config/lazygit/theme.yml` and have `light`/`dark` rewrite
only the small theme overlay file. No sed-ing the main config.

### statusline.sh subprocess trim (perf, optional)

The status line spawns 2 git + 2 jq processes per render (~22ms). The dirty
check could be one `git status --porcelain` and the model/ctx jq calls could
fold into the existing combined jq call, cutting it to ~2 spawns. Deliberately
skipped: it works, and the rewrite is more parsing logic for ~15ms — revisit
only if statusline latency ever becomes noticeable.

### Automate mise prune (hygiene, low)

Orphaned installs re-accumulate with version bumps. `mise prune -y` could run
in `refresh_upstream` after `mise upgrade`, but verify prune semantics first
(it also drops versions pinned only by projects mise hasn't seen recently).

### bash PATH dedup (cosmetic)

`.bashrc` re-prepends its PATH entries on nested invocations. Harmless for a
fallback shell; a `case ":$PATH:"` guard would fix it if it ever bothers you.

## Investigated — no change needed

- **fzf-tab load order**: generated rc loads fzf-tab after zsh-autosuggestions,
  which fzf-tab's README warns against — but autosuggestions 0.7.x binds its
  widgets lazily at first precmd, so the order is harmless; widgets verified
  live (Tab → `fzf-tab-complete`, autosuggest wrapping intact). The old
  hand-written rc sourced fzf-tab last, deliberately, for years.
- **starship git_status cost**: 2–3ms in this repo; scales in huge repos but
  measured fine here. `command_timeout` defaults are adequate.
- **tmux status-interval 1**: `tmux-status` is a fast Go binary; 1s refresh is
  fine.

## Notes

- atuin `daemon-fuzzy` escape hatch: if Ctrl-R ever hangs after a daemon crash
  or suspend/resume weirdness, `rm ~/.local/share/atuin/atuin.sock` (known
  upstream issue class atuin #2969/#3382).
- mise per-prompt floor: ~6ms of the hook cost is process spawn and can't be
  configured away; eliminating it entirely would mean `mise activate --shims`,
  which changes env-var semantics and is not recommended for this setup.
- lima/macOS follow-ups live in `plans/lima-macos-improvements.md`.
