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

      # Host definitions, gets parsed into `nixosConfigurations`
      hosts = {
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
          modules = [ ./configurations/Morty.host.nix ];
        };

        Rick = {
          modules = [ ./configurations/Rick.host.nix ];
          output = "someConfigurations";
        };

        Summer = {
          channelName = "unstable";
          modules = [ ./configurations/Summer.host.nix ];
        };
      };

      # Evaluates to `packages.<system>.attributeKey = "attributeValue"`
      packagesBuilder = channels: { inherit (channels.unstable) coreutils; };

      # Evaluates to `defaultPackage.<system>.attributeKey = "attributeValue"`
      defaultPackageBuilder = channels: channels.nixpkgs.runCommandNoCC "package" { } "echo package > $out";

      # Evaluates to `apps.<system>.attributeKey = "attributeValue"`
      appsBuilder = channels: { package = { type = "app"; program = channels.nixpkgs.runCommandNoCC "package" { } "echo test > $out"; }; };

      # Evaluates to `defaultApp.<system>.attributeKey = "attributeValue"`
      defaultAppBuilder = channels: { type = "app"; program = channels.nixpkgs.runCommandNoCC "package" { } "echo test > $out"; };

      # Evaluates to `devShell.<system>.attributeKey = "attributeValue"`
      devShellBuilder = channels: channels.nixpkgs.mkShell { name = "devShell"; };

      # Evaluates to `checks.<system>.attributeKey = "attributeValue"`
      checksBuilder = channels:
        let
          booleanCheck = cond:
            if cond
            then channels.nixpkgs.runCommandNoCC "success" { } "echo success > $out"
            else channels.nixpkgs.runCommandNoCC "failure" { } "exit 1";
        in
        {
          check = channels.nixpkgs.runCommandNoCC "test" { } "echo test > $out";
          # Modules (and lib) from patched nixpkgs are used
          summerHasCustomModuleConfigured = booleanCheck (self.nixosConfigurations.Summer.config.patchedModule.test == "test");
          # nixpkgs config from host-specific module is used
          summerHasPackageOverridesConfigured = booleanCheck (self.nixosConfigurations.Summer.config.nixpkgs.pkgs.config ? packageOverrides);
          # nixpkgs config from channel is also used
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




