{
  description = "A highly awesome system configuration.";

  inputs = {
    nixpkgs.url = github:nixos/nixpkgs/release-20.09;
    utils.url = path:../../;
  };


  outputs = inputs@{ self, nixpkgs, utils }:
    let
      inherit (utils.lib.exporters) internalOverlays fromOverlays modulesFromList;
    in
    utils.lib.systemFlake {
      inherit self inputs;

      channels.nixpkgs.input = nixpkgs;

      sharedOverlays = [
        self.overlay
      ];

      nixosModules = modulesFromList [
        ./hosts/Morty.nix
      ];

      # export overlays automatically for all packages defined in overlaysBuilder of each channel
      overlays = internalOverlays {
        inherit (self) pkgs inputs;
      };

      # construct packagesBuilder to export all packages defined in overlays
      #packagesBuilder = fromOverlays self.overlays;

      overlay = import ./overlays;

    };
}

