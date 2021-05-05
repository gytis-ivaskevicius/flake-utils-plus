{
  inputs.utils.url = path:../../;

  outputs = inputs@{ self, nixpkgs, utils }:
    utils.lib.systemFlake {
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
          nixpkgs.config.packageOverrides = pkgs: { };

          # To keep Nix from complaining
          boot.loader.grub.devices = [ "nodev" ];
          fileSystems."/" = { device = "test"; fsType = "ext4"; };
        })
      ];

      # Using patched channel in builder
      packagesBuilder = channels: {
        inherit (channels.nixpkgs) flake-utils-plus-test;
      };





      ######################
      ### Test execution ###
      ######################

      checksBuilder = channels:
        let
          hostConfig = self.nixosConfigurations.PatchedHost.config;
          isTrue = cond:
            if cond
            then channels.nixpkgs.runCommandNoCC "success" { } "echo success > $out"
            else channels.nixpkgs.runCommandNoCC "failure" { } "exit 1";
        in
        {

          # Patched package gets passed to `packageBuilder`
          patchedPackageGetsPassedToBuilders = isTrue (self.packages.x86_64-linux.flake-utils-plus-test.pname == "hello");

          # Modules (and lib) from patched nixpkgs are used
          patchedModuleAndFunctionWorks = isTrue (hostConfig.patchedModule.test == "using patched module via patched function");

          # `channelsConfig.*` is used
          globalChannelConfigWorks = isTrue (hostConfig.nixpkgs.pkgs.config ? allowBroken);

          # `channels.nixpkgs.config.*` is also used
          channelSpecificConfigWorks = isTrue (hostConfig.nixpkgs.pkgs.config ? allowUnfree);

          # `options.nixpkgs.config.*` is also used
          modulesNixpkgsConfigWorks = isTrue (hostConfig.nixpkgs.pkgs.config ? packageOverrides);

        };


    };
}




