{
  description = "A highly awesome system configuration.";

  inputs = {
    nixpkgs.url = github:nixos/nixpkgs/release-20.09;
    unstable.url = github:nixos/nixpkgs/nixos-unstable;
    utils.url = path:../../;

    nix-darwin.url = github:LnL7/nix-darwin;
    home-manager = {
      url = github:nix-community/home-manager/release-20.09;
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };


  outputs = inputs@{ self, nixpkgs, unstable, utils, nix-darwin, home-manager }:
    utils.lib.systemFlake {

      # `self` and `inputs` arguments are REQUIRED!!!!!!!!!!!!!!
      inherit self inputs;




      # Shared overlays between channels, gets applied to all `channels.<name>.input`
      sharedOverlays = [
        # Overlay imported from `./overlays`. (Defined above)
        self.overlay
      ];

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






      # Shared modules/configurations between `hosts`
      hostDefaults = {
        modules = [
          # Sets sane `nix.*` defaults. Please refer to implementation/readme for more details.
          utils.nixosModules.saneFlakeDefaults
          (import ./modules)
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
          }
        ];
      };


      # Profiles, gets parsed into `nixosConfigurations`
      hosts.Alice.modules = [
        home-manager.nixosModules.home-manager
        ./hosts/Alice.nix
      ];


      hosts.Bob = {
        # This host uses `channels.unstable.{input,overlaysBuilder,config,patches}` attributes instead of `channels.nixpkgs.<...>`
        channelName = "unstable";

        # Host specific configuration.
        modules = [
          home-manager.nixosModules.home-manager
          ./hosts/Bob.nix
        ];
      };

      hosts."Carl" = {
        # This host will be exported under the flake's `darwinConfigurations` output
        output = "darwinConfigurations";

        # Build host with darwinSystem. `removeAttrs` workaround due to https://github.com/LnL7/nix-darwin/issues/319
        builder = args: nix-darwin.lib.darwinSystem (builtins.removeAttrs args [ "system" ]);

        system = "x86_64-darwin";

        # This host uses `channels.unstable.{input,overlaysBuilder,config,patches}` attributes instead of `channels.nixpkgs.<...>`
        channelName = "unstable";

        # Host specific configuration.
        modules = [
          home-manager.darwinModules.home-manager
          ./hosts/Carl.nix
        ];
      };





      overlay = import ./overlays;

    };
}

