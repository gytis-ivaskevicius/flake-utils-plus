{
  inputs.utils.url = path:../../;

  outputs = inputs@{ self, nixpkgs, utils }:
    let
      testing-utils = import ../testing-utils.nix { inherit (self.pkgs.x86_64-linux) nixpkgs; };
      inherit (testing-utils) hasKey;
    in
    utils.lib.systemFlake {
      inherit self inputs;
      supportedSystems = [ "x86_64-linux" ];
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
      hostDefaults.modules = [
        {
          nixpkgs.overlays = [
            (final: prev: { fromHostConfig = prev.hello; })
          ];

          # To keep Nix from complaining
          boot.loader.grub.devices = [ "nodev" ];
          fileSystems."/" = { device = "test"; fsType = "ext4"; };
        }
      ];

      hosts.ExistingPkgsFlow = { };

      hosts.ReimportFlow.modules = [
        {
          # Custom configuration from modules causes reimport of nixpkgs
          nixpkgs.config.allowUnfree = true;
        }
      ];



      ######################
      ### Test execution ###
      ######################

      outputsBuilder = channels: {
        checks =
          let
            existingPkgsFlow = self.nixosConfigurations.ExistingPkgsFlow.pkgs;
            reimportFlow = self.nixosConfigurations.ReimportFlow.pkgs;
          in
          {

            # ExistingPkgsFlow
            sharedOverlays_Applied_1 = hasKey existingPkgsFlow "fromSharedOverlays";

            channelSpecific_Applied_1 = hasKey existingPkgsFlow "fromChannelSpecific";

            hostConfig_Applied_1 = hasKey existingPkgsFlow "fromHostConfig";

            contains_srcs_1 = hasKey existingPkgsFlow "srcs";


            # ReimportFlow
            sharedOverlays_Applied_2 = hasKey reimportFlow "fromSharedOverlays";

            channelSpecific_Applied_2 = hasKey reimportFlow "fromChannelSpecific";

            hostConfig_Applied_2 = hasKey reimportFlow "fromHostConfig";

            contains_srcs_2 = hasKey reimportFlow "srcs";

          };
      };

    };
}




