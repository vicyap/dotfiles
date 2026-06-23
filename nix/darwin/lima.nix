# lima — Victor's MacBook Pro (aarch64-darwin). The system layer: macOS
# defaults, Homebrew-managed GUI casks, and the primary user. home-manager
# (wired in flake.nix) layers the dotfiles home config on top, so a single
# `darwin-rebuild switch --flake .#lima` activates everything.
{ ... }:
{
  imports = [ ./common.nix ];

  networking.hostName = "lima";
  networking.computerName = "lima";

  # Required for user-scoped defaults and the home-manager integration.
  system.primaryUser = "victoryap";

  # nix-darwin's home-manager integration derives home.homeDirectory from here
  # (home.username comes from the home-manager.users.<name> attribute).
  users.users.victoryap.home = "/Users/victoryap";

  # GUI apps / fonts with no good nixpkgs equivalent on macOS. CLI tools come
  # from home-manager (nixpkgs), so only casks live here.
  homebrew = {
    enable = true;
    onActivation = {
      cleanup = "none"; # never uninstall anything not listed here
      autoUpdate = false;
      upgrade = false;
    };
    casks = [
      "codex"
      "lm-studio"
      "secretive"
      "font-jetbrains-mono-nerd-font"
    ];
  };

  # macOS defaults: a conservative, developer-friendly starting set — tune
  # freely. Appearance is intentionally left unmanaged (the light/dark switcher
  # owns it).
  system.defaults = {
    dock = {
      autohide = true;
      show-recents = false;
      mru-spaces = false;
    };
    finder = {
      AppleShowAllExtensions = true;
      FXPreferredViewStyle = "Nlsv"; # list view
      ShowPathbar = true;
    };
    NSGlobalDomain = {
      AppleShowAllExtensions = true;
      ApplePressAndHoldEnabled = false; # key repeat instead of the accent menu
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
    };
    trackpad.Clicking = true;
  };
}
