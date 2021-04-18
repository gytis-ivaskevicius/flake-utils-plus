{
  description = "A highly awesome system configuration.";

  inputs = {
    nixpkgs.url = github:nixos/nixpkgs/release-20.09;
    unstable.url = github:nixos/nixpkgs/nixos-unstable;
    nur.url = github:nix-community/NUR;
    utils.url = github:gytis-ivaskevicius/flake-utils-plus;

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
      supportedSystems = [ "aarch64-linux" "x86_64-linux" ];

      # Default architecture to be used for `nixosProfiles` defaults to "x86_64-linux"
      defaultSystem = "aarch64-linux";

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

      # Profiles, gets parsed into `nixosConfigurations`
      nixosProfiles = {
        # Profile name / System hostname
        Morty = {
          # System architecture. Defaults to `defaultSystem` argument
          system = "x86_64-linux";
          # <name> of the channel to be used. Defaults to `nixpkgs`
          channelName = "unstable";
          # Extra arguments to be passed to the modules. Overwrites `sharedExtraArgs` argument
          extraArgs = {
            abc = 123;
          };
          # Host specific configuration. Same as `sharedModules`
          modules = [
            (import ./configurations/Morty.host.nix)
          ];
        };
      };

      # Extra arguments to be passed to modules. Defaults to `{ inherit inputs; }`
      sharedExtraArgs = { inherit utils inputs; };

      # Shared overlays between channels, gets applied to all `channels.<name>.input`
      sharedOverlays = [
        # Overlay imported from `./overlays`. (Defined below)
        self.overlays
        # Nix User Repository overlay
        nur.overlay
      ];

      # Shared modules/configurations between `nixosProfiles`
      sharedModules = [
        home-manager.nixosModules.home-manager
        # Sets sane `nix.*` defaults. Please refer to implementation/readme for more details.
        utils.nixosModules.saneFlakeDefaults
        (import ./modules)
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
        }
      ];


      # Evaluates to `packages.<system>.attributeKey = "attributeValue"`
      packagesBuilder = channels: { attributeKey = "attributeValue"; };

      # Evaluates to `defaultPackage.<system>.attributeKey = "attributeValue"`
      defaultPackageBuilder = channels: { attributeKey = "attributeValue"; };

      # Evaluates to `apps.<system>.attributeKey = "attributeValue"`
      appsBuilder = channels: { attributeKey = "attributeValue"; };

      # Evaluates to `defaultApp.<system>.attributeKey = "attributeValue"`
      defaultAppBuilder = channels: { attributeKey = "attributeValue"; };

      # Evaluates to `devShell.<system>.attributeKey = "attributeValue"`
      devShellBuilder = channels: { attributeKey = "attributeValue"; };

      # Evaluates to `checks.<system>.attributeKey = "attributeValue"`
      checksBuilder = channels: { attributeKey = "attributeValue"; };

      # All other values gets passed down to the flake
      overlay = import ./overlays;
      abc = 132;
      # etc

    };
}
