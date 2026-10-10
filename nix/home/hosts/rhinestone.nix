# rhinestone — headless Ubuntu host (x86_64-linux). Identity (username/home) is
# set by the flake wrapper, so this module carries only shared + host config.
{ ... }:
{
  imports = [ ../common.nix ];

  # Expire home-manager generations after 30 days and GC the store weekly
  # (systemd user timer; linger is on, so it fires without an SSH session).
  # Nothing bounded generations before this, and / sat at 85% used with 3911
  # dead store paths. Linux-scoped: lima needs a launchd-compatible answer,
  # tracked in the audit plan.
  services.home-manager.autoExpire = {
    enable = true;
    timestamp = "-30 days";
    frequency = "weekly";
    store.cleanup = true;
    store.options = "--delete-older-than 30d";
  };
}
