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
    let
      pkgs = self.pkgs.nixpkgs;
    in
    utils.lib.systemFlake {

      inherit self inputs;
      defaultSystem = "xyz";      # Specifies default `pkgs.<name>.system` defaults to "x86_64-linux"

      channels.nixpkgs = {
        #patches = [];    # TODO:
        input = nixpkgs;  # Sources to import
        overlays = [];    # Channel specific overlays
        system = "xyz";   # Overwrites `defaultSystem`
        config = {        # Overwrites `pkgsConfig`
          allowUnfree = false;
        };
      };

      # Unstable packages
      channels.unstable.input = unstable;

      channelsConfig = {          # Default configuration values for `pkgs.<name>.config = {...}`
        allowBroken = true;
        allowUnfree = true;
      };

      nixosProfiles = {           # Profiles, gets parsed into `nixosConfigurations`
        Morty = {                 # System hostname
          nixpkgs = self.pkgs.unstable; # Defaults to `self.pkgs.nixpkgs`
          extraArgs = {           # Globally available argumets
            abc = 123;
          };
          modules = [             # Host specific configuration. Same as `sharedModules`
            (import ./configurations/Morty.host.nix)
          ];
        };
      };

      sharedOverlays = [          # Overlays, gets applied to all `pkgs.<name>.input`
        self.overlays             # Overlay imported from `./overlays`
        nur.overlay               # Nix User Repository overlay
        (final: prev: {           # Overlay function
          neovim-nightly = neovim.defaultPackage.${pkgs.system};
        })
      ];

      sharedModules = [           # Shared modules/configurations between `nixProfiles`
        home-manager.nixosModules.home-manager
        (import ./modules)
        {
          nix = utils.lib.nixDefaultsFromInputs inputs; # Sets sane `nix.nixPath` `nix.registry` `nix.extraOptions`. Please refer to implementation for more details.

          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
        }
      ];

      # All other values gets passed down to the flake
      overlay = import ./overlays;
      abc = 132;
      # etc

    };
}




