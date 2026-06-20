# atuin — native home-manager module. Settings come from the repo TOML
# (declarative, re-serialized by home-manager). The daemon is left to atuin's
# own `autostart` (in the TOML) rather than a systemd user service, so it keeps
# working on the headless host without lingering. atuin owns Ctrl+R;
# --disable-up-arrow keeps prefix history-search on the UP key.
{ ... }:
{
  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
    flags = [ "--disable-up-arrow" ];
    settings = builtins.fromTOML (
      builtins.readFile ../../../packages/atuin/.config/atuin/config.toml
    );
  };
}
