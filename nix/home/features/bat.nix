# bat — native home-manager module. Ships the two custom Catppuccin tmThemes
# and rebuilds the bat cache at activation so `BAT_THEME="Catppuccin Mocha"`
# (exported by the light/dark switcher) resolves. No static theme is set in
# config; the BAT_THEME env var drives the active theme.
{ ... }:
{
  programs.bat = {
    enable = true;
    themes = {
      "Catppuccin Mocha" = {
        src = ../../../packages/bat/.config/bat/themes;
        file = "Catppuccin Mocha.tmTheme";
      };
      "Catppuccin Latte" = {
        src = ../../../packages/bat/.config/bat/themes;
        file = "Catppuccin Latte.tmTheme";
      };
    };
  };
}
