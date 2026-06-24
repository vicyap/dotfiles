# Nix Migration Plan

## Decision

Manage the environment with **Nix**:

- **home-manager** on both hosts (rhinestone = Ubuntu, lima = macOS) for user
  packages, dotfiles, program configs, and agent (Claude Code / Codex) setup.
- **nix-darwin** on lima for macOS system defaults, GUI apps, launchd, and
  system packages.
- **mise** kept for per-project language-runtime versions.
- **apt** kept on rhinestone for system packages, services, and the host-scoped
  memory hardening.
- **1Password** as the secrets backend.

## Why Nix

- One declarative, idempotent model expresses the user environment the same way
  on both operating systems, with per-host differences as data rather than
  branching shell logic.
- Nix manages packages *and* configuration in one graph, so "what is installed"
  and "how it is configured" live together and converge with a single command.
- nix-darwin is the only way to declare macOS system preferences as data instead
  of a pile of imperative `defaults write` calls.
- Secrets integrate cleanly: encrypted at rest, decrypted at activation into
  paths outside the store, with 1Password as the source of truth.

Reproducibility and atomic rollback come for free with this model but are not the
motivation; idempotent convergence is.

## Ownership model — what each layer manages

The point of the layout is that every path has exactly one owner, and
app-mutated state has no Nix owner at all.

- **home-manager (both hosts)** — user CLI tools, shell + tool configs
  (`programs.*`), the mise binary and its shell hook, and the agent layer
  (settings, skills, plugin reconciliation). No sudo; packages land in the user
  profile.
- **nix-darwin (lima only)** — macOS `system.defaults`, GUI apps via Homebrew
  casks, launchd agents, and system packages. There is no Linux equivalent, so
  this layer simply does not exist on rhinestone.
- **mise (both hosts)** — language-runtime versions only (Node, Python, Go, Bun,
  Erlang, Elixir), global pins plus per-project `.mise.toml`. Nix owns the mise
  binary; mise owns versions. This split exists because per-directory runtime
  switching has no home-manager equivalent.
- **apt (Ubuntu only)** — system packages and services that need OS
  integration (docker, tailscale, compilers, build deps), and the root-owned
  `/etc` memory hardening where host-scoped. This stays outside Nix because
  there is no Nix system layer on a non-NixOS Linux host without converting the
  whole OS.

## Repository shape — what, not how

The flake exposes generic Home Manager configurations by OS and architecture
(`ubuntu-<nix-system>` and `macos-<nix-system>`), plus compatibility targets for
older host-specific activations. The lima darwin configuration embeds
home-manager for the macOS system layer.

Configuration is organized as feature-scoped modules (shell, git, tmux, agents,
packages, etc.). Each module holds shared options plus platform branches, so a
feature is described once and adapts per OS. Host entrypoints compose the
modules and set host-specific values. Shared modules are reusable; the per-host
configurations are thin.

Why this shape: it keeps the two-OS difference inside each feature as data, makes
a feature legible in one place, and avoids a configuration matrix.

## Agent layer — the part that needs care

Claude Code and Codex read some files and write others. The plan treats each
class differently, because Nix's store is read-only and would otherwise break the
apps.

- **Static config the apps read** (Claude `settings.json`, `CLAUDE.md`,
  `statusline.sh`, `agents/`, hooks; Codex `config.base.toml`, `hooks.json`;
  shared `AGENTS.md` and rules) → writable symlinks pointing into the dotfiles
  repo, not copies into the store. Why: the app must be able to read them, you
  want repo edits live without a rebuild, and a read-only store link would also
  break the in-place theme switcher for files like the ghostty config.
- **Files the apps append to** (notably Codex `config.toml`, which gains
  `[hooks.state]` trust hashes and `[projects]` trust levels at runtime) →
  seeded once if absent, then owned by the app. Why: a store symlink is
  read-only, and re-stamping on every switch would erase the app's trust state
  and force re-approval.
- **Plugins and marketplaces** → reconciled by activation scripts that call the
  app's own CLI (`claude plugin install`, `codex plugin add`), guarded so they
  run when the declared set changes. Why: plugin installation is not something
  Nix can model as a build output, and delegating to the app's installer is what
  keeps each plugin's own config and credentials intact.
- **Dotfiles-owned skills** (the few maintained in this repo) → managed files.
  **Third-party skills** → fetched as declared external sources. Why: owned
  content travels with the repo; external content is declared by reference, not
  vendored.
- **Runtime state — never managed by Nix.** This set must survive every switch
  untouched: `~/.claude.json`, `*.credentials.json`,
  `installed_plugins.json`, `known_marketplaces.json`, conversation/session
  history and projects; Codex `auth.json`, session history, and the `*.sqlite`
  databases; mise installs and shims; atuin databases; tmux plugin and resurrect
  trees; shell history. Why: these are app-owned, secret, or large and
  regenerable — managing any of them logs you out or destroys state.

## Packages — what goes where

- **Global CLI tools** (the modern replacements: ripgrep, fd, bat, eza, dust,
  procs, sd, delta, jq, yq, jless, lazygit, lazydocker, starship, atuin, etc.) →
  home-manager `home.packages`, one declared set shared by both hosts. Why: a
  single source of truth for the tools you want everywhere, removing today's
  three-way overlap across mise, brew, and apt.
- **Language runtimes** → mise. Why: per-project versions.
- **Custom tools** (web, ask, ssh-opener, the tmux status binary) → Nix
  derivations or flake inputs where packageable, otherwise activation-time
  installs. Why: keep them inside the declarative graph instead of ad-hoc curl
  and build steps.
- **macOS GUI apps** → nix-darwin Homebrew casks. Why: the declarative path for
  apps Nix does not package well.
- **Ubuntu system packages and `/etc` hardening** → apt, host-scoped. Why: see
  ownership model.

## Secrets — 1Password

- Secrets are never written into Nix expressions; the store is world-readable.
  They are referenced by `op://` path and materialized at activation into
  permission-restricted paths outside the store.
- On lima (has a GUI) interactive 1Password auth is available. On rhinestone
  (headless) the only working auth is a 1Password **service account token**,
  which requires a Teams or Business plan. If the account is personal/Families,
  the fallback is an age-based store (sops-nix/agenix) whose master key is kept
  in 1Password and provisioned once. **This plan tier is the first thing to
  confirm**, because it decides the secrets mechanism.

## macOS system defaults — lima

Declared as data via nix-darwin `system.defaults` and `system.keyboard`:
keyboard repeat and modifier remap, Dock, Finder, trackpad, screenshots, login
window, and any remaining domain through the custom-preferences escape hatch.
Why: replaces imperative `defaults write` scripting with a single declared,
idempotent set.

Known constraints to account for: activation runs as root and needs
`system.primaryUser` set for user-scoped defaults to land on the right account;
some changes still need an app restart or logout to show; App Store apps via
Nix are currently unreliable, so treat those as manual.

## Testing

Validate convergence before it touches a real machine, on both operating
systems:

- Build-without-activate and flake evaluation as the fast gate that every host
  configuration is valid.
- A CI matrix covering both OSes that applies the configuration twice and
  requires a clean second run — the idempotency check.
- A throwaway Linux VM for full end-to-end activation against a clean image.

Why: the agent layer and the secrets/activation scripts are the parts most
likely to drift or be destructive, so they need a no-touch validation path.

## Boundaries / non-goals

- No NixOS conversion of rhinestone; it stays Ubuntu with apt for the system
  layer.
- Nix does not manage app runtime state, mise's per-project job, or the
  host-scoped `/etc` hardening.
- No reproducibility or rollback workflows are built out beyond what the model
  provides by default; they are not goals.

## Open decisions to settle first

1. 1Password plan tier (service account vs age-key fallback) — gates the secrets
   mechanism.
2. Which currently mise-managed CLI tools move to `home.packages` versus staying
   in mise — the recommendation is to move all non-runtime tools to Nix and
   narrow mise to language runtimes.
3. `home.stateVersion` value, set once per host and left fixed.
