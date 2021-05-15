{
  description = "A highly awesome system configuration.";

  inputs = {
    nixpkgs.url = github:nixos/nixpkgs/release-20.09;
    unstable.url = github:nixos/nixpkgs/nixos-unstable;
    utils.url = path:../../;
  };


  outputs = inputs@{ self, nixpkgs, unstable, utils, home-manager }:
    utils.lib.systemFlake {
      inherit self inputs;

      # Channel definitions.
      channels.unstable.input = unstable;
      channels.nixpkgs.input = nixpkgs;
      channelsConfig.allowUnfree = true;


      # Modules shared between all hosts
      hostDefaults.modules = [
        ./modules/sharedConfigurationBetweenHosts.nix
        utils.nixosModules.saneFlakeDefaults
      ];


      #############
      ### Hosts ###
      #############

      # Machine using default channel (nixpkgs)
      hosts.Hostname1.modules = [
        ./hosts/Hostname1.nix
      ];


      # Machine using `unstable` channel
      hosts.Hostname2 = {
        channelName = "unstable";

        modules = [
          ./hosts/Hostname2.nix
        ];
      };

    };
}

