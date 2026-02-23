# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## IMPORTANT: This Is a Public Repository

NEVER commit API keys, tokens, passwords, private keys, personal emails, or any other secrets. All sensitive values belong in `~/.secrets` (which is git-ignored). When adding new config files, always check that they contain no credentials or private data before committing.

## What This Repo Is

Personal dotfiles repo. Shell scripts that symlink config files from `packages/` into `$HOME`. No build system, no tests, no linting. Supports macOS and Linux.

## Key Commands

```bash
./install.sh              # Full bootstrap: install zsh, mise, symlink everything, install tools
dotfiles pull             # Pull latest + re-run install.sh
dotfiles status           # Git status of this repo
```

Platform packages are installed separately:
```bash
brew bundle --file=platform/macos/Brewfile   # macOS
xargs -a platform/linux/packages.txt sudo apt install -y  # Linux
```

## Architecture

### Symlink Convention

Files under `packages/<name>/` mirror `$HOME` structure and get symlinked there:
- `packages/zsh/.zshrc` -> `~/.zshrc`
- `packages/claude/.claude/settings.json` -> `~/.claude/settings.json`

The `lib/symlink.sh` module handles this. It backs up existing files to `~/.dotfiles-backup/<timestamp>/` before replacing. In non-interactive mode, it skips conflicts rather than overwriting.

### Adding a New Package

Create a directory under `packages/` with files mirroring their `$HOME` paths. No registration needed -- `symlink_all_packages` iterates all `packages/*/` directories automatically.

### Secrets Pattern

Sensitive data lives in `~/.secrets` (never committed). Both `.zshrc` and `.bashrc` source it if present. The `.gitignore` broadly excludes `*secret*`, `*token*`, `.env*`, credentials, and SSH keys.

### lib/ Modules

- `platform.sh` -- OS detection (`detect_os`), command existence check (`has_cmd`), installers for zsh and mise
- `symlink.sh` -- Symlink creation with backup, interactive prompting, conflict resolution

### Tool Management

`mise` manages language runtimes (Go, Node, Python, Bun, Erlang, Elixir). Versions are pinned in `packages/mise/.config/mise/config.toml`. The mise config also defines setup tasks (`setup:web`, `setup:ask`) for building CLI tools from source.

## Tools

- `mise` manages language runtimes (versions pinned in `packages/mise/.config/mise/config.toml`)
- `brew` for system packages on macOS, `apt` on Linux
- Repos live at `~/code/{org}/{repo}` on all machines

## Shell Conventions

- All scripts use `#!/usr/bin/env bash` with `set -e`
- Guard pattern for optional tools: `command -v tool &>/dev/null && eval "$(tool init zsh)"`
- Interactive detection via `[[ -t 0 ]]` or `DOTFILES_INTERACTIVE` env var (auto/always/never)
