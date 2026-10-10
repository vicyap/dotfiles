# lazygit — package plus config as writable out-of-store symlinks into the
# repo (vim.nix pattern). programs.lazygit is deliberately NOT used: the
# module hard-wires ~/.config/lazygit/config.yml to its `settings` attrset
# (defining enable = false and a store-generated source even when settings is
# empty), which conflicts with external management of that path. The
# light/dark switcher copies themes/<mode>.yml over ~/.config/lazygit/theme.yml
# at runtime (see packages/zsh/.zsh/theme.zsh), so ~/.config/lazygit must stay
# writable and the repo files the edited source of truth.
{ config, pkgs, ... }:
let
  lazygitDir = "${config.home.homeDirectory}/.dotfiles/packages/lazygit/.config/lazygit";
in
{
  home.packages = [ pkgs.lazygit ];

  # lazygit reads ~/.config/lazygit on macOS too here: theme.zsh points
  # LG_CONFIG_FILE at these paths explicitly on both OSes.
  xdg.configFile."lazygit/config.yml".source =
    config.lib.file.mkOutOfStoreSymlink "${lazygitDir}/config.yml";
  xdg.configFile."lazygit/themes/dark.yml".source =
    config.lib.file.mkOutOfStoreSymlink "${lazygitDir}/themes/dark.yml";
  xdg.configFile."lazygit/themes/light.yml".source =
    config.lib.file.mkOutOfStoreSymlink "${lazygitDir}/themes/light.yml";
}
