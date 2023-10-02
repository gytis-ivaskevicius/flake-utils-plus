{
  description = "A highly awesome system configuration.";

  inputs = {
    nixpkgs.url = github:nixos/nixpkgs/nixos-unstable-small; # Lets pretend that this is a stable channel
    unstable.url = github:nixos/nixpkgs/nixos-unstable-small;
    utils.url = path:../../;
  };


  outputs = inputs@{ self, nixpkgs, unstable, utils }:
    utils.lib.mkFlake {
      inherit self inputs;

      # Channel definitions.
      # Channels are automatically generated from nixpkgs inputs
      # e.g the inputs which contain `legacyPackages` attribute are used.
      channelsConfig.allowUnfree = true;


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
