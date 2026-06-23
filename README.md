# Dotfiles

Personal dotfiles managed with a simple shell script. No dependencies required.

## Philosophy

Curated, opinionated, chef's-choice defaults — productivity and aesthetics over a gentle learning curve.

1. **Curated > optional.** Every tool, alias, and theme is picked deliberately to compose with the rest. Modern CLI replacements (`rg`, `fd`, `bat`, `eza`, `dust`, `procs`, `sd`) over their classic counterparts. TUIs (`lazygit`, `lazydocker`, `atuin`, `btop`, `fastfetch`) for the workflows that benefit. Catppuccin Mocha + a `light`/`dark` switcher across ghostty, bat, fzf, tmux, and claude. One coherent menu, not a buffet.
2. **Productivity + aesthetics > ease-of-learning.** New keybindings and unfamiliar tools are fine if they pay off long-term. See [`CHEATSHEET.md`](./CHEATSHEET.md) (or `oma` from any shell).

Swap any single piece without abandoning the rest — the modular Linux/macOS ecosystem makes that cheap — but the curation is the value.

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
dotfiles pull     # Pull latest, then converge this machine (fast, repeatable)
dotfiles update   # pull + refresh upstream (flake inputs, Homebrew, mise, plugins)
dotfiles status   # Show git status of the dotfiles repo
dotfiles cd       # cd into the dotfiles repo
dotfiles edit     # Open dotfiles in $EDITOR
```

For a fresh machine, run `./install.sh` (or pipe it from curl).

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

## Remote browser / OAuth

[ssh-opener](https://github.com/vicyap/ssh-opener) opens URLs on a local machine's browser from a headless remote and sets up reverse SSH port forwarding for OAuth callbacks. On headless Linux machines, `.zshrc` sets it as `$BROWSER`.

Installed automatically by `./install.sh` via `mise run setup:ssh-opener`. See the [ssh-opener README](https://github.com/vicyap/ssh-opener) for setup instructions (SSH config, env vars).

## License

MIT
