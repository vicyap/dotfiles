# lima — macOS host (aarch64-darwin), Victor's MacBook Pro. Identity is set by
# the flake wrapper (standalone home-manager) or by nix-darwin (system
# activation), so this module carries only shared + host home config.
{ ... }:
{
  imports = [ ../common.nix ];
}
