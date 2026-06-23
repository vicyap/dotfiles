# rhinestone — headless Ubuntu host (x86_64-linux). Identity (username/home) is
# set by the flake wrapper, so this module carries only shared + host config.
{ ... }:
{
  imports = [ ../common.nix ];
}
