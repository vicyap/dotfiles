# direnv — native home-manager module. Replaces the `eval "$(direnv hook zsh)"`
# line in the old .zshrc.
{ ... }:
{
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
  };
}
