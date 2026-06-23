{
  description = "Victor's dotfiles managed with Nix + home-manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      nix-darwin,
      ...
    }:
    let
      # Standalone home-manager (Linux hosts; also a build-only target on macOS).
      # Identity lives here, not in the host module, so the same host module can
      # be reused inside nix-darwin (where home-manager sets identity itself).
      mkHome =
        {
          system,
          module,
          username,
          homeDirectory,
        }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          modules = [
            module
            {
              home.username = username;
              home.homeDirectory = homeDirectory;
            }
          ];
        };

      # macOS system via nix-darwin, with home-manager wired in as a module so a
      # single `darwin-rebuild switch` activates both the system layer and the
      # user's home config — reusing the same host module as the standalone
      # homeConfigurations entry above.
      mkDarwin =
        {
          system,
          hostModule,
          username,
          homeModule,
        }:
        nix-darwin.lib.darwinSystem {
          inherit system;
          modules = [
            hostModule
            home-manager.darwinModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              # Back up (rather than fail on) any non-symlink file in the way on
              # first activation; setup_nix removes the legacy repo symlinks.
              home-manager.backupFileExtension = "backup";
              home-manager.users.${username} = import homeModule;
            }
          ];
        };
    in
    {
      homeConfigurations = {
        # Headless Ubuntu host. Apply with:
        #   home-manager switch --flake .#victor@rhinestone
        "victor@rhinestone" = mkHome {
          system = "x86_64-linux";
          module = ./nix/home/hosts/rhinestone.nix;
          username = "victor";
          homeDirectory = "/home/victor";
        };

        # macOS host (Apple Silicon) — standalone target kept for build-only
        # checks. The lima cutover activates via darwinConfigurations below
        # (which embeds this same home module).
        "victoryap@lima" = mkHome {
          system = "aarch64-darwin";
          module = ./nix/home/hosts/lima.nix;
          username = "victoryap";
          homeDirectory = "/Users/victoryap";
        };
      };

      # macOS system config. Apply with:
      #   darwin-rebuild switch --flake .#lima
      darwinConfigurations.lima = mkDarwin {
        system = "aarch64-darwin";
        hostModule = ./nix/darwin/lima.nix;
        username = "victoryap";
        homeModule = ./nix/home/hosts/lima.nix;
      };
    };
}
