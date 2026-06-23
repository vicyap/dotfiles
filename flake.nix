{
  description = "Victor's dotfiles managed with Nix + home-manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, home-manager, ... }:
    let
      mkHome =
        { system, module }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          modules = [ module ];
        };
    in
    {
      homeConfigurations = {
        # Headless Ubuntu host. Apply with:
        #   home-manager switch --flake .#victor@rhinestone
        "victor@rhinestone" = mkHome {
          system = "x86_64-linux";
          module = ./nix/home/hosts/rhinestone.nix;
        };

        # macOS host (Apple Silicon). Apply with:
        #   home-manager switch --flake .#victoryap@lima
        "victoryap@lima" = mkHome {
          system = "aarch64-darwin";
          module = ./nix/home/hosts/lima.nix;
        };
      };
    };
}
