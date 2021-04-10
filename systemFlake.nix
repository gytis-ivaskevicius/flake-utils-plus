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
  validateHost = {
      channelName ? null
    , system ? null
    , modules ? []
    , extraArgs ? {}
  }: { inherit channelName system modules extraArgs; };

  mergeHosts = lhs: rhs:
  let
    # convoluted nix-kell, but clean(er) english-german below :-)
    _ = x: op: y: op x y;
    oder = lhs: rhs: if lhs != null then lhs else rhs;

    rhs' = { channelName = _ rhs.channelName; system = _ rhs.system; };
    lhs' = { channelName = _ lhs.channelName; system = _ lhs.system; };
  in 
  {
    channelName = rhs'.channelName oder (lhs'.channelName oder "nixpkgs") ;
    system = rhs'.system oder (lhs'.system oder defaultSystem) ; # replace deaultSystem with x86_64-linux
    modules = rhs.modules ++ lhs.modules ++ sharedModules;
    extraArgs = sharedExtraArgs // lhs.extraArgs // rhs.extraArgs;
  };

  optionalAttrs = check: value: if check then value else { };

  otherArguments = builtins.removeAttrs args [
    "defaultSystem" # TODO: deprecated, remove
    "sharedExtraArgs"
    "inputs"
    "nixosHosts"
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

  nixosConfigurationBuilder = hostname: host:
    let
      host' =
        mergeHosts (validateHost hostDefaults) (validateHost host);
    in
      # It would be nice to get `nixosSystem` reference from `selectedNixpkgs` but it is not possible at this moment
      inputs."${host'.channelName}".lib.nixosSystem
        (genericConfigurationBuilder hostname host');

  getNixpkgs = host: self.pkgs."${host.system}"."${host.channelName}";

  genericConfigurationBuilder = hostname: host: (
    let selectedNixpkgs = getNixpkgs host; in
    {
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
      ]
      ++ host.modules;
      extraArgs = { inherit inputs; } // host.extraArgs;
    }
  );
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

  // {
  nixosConfigurations = nixosConfigurations // (builtins.mapAttrs nixosConfigurationBuilder nixosHosts);
}

