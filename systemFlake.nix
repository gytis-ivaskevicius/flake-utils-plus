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
  evalHostAttrs = let
    defaultHostAttrs' =
      { channelName ? "nixpkgs"
      , system ? defaultSystem # replace with x86_64-linux eventually
      , modules ? []
      , extraArgs ? {}
      }:
      {
        inherit channelName system;
        modules = modules  ++ sharedModules;
        extraArgs = extraArgs // sharedExtraArgs;
      };
    defaultHostsAttrs_ = defaultHostAttrs' defaultHostAttrs;
  in
    { channelName ? defaultHostAttrs_.channelName
    , system ? defaultHostAttrs_.system
    , modules ? []
    , extraArgs ? {}
    }:
    {
      inherit channelName system;
      modules = modules ++ defaultHostAttrs_.modules;
      extraArgs = extraArgs // defaultHostAttrs_.extraArgs;
    };

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

  nixosConfigurationBuilder = hostname: profile: 
    let hostAttrs = evalHostArgs profile; in
    # It would be nice to get `nixosSystem` reference from `selectedNixpkgs` but it is not possible at this moment
    inputs."${hostAttrs.channelName}".lib.nixosSystem (genericConfigurationBuilder hostname hostAttrs);

  getNixpkgs = profile: self.pkgs."${profile.system}"."${profile.channelName}";

  genericConfigurationBuilder = hostname: profile: (
    let selectedNixpkgs = getNixpkgs profile; in
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
      ++ profile.modules;
      extraArgs = { inherit inputs; } // profile.extraArgs;
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

