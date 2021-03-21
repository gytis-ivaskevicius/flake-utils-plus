
# What is this flake #

This flake exposes a library abstraction to *painlessly* generate nixos flake configurations.

The biggest design goal is to keep down the fluff. The library is meant to be easy to understand and use. It aims to be far simpler than frameworks such as devos (previously called nixflk).

# Features of flake #

This flake provides two main features (visible from `flake.nix`):

- `nixosModules.saneFlakeDefaults` - Configures `nix.*` attributes. Generates `nix.nixPath`/`nix.registry` from flake `inputs`, sets `pkgs.nixUnstable` as the default also enables `ca-references` and `flakes`.
- `lib.systemFlake { ... }` - Generates a system flake that may then be built.
- `lib.modulesFromList [ ./a.nix ./b.nix ]` - Generates modules attributes which looks like this `{ a = import ./a.nix; b = import ./b.nix; }`.


# Examples #

- [Gytis Dotfiles (Author of this project)](https://github.com/gytis-ivaskevicius/nixfiles/blob/master/flake.nix)
- [fufexan Dotfiles](https://github.com/fufexan/nixos-config/blob/master/flake.nix)

# How to use this flake #

Example flake with all available attributes can be found [Here](https://github.com/gytis-ivaskevicius/flake-utils-plus/blob/master/examples/fully-featured-flake.nix).

And more realistic flake example can be found [Here](https://github.com/gytis-ivaskevicius/flake-utils-plus/blob/master/examples/somewhat-realistic-flake.nix).

```nix
{
  outputs = inputs@{ self, nixpkgs, unstable, nur, utils, home-manager, neovim }:
    utils.lib.systemFlake {

      # `self` and `inputs` arguments are REQUIRED!!!!!!!!!
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
        overlaysBuilder = channels: [ ];

        # Channel specific configuration. Overwrites `channelsConfig` argument
        config = { allowUnfree = false; };
      };

      # Additional channel input
      channels.unstable.input = unstable;
      # Yep, you see it first folks - you can patch nixpkgs!
      channels.unstable.patches = [ ./myNixpkgsPatch.patch ];


      # Default configuration values for `channels.<name>.config = {...}`
      channelsConfig.allowUnfree = true;

      # Profiles, gets parsed into `nixosConfigurations`
      nixosProfiles = {
        # Profile name / System hostname
        FirstHost = {
          # System architecture. Defaults to `defaultSystem` argument
          system = "x86_64-linux";
          # <name> of the channel to be used. Defaults to `nixpkgs`
          channelName = "unstable";
          # Extra arguments to be passed to the modules. Overwrites `sharedExtraArgs` argument
          extraArgs = { };
          # Host specific configuration
          modules = [ ];
        };

        OtherHost = { ... };
      };

      # Extra arguments to be passed to modules. Defaults to `{ inherit inputs; }`
      sharedExtraArgs = { };

      # Shared overlays between channels, gets applied to all `channels.<name>.input`
      sharedOverlays = [ ];

      # Shared modules/configurations between `nixosProfiles`
      sharedModules = [ utils.nixosModules.saneFlakeDefaults ];


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
    };
}
```


