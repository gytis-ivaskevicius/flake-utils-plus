# What is this flake #

The most difficult part of switching to flakes is understanding the subtleties of:

- Adding overlays
- Using packages from multiple channels
- Passing in multiple flake sources

This flake exposes a library abstraction to *painlessly* generate nixos configurations
with these features.

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
utils.lib.systemFlake {

      inherit self inputs;
      defaultSystem = "x86_64";      # Specifies default `pkgs.<name>.system` defaults to "x86_64-linux"

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

      # attribute set of individual hosts
      nixosProfiles = {           # Profiles, gets parsed into `nixosConfigurations`
        FirstHost = {                 # System hostname
          nixpkgs = self.pkgs.nixpkgs; # Defaults nixpkgs input to follow.
          extraArgs = {};              # Globally available attributes
          modules = [];                # Host specific configuration
        };
        OtherHost = { ... };
      };

      sharedOverlays = []; # Shared overlays: global system overlays

      sharedModules = []; # list of global system modules

      # All other values gets passed down to the flake
    };
```


# Other Examples #

[Gytis Dotfiles](https://github.com/gytis-ivaskevicius/nixfiles)
[Justin Dotfiles](https://github.com/DieracDelta/flakes)

