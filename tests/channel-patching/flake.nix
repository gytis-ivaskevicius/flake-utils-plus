{
  inputs.utils.url = path:../../;
  inputs.nixpkgs.url = github:NixOS/nixpkgs/3c4a65f323dd;

  outputs = inputs@{ self, nixpkgs, utils }:
    utils.lib.mkFlake {
      inherit self inputs;
      supportedSystems = [ "x86_64-linux" ];




      #################
      ### Test Data ###
      #################

      channelsConfig.allowBroken = true;

      channels.nixpkgs = {
        input = nixpkgs;
        patches = [ ./myNixpkgsPatch.patch ];
        config.allowUnfree = true;
      };

      hosts.PatchedHost.modules = [
        ({ lib, ... }: {
          patchedModule.test = lib.patchedFunction "using patched module via patched function";

          # To keep Nix from complaining
          boot.loader.grub.devices = [ "nodev" ];
          fileSystems."/" = { device = "test"; fsType = "ext4"; };
        })
      ];


      outputsBuilder = channels: {

        packages = {
          # Using patched channel
          inherit (channels.nixpkgs) flake-utils-plus-test;
        };



        ######################
        ### Test execution ###
        ######################

        checks =
          let
            inherit (utils.lib.check-utils channels.nixpkgs) hasKey isEqual;
            hostConfig = self.nixosConfigurations.PatchedHost.config;
          in
          {

            # Patched package gets passed to `packageBuilder`
            patchedPackageGetsPassedToBuilders = isEqual self.packages.x86_64-linux.flake-utils-plus-test.pname "coreutils";

            # Modules (and lib) from patched nixpkgs are used
            patchedModuleAndFunctionWorks = isEqual hostConfig.patchedModule.test "using patched module via patched function";

            # `channelsConfig.*` is used
            globalChannelConfigWorks = hasKey hostConfig.nixpkgs.pkgs.config "allowBroken";

            # `channels.nixpkgs.config.*` is also used
            channelSpecificConfigWorks = hasKey hostConfig.nixpkgs.pkgs.config "allowUnfree";

          };
      };


    };
}




