{ flake-utils-plus }:

{ self
, defaultSystem ? "x86_64-linux" # will be deprecated soon use defaultHostAttrs.system instead
, supportedSystems ? flake-utils-plus.lib.defaultSystems
, inputs

, nixosConfigurations ? { }
, sharedExtraArgs ? { }
, defaultHostAttrs ? { }
, nixosProfiles ? { } # will be deprecated soon, use nixosHosts, instead.
, nixosHosts ? nixosProfiles
, channels ? { }
, channelsConfig ? { }
, sharedModules ? [ ]
, sharedOverlays ? [ ]

, packagesBuilder ? null
, defaultPackageBuilder ? null
, appsBuilder ? null
, defaultAppBuilder ? null
, devShellBuilder ? null
, checksBuilder ? null
, ...
}@args:

let
  # ensure for that all expected, but no extra attrs are present
  validateHostAttrs = {
      channelName ? null
    , system ? null
    , modules ? []
    , extraArgs ? {}
  }: { inherit channelName system modules extraArgs; };

  inherit (flake-utils-plus.lib) eachSystem;

  optionalAttrs = check: value: if check then value else { };

  otherArguments = builtins.removeAttrs args [
    "defaultSystem" # TODO: deprecated, remove
    "sharedExtraArgs"
    "inputs"
    "nixosHosts"
    "defaultHostAttrs"
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

  mergeHostAttrs = defaultAttrs: attrs: let
    # convoluted nix-kell, but clean(er) english-german below :-)
    _ = x: op: y: op x y;
    oder = lhs: rhs: if lhs != null then lhs else rhs;

    attrs.channelName' = _ attrs.channelName;
    defaultAttrs.channelName' = _ defaultAttrs.channelName;
    attrs.system' = _ attrs.system;
    defaultAttrs.system' = _ defaultAttrs.system;
  in
  {
    channelName = attrs.channelName' oder (defaultAttrs.channelName' oder "nixpkgs") ;
    system = attrs.system' oder (defaultAttrs.system' oder defaultSystem) ; # replace deaultSystem with x86_64-linux
    modules = modules ++ defaultAttrs.modules ++ sharedModules;
    extraArgs = sharedExtraArgs // defaultAttrs.extraArgs // extraArgs;
  };

  nixosConfigurationBuilder = hostname: hostAttrs: 
    let hostAttrs = mergeHostAttrs (validateHostAttrs defaultHostAttrs) (validateHostAttrs profile); in
    # It would be nice to get `nixosSystem` reference from `selectedNixpkgs` but it is not possible at this moment
    inputs."${hostAttrs.channelName}".lib.nixosSystem (genericConfigurationBuilder hostname hostAttrs);

  getNixpkgs = hostAttrs: self.pkgs."${hostAttrs.system}"."${hostAttrs.channelName}";

  genericConfigurationBuilder = hostname: hostAttrs: (
    let selectedNixpkgs = getNixpkgs hostAttrs; in
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
      ++ hostAttrs.modules;
      extraArgs = { inherit inputs; } // hostAttrs.extraArgs;
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

