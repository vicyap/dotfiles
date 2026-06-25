# lima — macOS host (aarch64-darwin), Victor's MacBook Pro. Identity is set by
# the flake wrapper (standalone home-manager) or by nix-darwin (system
# activation), so this module carries only shared + host home config.
#
# macOS-only home config that must NOT leak to headless rhinestone lives here
# (the shared feature modules stay host-agnostic).
{ lib, ... }:
{
  imports = [ ../common.nix ];

  # codex is a macOS-only Homebrew cask; the alias would dangle on Linux.
  programs.zsh.shellAliases.cx = "codex";

  # Homebrew shellenv (login shell). profileExtra is a `lines` option, so this
  # concatenates after the shared MOTD block in nix/home/features/zsh.nix.
  programs.zsh.profileExtra = ''
    # Homebrew (macOS)
    if [[ -f /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f /usr/local/bin/brew ]]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  '';

  # pbcopy clipboard integration (macOS only; pbcopy does not exist on Linux).
  # mkAfter so it lands after the shared extraConfig in nix/home/features/tmux.nix.
  programs.tmux.extraConfig = lib.mkAfter ''
    # macOS clipboard: route copy-mode and prefix-y through pbcopy.
    set -s copy-command 'pbcopy'
    bind y run-shell -b "tmux save-buffer - | pbcopy"
  '';
}
