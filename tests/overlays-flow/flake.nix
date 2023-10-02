{
  inputs.utils.url = path:../../;

  outputs = inputs@{ self, nixpkgs, utils }:
    utils.lib.mkFlake {
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


      ######################
      ### Test execution ###
      ######################

      outputsBuilder = channels: {
        checks =
          let
            inherit (utils.lib.check-utils channels.nixpkgs) hasKey;
            existingPkgsFlow = self.nixosConfigurations.ExistingPkgsFlow.pkgs;
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

