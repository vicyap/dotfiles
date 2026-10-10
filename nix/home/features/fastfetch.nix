# fastfetch — package via the home-manager module; config.jsonc stays a
# writable out-of-store symlink into the repo (vim.nix pattern) because
# programs.fastfetch.settings emits plain JSON and would drop the jsonc
# comments.
{ config, ... }:
{
  programs.fastfetch.enable = true;

  xdg.configFile."fastfetch/config.jsonc".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/.dotfiles/packages/fastfetch/.config/fastfetch/config.jsonc";
}
