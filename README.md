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
dotfiles pull     # Pull latest changes and re-symlink
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
3. Run `dotfiles pull` or `./install.sh` to apply

## License

MIT
