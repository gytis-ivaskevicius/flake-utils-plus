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
        # Default stream to be used for `hosts` defaults to "nixpkgs"
        streamName = "unstable";
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

      # Shared overlays between streams, gets applied to all `streams.<name>.input`
      sharedOverlays = [
        # Overlay imported from `./overlays`. (Defined below)
        self.overlay
        # Nix User Repository overlay
        nur.overlay
      ];



      # Stream definitions. `streams.<name>.{input,overlaysBuilder,config,patches}`
      streams.nixpkgs = {
        # Stream input to import
        input = nixpkgs;

        # Stream specific overlays
        overlaysBuilder = streams: [
          (final: prev: { inherit (streams.unstable) zsh; })
        ];

        # Stream specific configuration. Overwrites `streamsConfig` argument
        config = {
          allowUnfree = false;
        };
      };

      # Additional stream input
      streams.unstable.input = unstable;
      # Yep, you see it first folks - you can patch nixpkgs!
      streams.unstable.patches = [ ./myNixpkgsPatch.patch ];
      streams.unstable.overlaysBuilder = streams: [
        (final: prev: {
          neovim-nightly = neovim.defaultPackage.${prev.system};
        })
      ];


      # Default configuration values for `streams.<name>.config = {...}`
      streamsConfig = {
        allowBroken = true;
        allowUnfree = true;
      };

      # Host definitions
      hosts = {
        # Profile name / System hostname
        Morty = {
          # System architecture.
          system = "x86_64-linux";
          # <name> of the stream to be used. Defaults to `nixpkgs`
          streamName = "unstable";
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

        Summer = {
          streamName = "unstable";
          modules = [ ./configurations/Summer.host.nix ];
        };
      };

      # Evaluates to `packages.<system>.attributeKey = "attributeValue"`
      packagesBuilder = streams: { inherit (streams.unstable) coreutils; };

      # Evaluates to `defaultPackage.<system>.attributeKey = "attributeValue"`
      defaultPackageBuilder = streams: streams.nixpkgs.runCommandNoCC "package" { } "echo package > $out";

      # Evaluates to `apps.<system>.attributeKey = "attributeValue"`
      appsBuilder = streams: { package = { type = "app"; program = streams.nixpkgs.runCommandNoCC "package" { } "echo test > $out"; }; };

      # Evaluates to `defaultApp.<system>.attributeKey = "attributeValue"`
      defaultAppBuilder = streams: { type = "app"; program = streams.nixpkgs.runCommandNoCC "package" { } "echo test > $out"; };

      # Evaluates to `devShell.<system> = "attributeValue"`
      devShellBuilder = streams: streams.nixpkgs.mkShell { name = "devShell"; };

      # Evaluates to `checks.<system>.attributeKey = "attributeValue"`
      checksBuilder = streams:
        let
          booleanCheck = cond:
            if cond
            then streams.nixpkgs.runCommandNoCC "success" { } "echo success > $out"
            else streams.nixpkgs.runCommandNoCC "failure" { } "exit 1";
        in
        {
          check = streams.nixpkgs.runCommandNoCC "test" { } "echo test > $out";
          # Modules (and lib) from patched nixpkgs are used
          summerHasCustomModuleConfigured = booleanCheck (self.nixosConfigurations.Summer.config.patchedModule.test == "test");
          # nixpkgs config from host-specific module is used
          summerHasPackageOverridesConfigured = booleanCheck (self.nixosConfigurations.Summer.config.nixpkgs.pkgs.config ? packageOverrides);
          # nixpkgs config from stream is also used
          summerHasUnfreeConfigured = booleanCheck (self.nixosConfigurations.Summer.config.nixpkgs.pkgs.config ? allowUnfree);
        };

      # All other values gets passed down to the flake
      checks.x86_64-linux.merge-with-checksBuilder-test = self.pkgs.x86_64-linux.nixpkgs.hello;
      packages.x86_64-linux.patched-package = self.pkgs.x86_64-linux.unstable.flake-utils-plus-test;
      overlay = import ./overlays;
      abc = 132;
      # etc

    };
}




