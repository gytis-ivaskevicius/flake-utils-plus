{
  description = "Home Manager + NUR + Neovim config";

  inputs = {
    nixpkgs.url = github:nixos/nixpkgs/nixos-unstable-small;
    utils.url = path:../../;


    nur.url = github:nix-community/NUR;

    neovim = {
      url = github:neovim/neovim?dir=contrib;
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = github:nix-community/home-manager/release-21.05;
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };


  outputs = inputs@{ self, nixpkgs, utils, home-manager, neovim, nur }:
    utils.lib.mkFlake {
      inherit self inputs;


      channelsConfig.allowUnfree = true;

      sharedOverlays = [
        nur.overlay
        self.overlay
        neovim.overlay
      ];


      # Modules shared between all hosts
      hostDefaults.modules = [
        home-manager.nixosModules.home-manager
        ./modules/sharedConfigurationBetweenHosts.nix
      ];


      hosts.Rick.modules = [
        ./hosts/Rick.nix
      ];


      overlay = import ./overlays;

    };
}

