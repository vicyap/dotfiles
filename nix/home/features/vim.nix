# vim — writable out-of-store symlink to the file in the dotfiles repo, so the
# repo stays the source of truth and edits are live without a rebuild.
{ config, ... }:
{
  home.file.".vimrc".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.dotfiles/packages/vim/.vimrc";
}
