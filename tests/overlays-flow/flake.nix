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

      checksBuilder = channels:
        let
          existingPkgsFlow = self.nixosConfigurations.ExistingPkgsFlow.pkgs;
          reimportFlow = self.nixosConfigurations.ReimportFlow.pkgs;
        in
        {

          # ExistingPkgsFlow
          fromSharedOverlaysApplied_1 = hasKey existingPkgsFlow "fromSharedOverlays";

          fromChannelSpecificApplied_1 = hasKey existingPkgsFlow "fromChannelSpecific";

          fromHostConfigApplied_1 = hasKey existingPkgsFlow "fromHostConfig";


          # ReimportFlow
          fromSharedOverlaysApplied_2 = hasKey reimportFlow "fromSharedOverlays";

          fromChannelSpecificApplied_2 = hasKey reimportFlow "fromChannelSpecific";

          fromHostConfigApplied_2 = hasKey reimportFlow "fromHostConfig";

        };

    };
}




