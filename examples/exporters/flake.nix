{
  description = "A highly awesome system configuration.";

  inputs = {
    nixpkgs.url = github:nixos/nixpkgs/release-20.09;
    utils.url = path:../../;
  };


  outputs = inputs@{ self, nixpkgs, utils }:
    utils.lib.systemFlake {
      inherit self inputs;

      channels.nixpkgs.input = nixpkgs;

      sharedOverlays = [
        self.overlay
      ];


      # export overlays automatically for all packages defined in overlaysBuilder of each channel
      overlays = utils.lib.exporter.overlaysFromChannelsExporter {
        inherit (self) pkgs inputs;
      };

      # TODO: Broken
      # construct packagesBuilder to export all packages defined in overlays
      #packagesBuilder = utils.lib.builder.packagesFromOverlaysBuilderConstructor self.overlays;

      overlay = import ./overlays;

    };
}

