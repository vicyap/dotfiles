# Shared nix-darwin system configuration for macOS hosts.
{ ... }:
{
  # Nix is installed and its daemon managed by the upstream (NixOS community)
  # installer, which already enabled flakes in /etc/nix. Let nix-darwin leave
  # Nix alone so the two don't fight over the daemon or nix.conf.
  nix.enable = false;

  # Make /etc/zshrc source the Nix + nix-darwin environment for login shells.
  # The interactive zsh config itself is provided by home-manager.
  programs.zsh.enable = true;

  # Pin the release this config tracks; gates opt-in default changes.
  system.stateVersion = 6;
}
