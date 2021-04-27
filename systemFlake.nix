{ flake-utils-plus }:

{ self
, defaultSystem ? "x86_64-linux" # will be deprecated soon use hostDefaults.system instead
, supportedSystems ? flake-utils-plus.lib.defaultSystems
, inputs

, channels ? { }
, channelsConfig ? { }
, sharedOverlays ? [ ]

, nixosProfiles ? { } # will be deprecated soon, use hosts, instead.
, hosts ? nixosProfiles
, sharedExtraArgs ? { } # deprecate soon, prefer hostDefaults
, sharedModules ? [ ] # deprecate soon, prefer hostDefaults
, hostDefaults ? {
    system = defaultSystem;
    modules = sharedModules;
    extraArgs = sharedExtraArgs;
  }

, packagesBuilder ? null
, defaultPackageBuilder ? null
, appsBuilder ? null
, defaultAppBuilder ? null
, devShellBuilder ? null
, checksBuilder ? null
, ...
}@args:

let
  inherit (flake-utils-plus.lib) eachSystem patchChannel mergeAny;
  inherit (builtins) foldl' mapAttrs removeAttrs attrValues attrNames listToAttrs concatMap;

  filterAttrs = pred: set:
    listToAttrs (concatMap (name: let value = set.${name}; in if pred name value then [ ({ inherit name value; }) ] else [ ]) (attrNames set));

  srcs = filterAttrs (_: value: !value ? outputs) inputs;

  # set defaults and validate host arguments
  evalHostArgs =
    { channelName ? "nixpkgs"
    , system ? "x86_64-linux"
    , output ? "nixosConfigurations"
    , builder ? channels.${channelName}.input.lib.nixosSystem
    , modules ? [ ]
    , extraArgs ? { }
      # These are not part of the module system, so they can be used in `imports` lines without infinite recursion
    , specialArgs ? { }
    }: {
      inherit channelName system output builder modules extraArgs specialArgs;
    };

  foldHosts = foldl' mergeAny { };

  optionalAttrs = check: value: if check then value else { };

  otherArguments = removeAttrs args [
    "defaultSystem" # TODO: deprecated, remove
    "sharedExtraArgs" # deprecated
    "inputs"
    "hosts"
    "hostDefaults"
    "nixosProfiles"
    "channels"
    "channelsConfig"
    "self"
    "sharedModules" # deprecated
    "sharedOverlays"
    "supportedSystems"

    "packagesBuilder"
    "defaultPackageBuilder"
    "appsBuilder"
    "defaultAppBuilder"
    "devShellBuilder"
    "checksBuilder"
  ];

  getNixpkgs = host: self.pkgs."${host.system}"."${host.channelName}";

  configurationBuilder = hostname: host': (
    let
      selectedNixpkgs = getNixpkgs host;
      host = evalHostArgs (mergeAny hostDefaults host');
      patchedChannel = selectedNixpkgs.path;

      specialArgs = host.specialArgs // { channel = selectedNixpkgs; };

      /* nixos specific arguments */
      # Use lib from patched nixpkgs
      lib = selectedNixpkgs.lib;
      # Use nixos modules from patched nixpkgs
      baseModules = import (patchedChannel + "/nixos/modules/module-list.nix");
      nixosSpecialArgs =
        let
          f = channelName:
            { "${channelName}ModulesPath" = toString (channels.${channelName}.input + "/nixos/modules"); };
        in
        # Add `<channelName>ModulesPath`s
        (foldl' (lhs: rhs: lhs // rhs) { } (map f (attrNames channels)))
        # Override `modulesPath` because otherwise imports from there will not use patched nixpkgs
        // { modulesPath = toString (patchedChannel + "/nixos/modules"); };
      # The only way to find out if a host has `nixpkgs.config` set to
      # the non-default value is by evalling most of the config.
      hostConfig = (lib.evalModules {
        prefix = [ ];
        check = false;
        modules = baseModules ++ host.modules;
        args = { inherit inputs; } // host.extraArgs;
        specialArgs = nixosSpecialArgs // specialArgs;
      }).config;
    in
    {
      ${host.output}.${hostname} = host.builder ({
        inherit (host) system;
        modules = [
          ({ pkgs, lib, options, config, ... }: {
            # 'mkMerge` to separate out each part into its own module
            _type = "merge";
            contents = [
              (optionalAttrs (options ? networking.hostName) {
                networking.hostName = hostname;
              })

              (if options ? nixpkgs.pkgs then
                {
                  nixpkgs.config = selectedNixpkgs.config;
                  nixpkgs.pkgs =
                    # Make sure we don't import nixpkgs again if not
                    # necessary. We can't use `config.nixpkgs.config`
                    # because that triggers infinite recursion.
                    if (hostConfig.nixpkgs.config == { }) then
                      selectedNixpkgs
                    else
                      import patchedChannel {
                        inherit (host) system;
                        overlays = selectedNixpkgs.overlays;
                        config = selectedNixpkgs.config // config.nixpkgs.config;
                      };
                }
              else { _module.args.pkgs = selectedNixpkgs; })

              (optionalAttrs (options ? system.configurationRevision) {
                system.configurationRevision = lib.mkIf (self ? rev) self.rev;
              })

              (optionalAttrs (options ? nix.package) {
                nix.package = lib.mkDefault pkgs.nixUnstable;
              })

              {
                # at this point we assume, that an evaluator at least
                # uses nixpkgs.lib to evaluate modules.
                _module.args = { inherit inputs; } // host.extraArgs;
              }
            ];
          })
        ] ++ host.modules;
        inherit specialArgs;
      } // (optionalAttrs (host.output == "nixosConfigurations") {
        inherit lib baseModules;
        specialArgs = nixosSpecialArgs // specialArgs;
      }));
    }
  );

in
mergeAny otherArguments (

  eachSystem supportedSystems
    (system:
      let
        importChannel = name: value: (import (patchChannel system value.input (value.patches or [ ])) {
          inherit system;
          overlays = [ (final: prev: { inherit srcs; }) ] ++ sharedOverlays ++ (if (value ? overlaysBuilder) then (value.overlaysBuilder pkgs) else [ ]);
          config = channelsConfig // (value.config or { });
        }) // { inherit name; inherit (value) input; };

        pkgs = mapAttrs importChannel channels;

        mkOutput = output: builder:
          mergeAny
            # prevent override of nested outputs in otherArguments
            (optionalAttrs (otherArguments ? ${output}.${system})
              { ${output} = otherArguments.${output}.${system}; })
            (optionalAttrs (args ? ${builder})
              { ${output} = args.${builder} pkgs; });
      in
      { inherit pkgs; }
      // mkOutput "packages" "packagesBuilder"
      // mkOutput "defaultPackage" "defaultPackageBuilder"
      // mkOutput "apps" "appsBuilder"
      // mkOutput "defaultApp" "defaultAppBuilder"
      // mkOutput "devShell" "devShellBuilder"
      // mkOutput "checks" "checksBuilder"
    )
  # produces attrset in the shape of
  # { nixosConfigurations = {}; darwinConfigurations = {};  ... }
  # according to profile.output or the default `nixosConfigurations`
  // foldHosts (attrValues (mapAttrs configurationBuilder hosts))
)
