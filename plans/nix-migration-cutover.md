# Nix migration — live cutover runbook

How the shell slice (zsh, starship, atuin, fzf, bat, tmux + the slice-1 git/vim)
lands on an already-running machine. Validated in `vms/nixtest`.

## The short version

On a Nix-managed host (currently just `rhinestone`), running `dotfiles sync`
(i.e. `install.sh`) does the whole cutover:

1. `setup_home_manager` installs Nix if missing, removes the few legacy symlinks
   home-manager relocates (`cleanup_relocated_nix_symlinks`), then runs
   `home-manager switch -b backup`.
2. `-b backup` takes over every path home-manager manages: it replaces stale
   symlinks in place and moves any real file/dir that is in the way to
   `<path>.backup` (verified for `~/.zshrc`, `~/.config/*`, the bat themes, the
   tmux theme files, and a real `~/.zsh/plugins/fzf-tab` git clone).
3. `symlink_all_packages` then links the remaining non-Nix packages, skipping
   `NIX_OWNED_PACKAGES=(git vim zsh starship atuin bat tmux)`.

## What `cleanup_relocated_nix_symlinks` removes (and why)

home-manager writes git config to `~/.config/git/config` and tmux config to
`~/.config/tmux/tmux.conf`, but git and tmux *also* read the legacy paths. Left
in place, the old bash-symlinker links there would shadow the new config
(`~/.gitconfig`) or re-trigger TPM (`~/.tmux.conf` → `~/.tmux.conf.local` →
`run '~/.tmux/plugins/tpm/tpm'`), racing the Nix-managed resurrect/continuum.

The cleanup only removes `~/.gitconfig`, `~/.tmux.conf`, `~/.tmux.conf.local`
**when they are symlinks pointing into `~/.dotfiles`** — never a real user file.

## Optional manual tidy-up (safe to skip; nothing breaks if you don't)

These are orphans the migration leaves behind — harmless, just noise:

```bash
# Old git-cloned zsh/tmux plugins, no longer sourced (Nix owns them now):
rm -rf ~/.zsh/plugins/zsh-autosuggestions \
       ~/.zsh/plugins/fast-syntax-highlighting \
       ~/.zsh/plugins/fzf-tab.backup \
       ~/.tmux/plugins/tpm

# Any *.backup files home-manager created on the first switch:
ls -d ~/*.backup ~/.config/**/*.backup 2>/dev/null
```

## tmux: the running server

`programs.tmux` installs tmux 3.6a into the Nix profile; apt's tmux stays for
bootstrap. The **already-running** server keeps using whatever binary it started
with — it is never killed by the switch. New `tmux` invocations pick up the Nix
binary via PATH. To move the live server onto the new config without restarting:

```bash
tmux source ~/.config/tmux/tmux.conf
```

Restart the server (at a convenient time) only if you want it on the Nix tmux
binary. The socket stays at the default `/tmp/tmux-$UID` — `secureSocket = false`
keeps home-manager from moving it to `$XDG_RUNTIME_DIR`, which would not survive
logout.

## Verifying after cutover

```bash
exec zsh                              # or open a new pane
command -v fd bat eza starship atuin  # all should be ~/.nix-profile/bin/*
bindkey '^R'                          # -> atuin-search
bindkey '^I'                          # -> fzf-tab-complete
echo $BAT_THEME                       # -> Catppuccin Mocha (or GitHub in light)
dark; light                           # theme switch still works
```
