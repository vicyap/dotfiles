# Shared home-manager configuration applied to every host.
{ ... }:
{
  imports = [
    ./features/packages.nix
    ./features/git.nix
    ./features/vim.nix
    ./features/zsh.nix
    ./features/starship.nix
    ./features/atuin.nix
    ./features/fzf.nix
    ./features/bat.nix
    ./features/tmux.nix
    ./features/zoxide.nix
    ./features/direnv.nix
  ];

  # Set once per home; do not bump casually — it gates opt-in behavior changes.
  home.stateVersion = "26.05";

  # Let home-manager manage itself.
  programs.home-manager.enable = true;
}
