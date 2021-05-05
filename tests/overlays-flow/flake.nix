{
  inputs.utils.url = path:../../;

  outputs = inputs@{ self, nixpkgs, utils }:
    let
      mkApp = utils.lib.mkApp;

      packagePname = drvKey: self.packages.x86_64-linux.${drvKey}.pname;

      appHasSuffix = drvKey: suffix: nixpkgs.lib.hasSuffix suffix self.apps.x86_64-linux.${drvKey}.program;

      defaultAppHasSuffix = suffix: nixpkgs.lib.hasSuffix suffix self.defaultApp.x86_64-linux.program;

      pnameFromOutput = output: self.${output}.x86_64-linux.pname;
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

      # Host
      hosts.OverlaysTest.modules = [
        ({ lib, ... }: {
          nixpkgs.config.overlays = final: prev: {
            fromHostConfig = prev.hello;
          };

          # To keep Nix from complaining
          boot.loader.grub.devices = [ "nodev" ];
          fileSystems."/" = { device = "test"; fsType = "ext4"; };
        })
      ];



      ######################
      ### Test execution ###
      ######################

      checksBuilder = channels:
        let
          hostPkgs = self.nixosConfigurations.OverlaysTest.pkgs;
          isTrue = cond:
            if cond
            then channels.nixpkgs.runCommandNoCC "success" { } "echo success > $out"
            else channels.nixpkgs.runCommandNoCC "failure" { } "exit 1";
        in
        {

          fromSharedOverlaysApplied = isTrue (hostPkgs ? fromSharedOverlays);

          fromChannelSpecificApplied = isTrue (hostPkgs ? fromChannelSpecific);

          # TODO: Fix this one. Probably false positive
          #fromHostConfigApplied = isTrue (hostPkgs ? fromHostConfig);

        };

    };
}




