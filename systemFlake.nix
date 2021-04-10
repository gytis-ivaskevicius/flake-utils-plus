{ flake-utils-plus }:

{ self
, defaultSystem ? "x86_64-linux" # will be deprecated soon use hostDefaults.system instead
, supportedSystems ? flake-utils-plus.lib.defaultSystems
, inputs

, channels ? { }
, channelsConfig ? { }
, sharedOverlays ? [ ]

, nixosConfigurations ? { } # deprecate soon, no longer used or works
, hostDefaults ? { }
, nixosProfiles ? { } # will be deprecated soon, use hosts, instead.
, hosts ? nixosProfiles
, sharedExtraArgs ? { }
, sharedModules ? [ ]

, packagesBuilder ? null
, defaultPackageBuilder ? null
, appsBuilder ? null
, defaultAppBuilder ? null
, devShellBuilder ? null
, checksBuilder ? null
, ...
}@args:

let
  inherit (flake-utils-plus.lib) eachSystem;

  # ensure for that all expected, but no extra attrs are present
  validateHost =
    { channelName ? null
    , system ? null
    , output ? null
    , builder ? null
    , modules ? [ ]
    , extraArgs ? { }
    }: { inherit channelName system output builder modules extraArgs; };

  mergeHosts = lhs: rhs:
    let
      # convoluted nix-kell, but clean(er) english-german below :-)
      _ = x: op: y: op x y;
      oder = lhs: rhs: if lhs != null then lhs else rhs;

      rhs' = {
        channelName = _ rhs.channelName;
        system = _ rhs.system;
        output = _ rhs.output;
        builder = _ rhs.builder;
      };
      lhs' = {
        channelName = _ lhs.channelName;
        system = _ lhs.system;
        output = _ lhs.output;
        builder = _ lhs.builder;
      };
    in
    rec {
      channelName = rhs'.channelName oder (lhs'.channelName oder "nixpkgs");
      system = rhs'.system oder (lhs'.system oder defaultSystem); # replace deaultSystem with x86_64-linux
      output = rhs'.output oder (lhs'.output oder "nixosConfigurations");
      builder = rhs'.builder oder (lhs'.builder oder channels.${channelName}.input.lib.nixosSystem);
      modules = rhs.modules ++ lhs.modules ++ sharedModules;
      extraArgs = sharedExtraArgs // lhs.extraArgs // rhs.extraArgs;
    };

  optionalAttrs = check: value: if check then value else { };

  otherArguments = builtins.removeAttrs args [
    "defaultSystem" # TODO: deprecated, remove
    "sharedExtraArgs"
    "inputs"
    "hosts"
    "hostDefaults"
    "channels"
    "channelsConfig"
    "self"
    "sharedModules"
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
      host = mergeHosts (validateHost hostDefaults) (validateHost host');
    in
    {
      name = host.output;
      value.${hostname} = host.builder {
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
            ];
          })
        ] ++ host.modules;
        extraArgs = { inherit inputs; } // host.extraArgs;
      };
    }
  );

  mapAttrs' = f: set:
    builtins.listToAttrs (map (attr: f attr set.${attr}) (builtins.attrNames set));

in
otherArguments

// eachSystem supportedSystems (system:
  let
    patchChannel = channel: patches:
      if patches == [ ] then channel else
      (import channel { inherit system; }).pkgs.applyPatches {
        name = "nixpkgs-patched-${channel.shortRev}";
        src = channel;
        patches = patches;
      };

    importChannel = name: value: import (patchChannel value.input (value.patches or [ ])) {
      inherit system;
      overlays = sharedOverlays ++ (if (value ? overlaysBuilder) then (value.overlaysBuilder pkgs) else [ ]);
      config = channelsConfig // (value.config or { });
    };

    pkgs = builtins.mapAttrs importChannel channels;

    optional = check: optionalAttrs (check != null);
  in
  { inherit pkgs; }
  // optional packagesBuilder { packages = packagesBuilder pkgs; }
  // optional defaultPackageBuilder { defaultPackage = defaultPackageBuilder pkgs; }
  // optional appsBuilder { apps = appsBuilder pkgs; }
  // optional defaultAppBuilder { defaultApp = defaultAppBuilder pkgs; }
  // optional devShellBuilder { devShell = devShellBuilder pkgs; }
  // optional checksBuilder { checks = checksBuilder pkgs; }
)
  # produces attrset in the shape of
  # { nixosConfigurations = {}; darwinConfigurations = {};  ... } 
  # according to profile.output or the default `nixosConfigurations`
  // mapAttrs' configurationBuilder hosts
