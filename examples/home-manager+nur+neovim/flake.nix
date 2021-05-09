{
  description = "A highly awesome system configuration.";

  inputs = {
    nixpkgs.url = github:nixos/nixpkgs/nixos-unstable;
    utils.url = path:../../;


    nur.url = github:nix-community/NUR;

    neovim = {
      url = github:neovim/neovim?dir=contrib;
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = github:nix-community/home-manager/release-20.09;
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };


  outputs = inputs@{ self, nixpkgs, utils, home-manager, neovim, nur }:
    utils.lib.systemFlake {
      inherit self inputs;


      channels.nixpkgs.input = nixpkgs;
      channelsConfig.allowUnfree = true;

      sharedOverlays = [
        nur.overlay
        self.overlay
        neovim.overlay
      ];


      # Modules shared between all hosts
      hostDefaults.modules = [
        utils.nixosModules.saneFlakeDefaults
        home-manager.nixosModules.home-manager
        ./modules/sharedConfigurationBetweenHosts.nix
      ];


      hosts.Rick.modules = [
        ./hosts/Rick.nix
      ];


      overlay = import ./overlays;

    };
}

