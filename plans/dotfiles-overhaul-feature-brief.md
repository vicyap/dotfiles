# Dotfiles Install and Sync Overhaul Feature Brief

## Background

The current dotfiles repo works, but the install and sync paths have grown into
one large shell workflow. `install.sh` is the fresh-machine entrypoint, while
`bin/dotfiles sync` partially duplicates installer behavior and also runs slow
upstream refreshes. That makes routine syncs slower than necessary and makes it
harder to reason about first-run, partially bootstrapped, and already-managed
machines.

A complete overhaul should make the repo convergent, idempotent, and easier to
test while preserving the omakase model: one curated setup, no configuration
matrix, and no interactive package manager abstraction beyond the choices the
repo already makes.

## Problem Statement

The current implementation has several failure modes:

- Local convergence and upstream updates are coupled, so a normal `dotfiles sync`
  can run expensive refresh work.
- `install.sh` and `bin/dotfiles` duplicate responsibilities instead of sharing a
  small set of composable operations.
- The old separate first-run entrypoint is redundant after the repo exists because
  `install.sh` already handles first-run bootstrap work.
- Some commands assume the repo lives at `~/.dotfiles`, which makes worktree
  testing and alternate checkout paths awkward.
- Plugin, marketplace, and skill installation is mostly best-effort, but not
  clearly separated between "ensure installed" and "update to latest".
- There is no dry-run or temp-home test harness for validating symlink and config
  behavior without touching the real `$HOME`.

## Goals

- Make `install.sh` the one-shot fresh-machine entrypoint.
- Make `dotfiles sync` the fast, safe, repeatable convergence command after the
  repo exists.
- Add `dotfiles update` as the explicit expensive refresh command.
- Remove the separate first-run entrypoint from the documented command surface.
- Centralize install/sync/update behavior into reusable shell functions.
- Support partial bootstrap from a cloned repo, including missing `zsh`, `vim`,
  and `mise`.
- Preserve existing symlink semantics, backup behavior, and non-interactive
  conflict skipping.
- Make plugin, marketplace, skill, and mise tasks idempotent and observable.
- Add a lightweight verification harness that can run against a temporary home.
- Keep secrets out of the repo and avoid introducing any new credentials or
  machine-specific values.

## Non-Goals

- Do not add a generalized dotfiles framework.
- Do not introduce per-machine configuration switches beyond the existing
  `~/.secrets`, local agent rules, and ignored local config patterns.
- Do not replace curated tool choices with alternatives.
- Do not migrate away from shell unless a specific module becomes too complex to
  maintain safely in shell.
- Do not make `sync` upgrade every external dependency by default.

## Proposed Command Model

### Fresh Machine

Use one of:

```bash
curl -fsSL https://raw.githubusercontent.com/vicyap/dotfiles/main/install.sh | bash
```

or:

```bash
git clone https://github.com/vicyap/dotfiles.git ~/.dotfiles
~/.dotfiles/install.sh
```

`install.sh` should:

- install bootstrap packages needed to continue;
- clone the repo when running from a pipe;
- load shared helper modules;
- install core dependencies;
- symlink packages;
- generate derived config;
- install missing local tools, plugins, and skills;
- optionally prompt to make zsh the default shell.

### Existing Machine

```bash
dotfiles sync
```

`sync` should:

- resolve the actual repo path from the CLI symlink or `DOTFILES_DIR`;
- pull latest repo changes;
- ensure bootstrap/core dependencies needed for convergence;
- re-run symlinks and generated config;
- ensure required local plugins, skills, and mise-managed tools exist;
- skip expensive upstream refreshes.

### Upgrade Everything

```bash
dotfiles update
```

`update` should:

- run `sync` first;
- run Homebrew update and Brewfile bundle on macOS;
- run mise upgrades and update tasks;
- update zsh plugins;
- update Claude and Codex marketplaces/plugins;
- refresh skill registries;
- prune excluded skills and resync Claude skills.

## Proposed Architecture

Split the shell implementation into small modules while keeping the repo simple:

- `lib/platform.sh`: OS detection, command checks, system package helpers,
  zsh/vim/mise installation, default editor and shell helpers.
- `lib/symlink.sh`: existing package mirror and backup behavior.
- `lib/converge.sh`: local convergence steps shared by `install.sh` and
  `dotfiles sync`.
- `lib/update.sh`: expensive upstream refresh steps used only by
  `dotfiles update`.
- `lib/agents.sh`: Claude/Codex rules, skills, marketplaces, and plugin
  convergence.
- `bin/dotfiles`: thin command dispatcher with path resolution and user-facing
  command surface.
- `install.sh`: fresh-machine bootstrap wrapper that delegates to shared
  functions after the repo is available.

This split should reduce the size of each script and make command behavior
explicit without requiring a build system.

## Idempotence Rules

- "Ensure" functions should check current state before doing network work.
- "Update" functions may pull, upgrade, or refresh upstream state.
- A missing optional CLI should skip with a clear message instead of failing the
  whole run.
- A required bootstrap dependency should either be installed or fail with a clear
  next step.
- Symlink conflicts should continue to follow the existing
  `DOTFILES_FORCE`/`DOTFILES_INTERACTIVE` behavior.
- Generated files should be rewritten from repo sources, not edited in place.

## Testing and Verification

Add a script such as `scripts/test-sync.sh` that runs:

```bash
bash -n install.sh bin/dotfiles lib/*.sh
shellcheck -x install.sh bin/dotfiles lib/*.sh
git diff --check
```

Add a temp-home convergence test that:

- creates a temporary `$HOME`;
- sets `DOTFILES_DIR` to the current checkout;
- stubs networked commands such as `git`, `mise`, `claude`, `codex`, `npx`, and
  `tic`;
- runs `dotfiles sync`;
- asserts key symlinks and generated files exist;
- asserts dotfiles-owned agent skills are copied and Claude skill symlinks are
  created.

For real-machine smoke checks:

```bash
dotfiles status
dotfiles cd
DOTFILES_INTERACTIVE=never dotfiles sync
```

Only run `dotfiles update` manually when intentionally refreshing external
dependencies.

## Migration Plan

1. Add the temp-home harness first so behavior can be checked before refactors.
2. Extract shared helper functions without changing command behavior.
3. Introduce clear `ensure_*` and `update_*` function pairs for networked
   systems.
4. Change `dotfiles sync` to call local convergence only.
5. Add `dotfiles update` for expensive refreshes.
6. Deprecate or remove the old bootstrap docs.
7. Update `README.md`, `CHEATSHEET.md`, and `AGENTS.md`.
8. Run temp-home tests plus shell syntax/lint checks.
9. Manually run a real `dotfiles sync` after review.

## Risks

- Some third-party CLIs may not provide stable machine-readable output, so
  installed-state checks need to be conservative.
- `set -e` plus best-effort commands can create surprising exits if helper
  functions are not carefully written.
- macOS and Linux package behavior differs enough that platform update logic
  should stay explicit.
- Symlink behavior touches user home directories, so the temp-home harness is
  important before real runs.
- Over-eager cleanup of skills/plugins could remove user-installed items; pruning
  must remain scoped to dotfiles-owned manifests and explicit excludes.

## Acceptance Criteria

- `install.sh` works as the fresh-machine entrypoint.
- `dotfiles sync` is safe to run repeatedly and avoids intentional upstream
  refreshes.
- `dotfiles update` performs the expensive refresh path.
- The CLI resolves the repo path correctly from symlinked and worktree checkouts.
- Existing docs describe only the new command model.
- Temp-home verification passes without modifying the real `$HOME`.
- `bash -n`, ShellCheck, and `git diff --check` pass.
- No unrelated dirty worktree files are staged or committed.
