{
  description = "A highly awesome system configuration.";

  inputs = {
    nixpkgs.url = github:nixos/nixpkgs/release-20.09;
    unstable.url = github:nixos/nixpkgs/nixos-unstable;
    # utils.url = github:gytis-ivaskevicius/flake-utils-plus;
    utils.url = path:../../;

    nix-darwin.url = github:LnL7/nix-darwin;
    home-manager = {
      url = github:nix-community/home-manager/master;
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };


  outputs = inputs@{ self, nixpkgs, unstable, utils, nix-darwin, home-manager }:
    utils.lib.systemFlake {

      # `self` and `inputs` arguments are REQUIRED!!!!!!!!!!!!!!
      inherit self inputs;



      # Channel definitions. `channels.<name>.{input,overlaysBuilder,config,patches}`
      channels.nixpkgs.input = nixpkgs;
      channels.unstable.input = unstable;

      # Default configuration values for `channels.<name>.config = {...}`
      channelsConfig.allowUnfree = true;

      # Channel specific overlays
      channels.nixpkgs.overlaysBuilder = channels: [
        (final: prev: {
          # Overwrites specified packages to be used from unstable channel.
          inherit (channels.unstable) alacritty ranger jdk15_headless;
        })
      ];





      # Profiles, gets parsed into `nixosConfigurations`
      hosts.HostnameOne.modules = [
        (import ./hosts/One.nix)
      ];


      hosts.HostnameTwo = {
        # This host uses `channels.unstable.{input,overlaysBuilder,config,patches}` attributes instead of `channels.nixpkgs.<...>`
        channelName = "unstable";

        # Host specific configuration. Same as `sharedModules`
        modules = [
          (import ./hosts/Two.nix)
        ];
      };

      hosts."HostNameThree" = {
        # This host will be exported under the flake's `darwinConfigurations` output
        output = "darwinConfigurations";

        # Build host with darwinSystem
        builder = nix-darwin.lib.darwinSystem;

        # This host uses `channels.unstable.{input,overlaysBuilder,config,patches}` attributes instead of `channels.nixpkgs.<...>`
        channelName = "unstable";

        # Host specific configuration.
        modules = [
          (import ./configurations/Morty.home.nix)
        ];
      };





      overlay = import ./overlays;

      # Shared overlays between channels, gets applied to all `channels.<name>.input`
      sharedOverlays = [
        # Overlay imported from `./overlays`. (Defined above)
        self.overlay
      ];





      # Shared modules/configurations between `hosts`
      hostDefaults = {
        modules = [
          home-manager.nixosModules.home-manager
          # Sets sane `nix.*` defaults. Please refer to implementation/readme for more details.
          utils.nixosModules.saneFlakeDefaults
          (import ./modules)
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
          }
        ];
      };



    };
}



