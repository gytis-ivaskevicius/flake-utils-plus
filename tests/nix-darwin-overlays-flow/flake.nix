{
  inputs.utils.url = path:../../;
  inputs.nix-darwin.url = github:nix-darwin/nix-darwin;
  inputs.nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

  outputs = inputs@{ self, nixpkgs, utils, nix-darwin }:
    utils.lib.mkFlake {
      inherit self inputs;
      supportedSystems = [ "aarch64-darwin" ];
      channels.nixpkgs.input = nixpkgs;



      #################
      ### Test Data ###
      #################

      # Applied to all Channels
      sharedOverlays = [
        (final: prev: {
          fromSharedOverlays = prev.hello;
        })
      ];

      # Applied only to `nixpkgs` channel
      channels.nixpkgs.overlaysBuilder = channels: [
        (final: prev: {
          fromChannelSpecific = prev.hello;
        })
      ];


      # Hosts
      hostDefaults = {
        system = "aarch64-darwin";
        output = "darwinConfigurations";
        builder = nix-darwin.lib.darwinSystem;
        modules = [
          ({ inputs, ... }: {
            system = {
              stateVersion = 5;
              configurationRevision = (inputs.nix-darwin.rev or inputs.nix-darwin.dirtyRev or null);
            };
          })
          {
            nixpkgs.overlays = [
              (final: prev: { fromHostConfig = prev.hello; })
            ];
          }
        ];
      };

      hosts.ExistingPkgsFlow = { };


      ######################
      ### Test execution ###
      ######################

      outputsBuilder = channels: {
        checks =
          let
            inherit (utils.lib.check-utils channels.nixpkgs) hasKey;
            existingPkgsFlow = self.darwinConfigurations.ExistingPkgsFlow.pkgs;
          in
          {

            # ExistingPkgsFlow
            sharedOverlays_Applied_1 = hasKey existingPkgsFlow "fromSharedOverlays";

            channelSpecific_Applied_1 = hasKey existingPkgsFlow "fromChannelSpecific";

            hostConfig_Applied_1 = hasKey existingPkgsFlow "fromHostConfig";

            contains_srcs_1 = hasKey existingPkgsFlow "srcs";

          };
      };

    };
}

