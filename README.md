# Dotfiles

Personal dotfiles managed with a shell installer and Nix home-manager. Supports macOS and Ubuntu Linux.

## Philosophy

Curated, opinionated, chef's-choice defaults — productivity and aesthetics over a gentle learning curve.

1. **Curated > optional.** Every tool, alias, and theme is picked deliberately to compose with the rest. Modern CLI replacements (`rg`, `fd`, `bat`, `eza`, `dust`, `procs`, `sd`) over their classic counterparts. TUIs (`lazygit`, `lazydocker`, `atuin`, `btop`, `fastfetch`) for the workflows that benefit. Catppuccin Mocha + a `light`/`dark` switcher across ghostty, bat, fzf, tmux, and claude. One coherent menu, not a buffet.
2. **Productivity + aesthetics > ease-of-learning.** New keybindings and unfamiliar tools are fine if they pay off long-term. See [`CHEATSHEET.md`](./CHEATSHEET.md) (or `oma` from any shell).

Swap any single piece without abandoning the rest — the modular Linux/macOS ecosystem makes that cheap — but the curation is the value.

## Install

Fresh Ubuntu machine:

```bash
sudo apt-get update && sudo apt-get install -y ca-certificates curl git zsh && curl -fsSL https://raw.githubusercontent.com/vicyap/dotfiles/main/install.sh | bash
```

Fresh macOS machine:

```bash
xcode-select -p >/dev/null 2>&1 || (xcode-select --install; echo "Install Command Line Tools, then rerun this command."; false) && curl -fsSL https://raw.githubusercontent.com/vicyap/dotfiles/main/install.sh | bash
```

Fresh Linux machine:

Linux support means Ubuntu. On Ubuntu, use the command above. Other Linux
distributions are intentionally unsupported by the installer.

Already-bootstrapped Ubuntu or macOS machine:

```bash
curl -fsSL https://raw.githubusercontent.com/vicyap/dotfiles/main/install.sh | bash
```

The installer defaults to non-interactive conflict handling: existing files are
skipped. Use `DOTFILES_FORCE=1` to back up and replace conflicts:

```bash
curl -fsSL https://raw.githubusercontent.com/vicyap/dotfiles/main/install.sh | DOTFILES_FORCE=1 bash
```

To prompt for conflicts instead, run with `DOTFILES_INTERACTIVE=always`.

Or clone and run locally:

```bash
git clone https://github.com/vicyap/dotfiles.git ~/.dotfiles
~/.dotfiles/install.sh
```

The installer clones to `~/.dotfiles` when run through the curl pipe. It then:

- installs bootstrap tools such as `git`, `curl`, `zsh`, `vim`, and `mise`
- installs Nix and activates Home Manager
- symlinks package files from `packages/`
- installs platform packages from Homebrew or configured apt sources
- installs extra mise-managed tools, agent plugins, and skills

Home Manager activation is generic by OS and architecture. Ubuntu hosts use the
`ubuntu-<nix-system>` flake output, and macOS hosts use nix-darwin when a
host-specific Darwin config exists, otherwise `macos-<nix-system>`.

## Structure

```
~/.dotfiles/
├── install.sh          # Installer (symlinks + Nix)
├── bin/dotfiles        # CLI tool
├── lib/                # Helper scripts
├── nix/                # Nix configs
│   ├── home/           # home-manager: shell, core programs, CLI tool set
│   └── darwin/         # nix-darwin: macOS system settings + casks
├── packages/           # Symlinked dotfiles
│   ├── bash/
│   ├── claude/
│   ├── codex/
│   ├── ghostty/
│   └── shell/
└── platform/           # OS-specific configs
    ├── macos/
    └── linux/
```

## Usage

After installation, use the `dotfiles` CLI:

```bash
dotfiles pull     # Pull latest, then converge this machine (fast, repeatable)
dotfiles update   # pull + refresh upstream (flake inputs, Homebrew, mise, plugins)
dotfiles cd       # cd into the dotfiles repo
```

For a fresh machine, run `./install.sh` after cloning, or pipe it from curl.

## Secrets

API keys and tokens go in `~/.secrets` (not tracked by git):

```bash
# ~/.secrets
export A_SECRET_API_KEY='...'
```

This file is sourced by `.zshrc` and `.bashrc` if it exists.

## Adding new dotfiles

Two mechanisms; pick by who should own the file.

**Symlinked dotfiles** (most app configs):

1. Create a package directory: `mkdir -p packages/myapp`
2. Add your config file with the same path it would have in `$HOME`:
   - `packages/myapp/.myapprc` will be symlinked to `~/.myapprc`
   - `packages/myapp/.config/myapp/config` will be symlinked to `~/.config/myapp/config`
3. Run `dotfiles pull` or `./install.sh` to apply

**Nix home-manager** (the shell, git, tmux, and the CLI tool set): add a package
to `nix/home/features/packages.nix`, or a `programs.<name>` module under
`nix/home/features/`, then `dotfiles pull`. Packages listed in
`NIX_OWNED_PACKAGES` (`lib/symlink.sh`) are deliberately skipped by the symlinker
so the two mechanisms never fight over the same path.

## Remote browser / OAuth

[ssh-opener](https://github.com/vicyap/ssh-opener) opens URLs on a local machine's browser from a headless remote and sets up reverse SSH port forwarding for OAuth callbacks. On headless Linux machines, `.zshrc` sets it as `$BROWSER`.

Installed automatically by `./install.sh` via `mise run setup:ssh-opener`. See the [ssh-opener README](https://github.com/vicyap/ssh-opener) for setup instructions (SSH config, env vars).

## License

MIT
