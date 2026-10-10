# fzf — native home-manager module. Provides the binary + zsh integration
# (Ctrl-T file widget, Alt-C cd widget, and the default Ctrl-R binding, which
# zsh.nix re-points to atuin). FZF_DEFAULT_OPTS is intentionally NOT set here:
# the light/dark switcher owns it (theme.zsh exports --color=light|dark).
{ ... }:
{
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };
}
