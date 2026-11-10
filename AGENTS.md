# AGENTS.md

This file provides guidance to coding agents when working with code in this repository.

## IMPORTANT: This Is a Public Repository

NEVER commit API keys, tokens, passwords, private keys, personal emails, or any other secrets. All sensitive values belong in `~/.secrets` (which is git-ignored). When adding new config files, always check that they contain no credentials or private data before committing.

## What This Repo Is

Personal dotfiles repo. An installer (`install.sh`) applies config two ways: symlinks from `packages/` into `$HOME`, and Nix home-manager (`nix/home/`) for the shell, several core programs, and the CLI tool set. Run `scripts/test-sync.sh` for shell checks and isolated symlink/skill convergence tests. Supports macOS and Ubuntu Linux.

## Philosophy: Omakase Dotfiles

This repo is curated, not configurable. Choices are intentional and integrated — modern CLI replacements (`rg`/`fd`/`bat`/`eza`/`dust`/`procs`/`sd` over classic equivalents), TUIs (`lazygit`/`lazydocker`/`atuin`/`fastfetch`), Catppuccin Mocha theming with a `light`/`dark` switcher applied across ghostty, bat, fzf, tmux, and claude. On Linux, `fd` may be a shell alias to `fdfind`; use `fdfind` if `fd` is unavailable in a non-interactive shell. See [`CHEATSHEET.md`](./CHEATSHEET.md) for the full toolkit and the README's Philosophy section for the rationale.

When proposing changes, prefer cohesion with the existing curation over adding net-new options. Don't silently swap a chosen tool for an alternative ("rg is fine, but ag…"); discuss the trade and let the user decide. Don't propose tools that the repo already manages via `mise`/Brewfile/`packages.txt`. Match the existing aesthetic (Catppuccin, bracketed starship modules, vim-mode tmux) when adding configs.

## Key Commands

```bash
./install.sh              # Fresh machine: converge + upstream refresh (zsh, mise, symlinks, home-manager, tools)
dotfiles pull             # Pull latest + converge (fast, repeatable; alias: sync)
dotfiles upgrade          # pull + expensive upstream refresh (flake inputs, Homebrew, mise upgrades, plugins)
dotfiles cd               # cd into the dotfiles repo
dotfiles help             # all subcommands
```

`install.sh` and `dotfiles pull`/`upgrade` share the same `converge`/`refresh_upstream`
functions in `install.sh`: `converge` applies symlinks, home-manager `switch`
against the locked flake, generated config, pinned mise runtimes, and refreshed
declared agent skills.
`refresh_upstream` does the expensive network refresh (flake update, Brewfile/apt,
mise upgrades, the codex CLI, Claude/Codex plugins).

Platform packages are installed by `install_platform_packages`:
```bash
brew bundle --file=platform/macos/Brewfile   # macOS
dotfiles upgrade                             # Ubuntu apt packages from configured sources
```

## Architecture

### Symlink Convention

Files under `packages/<name>/` mirror `$HOME` structure and get symlinked there:
- `packages/ghostty/.config/ghostty/config` -> `~/.config/ghostty/config`
- `packages/claude/.claude/settings.json` -> `~/.claude/settings.json`

The `lib/symlink.sh` module handles this. It backs up existing files to `~/.dotfiles-backup/<timestamp>/` before replacing. Conflict prompts are disabled by default, so existing files are skipped unless `DOTFILES_FORCE=1` is set. Use `DOTFILES_INTERACTIVE=always` to prompt. Packages owned by Nix home-manager (`NIX_OWNED_PACKAGES` in `lib/symlink.sh`) are skipped here. Links whose source is no longer deployed (a deleted file, a removed package, a package that moved to Nix) are pruned at the start of `converge`.

Edit the tracked source, never the deployed copy. For a symlinked package that is the file under `packages/<pkg>/`. For a Nix-owned program, start at `nix/home/features/<name>.nix`: it either holds the config itself or names the file under `packages/<pkg>/` that it reads at build time or links live. Editing the generated file under `$HOME` is a no-op for future syncs. Before creating a new config under `$HOME`, check whether its parent is already dotfiles-managed (`ls -la` for sibling symlinks into `~/.dotfiles`).

### Nix Home-Manager

`nix/home/` declares the shells and core programs, one feature file per program under `nix/home/features/`, plus the CLI tool set (`packages.nix`), activated by `home-manager switch` during `converge`. Aliases, PATH, and session variables shared by zsh and bash are in `shell.nix`. Several features keep their content under `packages/<pkg>/` and read it at build time (shell functions, starship, atuin, bat and tmux themes) or link it live (vim, lazygit, fastfetch); a build-time file takes effect on the next `dotfiles pull`. `nix/darwin/` holds macOS system settings (`system.defaults` + GUI casks) applied via nix-darwin. Home Manager activation is generic by OS/arch (`ubuntu-<system>`, `macos-<system>`), with a host-specific Darwin config when one exists.

### Adding a New Package

Create a directory under `packages/` with files mirroring their `$HOME` paths. No registration needed -- `symlink_all_packages` iterates all `packages/*/` directories automatically.

### Secrets Pattern

Sensitive data lives in `~/.secrets` (never committed). Both `.zshrc` and `.bashrc` source it if present. The `.gitignore` broadly excludes `*secret*`, `*token*`, `.env*`, credentials, and SSH keys.

### lib/ Modules

- `platform.sh` -- OS/platform detection (`detect_os`, `detect_supported_platform`), bootstrap installers, platform package installs
- `symlink.sh` -- Symlink creation with backup and conflict handling, `NIX_OWNED_PACKAGES`, stale-link pruning

### Tool Management

Choose a tool owner based on its update policy. Nix home-manager is for stable,
general-purpose programs where reproducibility matters more than immediacy
(`rg`, `fd`, `bat`, `tmux`, `git`, etc.). `mise` and `uv` are for tools where
latest is usually best: programming languages, LSPs, fast-moving developer
tools, company/vendor CLIs, and Python CLIs published primarily through PyPI.

`mise` manages the language runtimes, LSP servers, and vendor CLIs pinned in
`packages/mise/.config/mise/config.toml`, whose `setup:*` tasks also build a few
tools from source (among them `web`). Use `uv tool` for Python CLIs
that should track PyPI more closely than nixpkgs. The general stable CLI tool
set comes from Nix home-manager (`nix/home/features/packages.nix`). Before
adding or moving a CLI, check for PATH shadowing so the intended package manager
owns the executable users will actually run.

### Host-Scoped System Setup

`platform/linux/setup-kanto.sh` owns `kanto`'s Ubuntu 24.04 host setup, the only system-level
configuration outside Nix: the `America/Los_Angeles` system timezone, the public inbound firewall
(`kanto-firewall.nft` and its unit), Tailscale, and Docker with `setup-kanto-docker.sh`'s log
rotation and build-cache GC. `setup_linux_system` in `install.sh` runs it on `kanto` when sudo
will not prompt; the script also checks the hostname itself because it is run by hand too.

## Agent Configuration

`agent-skills.txt` is the explicit list of managed user skills and their sources:
remote repositories (edit those skills upstream) and the local skill sources under
`packages/agents/.agents/skills/`. `sync_agent_skills` refreshes all
listed skills during every convergence, including `dotfiles pull`. Removing a
name removes its previously managed installation and Claude/Codex links on the
next successful sync. `~/.agents/.dotfiles-skills.txt` records ownership;
unmanaged skills, built-in skills, and plugin bundles are left alone. Failed
installs fail convergence and do not prune removed skills.

`packages/agents/.agents`, `packages/claude/.claude`, and `packages/codex/.codex` deploy to `~/.agents`, `~/.claude`, and `~/.codex`. Skills are installed into `~/.agents/skills` for Codex and linked into `~/.claude/skills`. `converge` also links `~/.agents/rules/*.md` into `~/.claude/rules` and symlinks `~/.codex/AGENTS.md` to the shared `~/.agents/AGENTS.md`, which Claude imports. Shared instructions explicitly tell agents to read the untracked `~/.agents/AGENTS.local.md` if it exists. The Codex link is force-replaced during convergence, backing up an existing regular file. Do not add root-level `.agents/` or `.claude/` directories in this repository.

`enabledPlugins` in `packages/claude/.claude/settings.json` is the list of Claude Code plugins: `setup_claude_plugins` installs every key and disables the ones set to `false`.

## Tools

For the curated CLI inventory, use `CHEATSHEET.md` or run `oma`. Shell functions live in `packages/shell/.functions` and aliases in `nix/home/features/shell.nix`. Before proposing a tool install or alias, check `packages/mise/.config/mise/config.toml`, `platform/macos/Brewfile`, `platform/linux/packages.txt`, and `nix/home/features/packages.nix`; most modern CLIs are already managed. Honor the omakase curation: cohesion over options.

- Nix home-manager (`nix/home/`) provides the shell and stable CLI tool set; nix-darwin (`nix/darwin/`) handles macOS system settings + GUI casks
- `mise` manages language runtimes and other latest-is-best dev tools (versions pinned in `packages/mise/.config/mise/config.toml`)
- `uv tool` manages Python CLIs that should track PyPI closely
- `brew` for bootstrap binaries (git/vim/zsh) and tooling not yet in Nix on macOS, `apt` on Ubuntu
- Repos live at `~/code/{org}/{repo}` on all machines

### Remote Browser / OAuth (`ssh-opener`)

[ssh-opener](https://github.com/vicyap/ssh-opener) opens URLs on a local machine's browser from headless remotes and sets up reverse SSH tunnels for OAuth callbacks. Installed via `mise run setup:ssh-opener` (downloads to `~/.local/bin/`). Set as `$BROWSER` on headless Linux machines via `.zshrc`. See the ssh-opener README for full setup instructions.

## Shell Conventions

- All scripts use `#!/usr/bin/env bash` with `set -e`
- Guard pattern for optional tools: `command -v tool &>/dev/null && eval "$(tool init zsh)"`
- Conflict prompts via `DOTFILES_INTERACTIVE` env var (`never` by default; `always` or `auto` opt in)
- Force mode via `DOTFILES_FORCE=1` to replace conflicts without prompting (backs up originals first)
