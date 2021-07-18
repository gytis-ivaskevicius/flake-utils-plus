{
  description = "FUP exporters demo";

  inputs = {
    nixpkgs.url = github:nixos/nixpkgs/release-21.05;
    unstable.url = github:nixos/nixpkgs/nixos-unstable-small;
    utils.url = path:../../;
  };


  outputs = inputs@{ self, nixpkgs, utils, ... }:
    let
      inherit (utils.lib.exporters) internalOverlays fromOverlays modulesFromList;
    in
    utils.lib.systemFlake {
      inherit self inputs;

      # Channel specific overlays. Overlays `coreutils` from `unstable` channel.
      channels.nixpkgs.overlaysBuilder = channels: [
        (final: prev: { inherit (channels.unstable) ranger; })
      ];

      # Propagates to channels.<name>.overlaysBuilder
      sharedOverlays = [
        self.overlay
      ];

      hosts.Morty.modules = with self.nixosModules; [
        Morty
      ];

      nixosModules = modulesFromList [
        ./hosts/Morty.nix
      ];

      # export overlays automatically for all packages defined in overlaysBuilder of each channel
      overlays = internalOverlays {
        inherit (self) pkgs inputs;
      };

      outputsBuilder = channels: {
        # construct packagesBuilder to export all packages defined in overlays
        packages = fromOverlays self.overlays channels;
      };

      overlay = import ./overlays;

    };
}
