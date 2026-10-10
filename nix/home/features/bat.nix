# bat — native home-manager module. Ships the custom Catppuccin Mocha tmTheme
# and rebuilds the bat cache at activation so `BAT_THEME="Catppuccin Mocha"`
# (exported by the light/dark switcher) resolves. No static theme is set in
# config; the BAT_THEME env var drives the active theme. Light mode uses bat's
# built-in "GitHub" theme (see packages/zsh/.zsh/theme.zsh), so no Latte theme
# is registered here.
{ ... }:
{
  programs.bat = {
    enable = true;
    themes = {
      "Catppuccin Mocha" = {
        src = ../../../packages/bat/.config/bat/themes;
        file = "Catppuccin Mocha.tmTheme";
      };
    };
  };
}
