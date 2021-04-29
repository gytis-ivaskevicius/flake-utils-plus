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
    agenix.url = github:ryantm/agenix;
  };


  outputs = inputs@{ self, nixpkgs, unstable, utils, nix-darwin, home-manager, agenix }:
    utils.lib.systemFlake {

      # `self` and `inputs` arguments are REQUIRED!!!!!!!!!!!!!!
      inherit self inputs;




      # Shared overlays between streams, gets applied to all `streams.<name>.input`
      sharedOverlays = [
        # Overlay imported from `./overlays`. (Defined above)
        self.overlay
      ];

      # Stream definitions. `streams.<name>.{input,overlaysBuilder,config,patches}`
      streams.nixpkgs.input = nixpkgs;
      streams.unstable.input = unstable;

      # Default configuration values for `streams.<name>.config = {...}`
      streamsConfig.allowUnfree = true;

      # Stream specific overlays
      streams.nixpkgs.overlaysBuilder = streams: [
        (final: prev: {
          # Overwrites specified packages to be used from unstable stream.
          inherit (streams.unstable) alacritty ranger;
        })
        agenix.overlay
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
        # This host uses `streams.unstable.{input,overlaysBuilder,config,patches}` attributes instead of `streams.nixpkgs.<...>`
        streamName = "unstable";

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

        # This host uses `streams.unstable.{input,overlaysBuilder,config,patches}` attributes instead of `streams.nixpkgs.<...>`
        streamName = "unstable";

        # Host specific configuration.
        modules = [
          home-manager.darwinModules.home-manager
          ./hosts/Carl.nix
        ];
      };




      # export overlays automatically for all packages defined in overlaysBuilder of each stream
      overlays = utils.lib.exporter.overlaysFromStreamsExporter {
        inherit (self) pkgs inputs;
      };

      # construct packagesBuilder to export all packages defined in overlays
      packagesBuilder = utils.lib.builder.packagesFromOverlaysBuilderConstructor self.overlays;

      overlay = import ./overlays;

    };
}

