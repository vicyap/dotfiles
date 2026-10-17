# atuin — native home-manager module. Settings come from the repo TOML
# (declarative, re-serialized by home-manager). The daemon is left to atuin's
# own `autostart` (in the TOML) rather than a systemd user service, so it keeps
# working on the headless host without lingering. atuin owns Ctrl+R;
# --disable-up-arrow keeps prefix history-search on the UP key.
#
# The package is pinned to nixpkgs-unstable: 26.05 ships atuin 18.15.2, whose
# embedded `atuin ai` migration set stops at `20260413000000`. Once any newer
# atuin (mise's 18.16.x did) applies `20260417000000` to ~/.local/share/atuin/
# ai_sessions.db, 18.15.2 refuses to open it ("migration … previously applied
# but missing in the resolved migrations"). Tracking unstable keeps the binary
# ahead of the DB. Drop this override once 26.05 backports atuin >= 18.16.0.
{ pkgs, nixpkgs-unstable, ... }:
let
  # legacyPackages mirrors flake.nix's own `nixpkgs.legacyPackages.<system>`
  # pattern — reuses the input's evaluation instead of re-importing nixpkgs.
  unstable = nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  programs.atuin = {
    enable = true;
    package = if pkgs.stdenv.hostPlatform.isDarwin then
      unstable.atuin.overrideAttrs (old: {
        # Backport https://github.com/NixOS/nixpkgs/pull/574509 until the input includes it.
        env = (old.env or { }) // {
          ATUIN_E2E_BASH = unstable.lib.getExe (
            unstable.writeShellScriptBin "bash" ''
              NOSYSBASHRC=1 exec ${unstable.lib.getExe unstable.bashInteractive} "$@"
            ''
          );
        };
      })
    else unstable.atuin;
    enableZshIntegration = true;
    flags = [ "--disable-up-arrow" ];
    settings = builtins.fromTOML (
      builtins.readFile ../../../packages/atuin/.config/atuin/config.toml
    );
  };
}
