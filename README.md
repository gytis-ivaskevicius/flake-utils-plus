
[![Discord](https://img.shields.io/discord/591914197219016707.svg?label=&logo=discord&logoColor=ffffff&color=7389D8&labelColor=6A7EC2)](https://discord.com/invite/RbvHtGa)

Need help? Createn an issue or ping @Gytis#0001 in discord server above.

# What is this flake #

This flake exposes a library abstraction to *painlessly* generate nixos flake configurations.

The biggest design goal is to keep down the fluff. The library is meant to be easy to understand and use. It aims to be far simpler than frameworks such as devos (previously called nixflk).

# Features of flake #

This flake provides two main features (visible from `flake.nix`):

- `nixosModules.saneFlakeDefaults` - Configures `nix.*` attributes. Generates `nix.nixPath`/`nix.registry` from flake `inputs`, sets `pkgs.nixUnstable` as the default also enables `ca-references` and `flakes`.
- `lib.systemFlake { ... }` - Generates a system flake that may then be built.
- `lib.exporter.modulesFromListExporter [ ./a.nix ./b.nix ]` - Generates modules attributes which looks like this `{ a = import ./a.nix; b = import ./b.nix; }`.
- `lib.exporter.overlaysFromStreamsExporter streams` - Collects all overlays from streams and exports them as an appropriately namespaced attribute set. Users can instantiate with their nixpkgs version.
- `lib.builder.packagesFromOverlayBuilderConstructor streams pkgs` - Similar to the overlay generator, but outputs them as packages, instead. Users can use your cache.


# Examples #

- [Gytis Dotfiles (Author of this project)](https://github.com/gytis-ivaskevicius/nixfiles/blob/master/flake.nix)
- [Fufexan Dotfiles](https://github.com/fufexan/dotfiles/blob/main/flake.nix)
- [Bobbbay Dotfiles](https://github.com/Bobbbay/dotfiles/blob/master/flake.nix)
- [Charlotte Dotfiles](https://github.com/chvp/nixos-config/blob/master/flake.nix)

# How to use this flake #

Example flake with all available attributes can be found [Here](https://github.com/gytis-ivaskevicius/flake-utils-plus/blob/master/examples/fully-featured/flake.nix). (WARNING: Quite overwhelming)

And more realistic flake example can be found [Here](https://github.com/gytis-ivaskevicius/flake-utils-plus/blob/master/examples/somewhat-realistic/flake.nix).

I strongly recommend referring to actual people examples above when setting up your system.

Looking to add a kick-ass repl to your config? Create and import something along the lines of this:
```nix
{ inputs, ... }:

{
  environment.shellAliases = {
    very-cool-nix-repl = "nix repl ${inputs.utils.lib.repl}";
  };
}

```

## Documentation as code. Options with their example usage and description.

```nix
let
  inherit (builtins) removeAttrs;
  mkApp = utils.lib.mkApp;
  # If there is a need to get direct reference to nixpkgs - do this:
  pkgs = self.pkgs.x86_64-linux.nixpkgs;
in flake-utils-plus.lib.systemFlake {


  # `self` and `inputs` arguments are REQUIRED!!!!!!!!!!!!!!
  inherit self inputs;

  # Supported systems, used for packages, apps, devShell and multiple other definitions. Defaults to `flake-utils.lib.defaultSystems`.
  supportedSystems = [ "x86_64-linux" ];


  #################
  #### streams ####
  #################

  # Configuration that is shared between all streams.
  streamsConfig = { allowBroken = true; };

  # Overlays which are applied to all streams.
  sharedOverlays = [ nur.overlay ];

  # Nixpkgs flake reference to be used in the configuration.
  streams.<name>.input = nixpkgs;

  # Stream specific config options.
  streams.<name>.config = { allowUnfree = true; };

  # Patches to apply on selected stream.
  streams.<name>.patches = [ ./someAwesomePatch.patch ];

  # Overlays to apply on a selected stream.
  streams.<name>.overlaysBuilder = streams: [
    (final: prev: { inherit (streams.unstable) neovim; })
  ];


  ####################
  ### hostDefaults ###
  ####################

  # Default architecture to be used for `hosts` defaults to "x86_64-linux".
  hostDefaults.system = "x86_64-linux";

  # Default modules to be passed to all hosts.
  hostDefaults.modules = [ utils.nixosModules.saneFlakeDefaults ];

  # Reference to `streams.<name>.*`, defines default stream to be used by hosts. Defaults to "nixpkgs".
  hostDefaults.streamName = "unstable";

  # Extra arguments to be passed to all modules. Merged with host's extraArgs.
  hostDefaults.extraArgs = { inherit utils inputs; foo = "foo"; };


  #############
  ### hosts ###
  #############

  # System architecture. Defaults to `defaultSystem` argument.
  hosts.<hostname>.system = "aarch64-linux";

  # <name> of the stream to be used. Defaults to `nixpkgs`;
  hosts.<hostname>.streamName = "unstable";

  # Extra arguments to be passed to the modules.
  hosts.<hostname>.extraArgs = { abc = 123; };

  # These are not part of the module system, so they can be used in `imports` lines without infinite recursion.
  hosts.<hostname>.specialArgs = { thing = "abc"; };

  # Host specific configuration.
  hosts.<hostname>.modules = [ ./configuration.nix ];

  # Flake output for configuration to be passed to. Defaults to `nixosConfigurations`.
  hosts.<hostname>.output = "darwinConfigurations";

  # System builder. Defaults to `streams.<name>.input.lib.nixosSystem`.
  # `removeAttrs` workaround due to this issue https://github.com/LnL7/nix-darwin/issues/319
  hosts.<hostname>.builder = args: nix-darwin.lib.darwinSystem (removeAttrs args [ "system" ]);


  #############################
  ### flake output builders ###
  #############################

  # Evaluates to `packages.<system>.coreutils = <unstable-stream-reference>.coreutils`.
  packagesBuilder = streams: { inherit (streams.unstable) coreutils; };

  # Evaluates to `defaultPackage.<system>.neovim = <nixpkgs-stream-reference>.neovim`.
  defaultPackageBuilder = streams: streams.nixpkgs.neovim;

  # Evaluates to `apps.<system>.custom-neovim  = utils.lib.mkApp { drv = ...; exePath = ...; };`.
  appsBuilder = streams: with streams.nixpkgs; {
    custom-neovim = mkApp {
      drv = fancy-neovim;
      exePath = "/bin/nvim";
    };
  };

  # Evaluates to `apps.<system>.firefox  = utils.lib.mkApp { drv = ...; };`.
  defaultAppBuilder = streams: mkApp { drv = streams.nixpkgs.firefox; };

  # Evaluates to `devShell.<system> = <nixpkgs-stream-reference>.mkShell { name = "devShell"; };`.
  devShellBuilder = streams: streams.nixpkgs.mkShell { name = "devShell"; };


  #########################################################
  ### All other properties are passed down to the flake ###
  #########################################################

  checks.x86_64-linux.someCheck = pkgs.hello;
  packages.x86_64-linux.somePackage = pkss.hello;
  overlay = import ./overlays;
  abc = 132;

}
```

