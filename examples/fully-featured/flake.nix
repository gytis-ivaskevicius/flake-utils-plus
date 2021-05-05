{
  description = "A highly awesome system configuration.";

  inputs = {
    nixpkgs.url = github:nixos/nixpkgs/release-20.09;
    unstable.url = github:nixos/nixpkgs/nixos-unstable;
    nur.url = github:nix-community/NUR;
    utils.url = path:../../;

    home-manager = {
      url = github:nix-community/home-manager/master;
      inputs.nixpkgs.follows = "nixpkgs";
    };

    neovim = {
      url = github:neovim/neovim?dir=contrib;
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };


  outputs = inputs@{ self, nixpkgs, unstable, nur, utils, home-manager, neovim }:
    utils.lib.systemFlake {

      # `self` and `inputs` arguments are REQUIRED!!!!!!!!!!!!!!
      inherit self inputs;

      # Supported systems, used for packages, apps, devShell and multiple other definitions. Defaults to `flake-utils.lib.defaultSystems`
      supportedSystems = [ "x86_64-linux" ];


      # Default host settings.
      hostDefaults = {
        # Default architecture to be used for `hosts` defaults to "x86_64-linux"
        system = "x86_64-linux";
        # Default channel to be used for `hosts` defaults to "nixpkgs"
        channelName = "unstable";
        # Extra arguments to be passed to modules. Merged with host's extraArgs
        extraArgs = { inherit utils inputs; foo = "foo"; };
        # Default modules to be passed to all hosts.
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

      # Shared overlays between channels, gets applied to all `channels.<name>.input`
      sharedOverlays = [
        # Overlay imported from `./overlays`. (Defined below)
        self.overlay
        # Nix User Repository overlay
        nur.overlay
      ];



      # Channel definitions. `channels.<name>.{input,overlaysBuilder,config,patches}`
      channels.nixpkgs = {
        # Channel input to import
        input = nixpkgs;

        # Channel specific overlays
        overlaysBuilder = channels: [
          (final: prev: { inherit (channels.unstable) zsh; })
        ];

        # Channel specific configuration. Overwrites `channelsConfig` argument
        config = {
          allowUnfree = false;
        };
      };

      # Additional channel input
      channels.unstable.input = unstable;
      # Yep, you see it first folks - you can patch nixpkgs!
      channels.unstable.patches = [ ./myNixpkgsPatch.patch ];
      channels.unstable.overlaysBuilder = channels: [
        (final: prev: {
          neovim-nightly = neovim.defaultPackage.${prev.system};
        })
      ];


      # Default configuration values for `channels.<name>.config = {...}`
      channelsConfig = {
        allowBroken = true;
        allowUnfree = true;
      };

      # Host definitions
      hosts = {
        # Profile name / System hostname
        Morty = {
          # System architecture.
          system = "x86_64-linux";
          # <name> of the channel to be used. Defaults to `nixpkgs`
          channelName = "unstable";
          # Extra arguments to be passed to the modules.
          extraArgs = {
            abc = 123;
          };
          # Host specific configuration.
          modules = [ ./configurations/Morty.host.nix ];
        };

        Rick = {
          modules = [ ./configurations/Rick.host.nix ];
          output = "someConfigurations";
        };

      };



      # All other values gets passed down to the flake
      overlay = import ./overlays;
      abc = 132;
      # etc

    };
}




