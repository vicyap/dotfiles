# zoxide — native home-manager module (smarter cd). Replaces the
# `eval "$(zoxide init zsh)"` hook in the old .zshrc.
{ ... }:
{
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };
}
