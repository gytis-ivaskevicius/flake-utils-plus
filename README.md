# What is this flake #

This flake exposes a library abstraction to *painlessly* generate nixos flake configurations.

The biggest design goal is to keep down the fluff. The library is
meant to be easy to understand and use. It aims to be far simpler
than frameworks such as devos (previously called nixflk).

# Features of flake #

This flake provides two main features (visible from `flake.nix`):


- `nixPathFromInputs` generates list for nixpath to include flake inputs.
- `nixRegistryFromInputs` generates attribute set for registry to include flake inputs.
- `nixDefaultsFromInputs` generates `nix` configuration attribute set. Invokes `nixPathFromInputs` and `nixRegistreyFromInputs` as well as enables flakes.
- `systemFlake` generates a system flake that may then be built.

# How to use this flake #

```nix
outputs = inputs@{ self, nixpkgs, unstable, nur, utils, home-manager, neovim }:
utils.lib.systemFlake {

  # Required arguments
  inherit self inputs;

  # Supported systems, used for packages, apps, devShell and multiple other definitions. Defaults to `flake-utils.lib.defaultSystems`
  supportedSystems = [ "aarch64-linux" "x86_64-linux" ];

  # Default architecture to be used for `nixosProfiles` defaults to "x86_64-linux". Might get renamed in near future
  defaultSystem = "aarch64-linux";

  # Channel definitions. `channels.<name>.{input,overlaysFunc,config}`
  channels.nixpkgs = {
    # Channel input to import
    input = nixpkgs;

    # Channel specific overlays
    overlaysFunc = channels: [
      (final: prev: { inherit (channels.unstable) zsh; })
    ];

    # Channel specific configuration. Overwrites `channelsConfig` argument
    config = {
      allowUnfree = false;
    };
  };

  # Additional channel input
  channels.unstable.input = unstable;
  channels.unstable.overlaysFunc = channels: [
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
      system = "x96_64-linux";
      # <name> of the channel to be used
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

  # Extra arguments to be passed to modules
  sharedExtraArgs = { inherit utils; };

  # Overlays, gets applied to all `channels.<name>.input`
  sharedOverlays = [
    # Overlay imported from `./overlays`. (Defined below)
    self.overlays
    # Nix User Repository overlay
    nur.overlay
  ];

  # Shared modules/configurations between `nixProfiles`
  sharedModules = [
    home-manager.nixosModules.home-manager
    (import ./modules)
    {
      # Sets sane `nix.*` defaults. Please refer to implementation/readme for more details.
      nix = utils.lib.nixDefaultsFromInputs inputs;

      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
    }
  ];



  ### Postfix of keys below might change in soon future.

  # Evaluates to `packages.<system>.attributeKey = "attributeValue"`
  packagesFunc = channels: { attributeKey = "attributeValue"; };
  # Evaluates to `defaultPackage.<system>.attributeKey = "attributeValue"`
  defaultPackageFunc = channels: { attributeKey = "attributeValue"; };
  # Evaluates to `apps.<system>.attributeKey = "attributeValue"`
  appsFunc = channels: { attributeKey = "attributeValue"; };
  # Evaluates to `defaultApp.<system>.attributeKey = "attributeValue"`
  defaultAppFunc = channels: { attributeKey = "attributeValue"; };
  # Evaluates to `devShell.<system>.attributeKey = "attributeValue"`
  devShellFunc = channels: { attributeKey = "attributeValue"; };
  # Evaluates to `checks.<system>.attributeKey = "attributeValue"`
  checksFunc = channels: { attributeKey = "attributeValue"; };

  # All other values gets passed down to the flake
  overlay = import ./overlays;
  abc = 132;
  # etc

};
```


# Other Examples #

- [Gytis Dotfiles](https://github.com/gytis-ivaskevicius/nixfiles/blob/master/flake.nix)
- [Justin Dotfiles](https://github.com/DieracDelta/flakes/blob/flakes/flake.nix)
- [fufexan Dotfiles](https://github.com/fufexan/nixos-config/blob/master/flake.nix)
- [Bobbbay Dotfiles](https://github.com/Bobbbay/dotfiles/blob/master/flake.nix)

