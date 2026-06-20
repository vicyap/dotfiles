# rhinestone — headless Ubuntu host (x86_64-linux).
{ ... }:
{
  imports = [ ../common.nix ];

  home.username = "victor";
  home.homeDirectory = "/home/victor";
}
