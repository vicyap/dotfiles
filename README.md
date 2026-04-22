# Dotfiles

Personal dotfiles managed with a simple shell script. No dependencies required.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/vicyap/dotfiles/main/install.sh | bash
```

In non-interactive environments (e.g. piped via curl), existing files are skipped by default. Use `DOTFILES_FORCE=1` to back up and replace all conflicts:

```bash
curl -fsSL https://raw.githubusercontent.com/vicyap/dotfiles/main/install.sh | DOTFILES_FORCE=1 bash
```

Or clone and run locally:

```bash
git clone https://github.com/vicyap/dotfiles.git ~/.dotfiles
~/.dotfiles/install.sh
```

On a fresh Linux machine, use the bootstrap command after cloning. It installs
missing bootstrap packages such as `git`, `curl`, and `zsh`, then runs the
installer:

```bash
~/.dotfiles/bin/dotfiles bootstrap
```

## Structure

```
~/.dotfiles/
├── install.sh          # Bootstrap script
├── bin/dotfiles        # CLI tool
├── lib/                # Helper scripts
├── packages/           # Cross-platform dotfiles
│   ├── bash/
│   ├── claude/
│   ├── git/
│   ├── shell/
│   ├── starship/
│   ├── vim/
│   └── zsh/
└── platform/           # OS-specific configs
    ├── macos/
    └── linux/
```

## Usage

After installation, use the `dotfiles` CLI:

```bash
dotfiles sync     # Pull latest changes and re-symlink
dotfiles bootstrap # Install bootstrap packages, then run install.sh
dotfiles status   # Show git status of dotfiles repo
dotfiles edit     # Open dotfiles in $EDITOR
```

## Secrets

API keys and tokens go in `~/.secrets` (not tracked by git):

```bash
# ~/.secrets
export A_SECRET_API_KEY='...'
```

This file is sourced by `.zshrc` and `.bashrc` if it exists.

## Adding new dotfiles

1. Create a package directory: `mkdir -p packages/myapp`
2. Add your config file with the same path it would have in `$HOME`:
   - `packages/myapp/.myapprc` will be symlinked to `~/.myapprc`
   - `packages/myapp/.config/myapp/config` will be symlinked to `~/.config/myapp/config`
3. Run `dotfiles sync` or `./install.sh` to apply

## Remote browser / OAuth

[ssh-opener](https://github.com/vicyap/ssh-opener) opens URLs on a local machine's browser from a headless remote and sets up reverse SSH port forwarding for OAuth callbacks. On headless Linux machines, `.zshrc` sets it as `$BROWSER`.

Installed automatically by `./install.sh` via `mise run setup:ssh-opener`. See the [ssh-opener README](https://github.com/vicyap/ssh-opener) for setup instructions (SSH config, env vars).

## License

MIT
