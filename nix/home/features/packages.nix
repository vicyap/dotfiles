# Global CLI tools, shared across hosts. Nix owns these; mise is narrowed to
# language runtimes. Comments note the binary name where it differs from the
# nixpkgs attribute.
#
# Tools with a dedicated home-manager module are NOT listed here — their
# `programs.<name>.enable` installs the package: bat, delta, fzf, starship,
# atuin, zoxide, direnv, tmux, git. gh is kept below because git's credential
# helper references it; vim's binary stays apt/brew-managed (only ~/.vimrc is
# Nix-owned).
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # modern CLI replacements
    ripgrep
    fd
    eza
    dust
    procs
    sd
    duf

    # search / nav / data
    jq
    yq-go # yq
    jless
    tree

    # system / process
    htop
    btop

    # network
    gping
    mosh
    # NOTE: `dog` (dogdns) was removed from nixpkgs 26.05 (unmaintained upstream);
    # it stays mise-managed via aqua:ogham/dog. Revisit `doggo` if desired.

    # git / dev tooling
    gh
    lazygit
    lazydocker
    just
    entr

    # prompt / shell / history / fetch
    fastfetch

    # misc
    glow
    tealdeer # tldr
    chafa
    cloc
  ];
}
