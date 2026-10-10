# direnv — native home-manager module. Replaces the `eval "$(direnv hook zsh)"`
# line in the old .zshrc.
{ ... }:
{
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    # Hash-based caching for `use flake` / `use nix` .envrcs — without it the
    # devShell is re-evaluated on every cd into the project.
    nix-direnv.enable = true;
  };
}
