# Dotfiles

Personal dotfiles managed with a simple shell script. No dependencies required.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/vicyap/dotfiles/main/install.sh | bash
```

## Structure

```
~/.dotfiles/
├── install.sh          # Bootstrap script
├── bin/dotfiles        # CLI tool
├── lib/                # Helper scripts
├── packages/           # Cross-platform dotfiles
│   ├── git/
│   ├── vim/
│   ├── bash/
│   ├── zsh/
│   ├── shell/
│   └── claude/
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

## Adding new dotfiles

1. Create a package directory: `mkdir -p packages/myapp`
2. Add your config file with the same path it would have in `$HOME`:
   - `packages/myapp/.myapprc` will be symlinked to `~/.myapprc`
   - `packages/myapp/.config/myapp/config` will be symlinked to `~/.config/myapp/config`
3. Run `dotfiles pull` or `./install.sh` to apply

## License

MIT
