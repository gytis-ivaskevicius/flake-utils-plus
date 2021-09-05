{
  description = "A highly awesome system configuration.";

  inputs = {
    nixpkgs.url = github:nixos/nixpkgs/release-21.05;
    unstable.url = github:nixos/nixpkgs/nixos-unstable;
    utils.url = path:../../;
  };


  outputs = inputs@{ self, nixpkgs, unstable, utils }:
    utils.lib.systemFlake {
      inherit self inputs;

      # Channel definitions.
      # Channels are automatically generated from nixpkgs inputs
      # e.g the inputs which contain `legacyPackages` attribute are used.
      channelsConfig.allowUnfree = true;
      channels.nixpkgs = { };
      channels.unstable = { };


      # Modules shared between all hosts
      hostDefaults.modules = [
        ./modules/sharedConfigurationBetweenHosts.nix
      ];


      ### Hosts ###

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
