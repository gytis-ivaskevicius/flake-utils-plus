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
  inherit (flake-utils-plus.lib) eachSystem patchChannel;
  inherit (builtins) foldl' mapAttrs removeAttrs attrValues isAttrs isList;

  # set defaults and validate host arguments
  evalHostArgs =
    { channelName ? "nixpkgs"
    , system ? "x86_64-linux"
    , output ? "nixosConfigurations"
    , builder ? channels.${channelName}.input.lib.nixosSystem
    , modules ? [ ]
    , extraArgs ? { }
    , specialArgs ? { }
    }: { inherit channelName system output builder modules extraArgs specialArgs; };

  # recursively merge attribute sets and lists up to a certain depth
  mergeAny = lhs: rhs:
    lhs // mapAttrs
      (name: value:
        if isAttrs value then lhs.${name} or { } // value
        else if isList value then lhs.${name} or [ ] ++ value
        else value
      )
      rhs;

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
    in
    {
      ${host.output}.${hostname} = host.builder {
        inherit (selectedNixpkgs) system;
        modules = [
          ({ pkgs, lib, options, ... }: {
            # 'mkMerge` to separate out each part into its own module
            _type = "merge";
            contents = [
              (optionalAttrs (options ? networking.hostName) {
                networking.hostName = hostname;
              })

              (if options ? nixpkgs then {
                nixpkgs = {
                  inherit (selectedNixpkgs) overlays config system;
                };
              } else { _module.args.pkgs = selectedNixpkgs; })

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
        specialArgs = host.specialArgs;
      };
    }
  );

in
mergeAny otherArguments (

  eachSystem supportedSystems
    (system:
      let
        importChannel = name: value: import (patchChannel system value.input (value.patches or [ ])) {
          inherit system;
          overlays = sharedOverlays ++ (if (value ? overlaysBuilder) then (value.overlaysBuilder pkgs) else [ ]);
          config = channelsConfig // (value.config or { });
        };

        pkgs = mapAttrs importChannel channels;

        mkOutput = output: builder: {
          ${output} = otherArguments.${output}.${system} or { }
          // optionalAttrs (args ? ${builder}) (args.${builder} pkgs);
        };

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
