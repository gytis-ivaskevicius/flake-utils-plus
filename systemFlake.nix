{ flake-utils }:

{ self
, defaultSystem ? "x86_64-linux"
, sharedExtraArgs ? { inherit inputs; }
, supportedSystems ? flake-utils.lib.defaultSystems
, inputs
, nixosConfigurations ? { }
, darwinConfigurations ? { }
, darwinProfiles ? { }
, nixosProfiles ? { }
, channels ? { }
, channelsConfig ? { }
, sharedModules ? [ ]
, sharedOverlays ? [ ]

  # `Func` postfix is soon to be deprecated. Replaced with `Builder` instead
, packagesFunc ? null
, defaultPackageFunc ? null
, appsFunc ? null
, defaultAppFunc ? null
, devShellFunc ? null
, checksFunc ? null

, packagesBuilder ? packagesFunc
, defaultPackageBuilder ? defaultPackageFunc
, appsBuilder ? appsFunc
, defaultAppBuilder ? defaultAppFunc
, devShellBuilder ? devShellFunc
, checksBuilder ? checksFunc
, ...
}@args:

let
  otherArguments = builtins.removeAttrs args [
    "defaultSystem"
    "sharedExtraArgs"
    "inputs"
    "nixosProfiles"
    "channels"
    "channelsConfig"
    "self"
    "sharedModules"
    "sharedOverlays"

    # `Func` postfix is soon to be deprecated. Replaced with `Builder` instead
    "packagesFunc"
    "defaultPackageFunc"
    "appsFunc"
    "defaultAppFunc"
    "devShellFunc"
    "checksFunc"

    "packagesBuilder"
    "defaultPackageBuilder"
    "appsBuilder"
    "defaultAppBuilder"
    "devShellBuilder"
    "checksBuilder"
  ];

  darwinConfigurationBuilder  = name: value: (
    # It would be nice to get `darwinSystem` reference from `selectedNixpkgs` but it is not possible at this moment
    inputs.nixpkgs.lib.darwinSystem (genericConfigurationBuilder name value)
  );

  nixosConfigurationBuilder = name: value: (
    # It would be nice to get `nixosSystem` reference from `selectedNixpkgs` but it is not possible at this moment
    inputs.nixpkgs.lib.nixosSystem (genericConfigurationBuilder name value)
  );

  genericConfigurationBuilder = name: value: (
    let
      system = if (value ? system) then value.system else defaultSystem;
      channelName = if (value ? channelName) then value.channelName else "nixpkgs";
      selectedNixpkgs = self.pkgs."${system}"."${channelName}";
    in
    with selectedNixpkgs.lib; {
      inherit system;
      modules = [
        {
          networking.hostName = name;

          nixpkgs = {
            pkgs = selectedNixpkgs;
            config = selectedNixpkgs.config;
          };

          system.configurationRevision = mkIf (self ? rev) self.rev;
          nix.package = mkDefault selectedNixpkgs.nixUnstable;
        }
      ]
      ++ sharedModules
      ++ (optionals (value ? modules) value.modules);
      extraArgs = sharedExtraArgs // optionalAttrs (value ? extraArgs) value.extraArgs;
    }
  );
in
otherArguments

// flake-utils.lib.eachSystem supportedSystems (system:
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
      config = channelsConfig // (if (value ? config) then value.config else { });
    };

    pkgs = builtins.mapAttrs importChannel channels;

    optional = check: value: (if check != null then value else { });
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
  nixosConfigurations = nixosConfigurations // (builtins.mapAttrs nixosConfigurationBuilder nixosProfiles);
  darwinConfigurations = darwinConfigurations // (builtins.mapAttrs darwinConfigurationBuilder darwinProfiles);
}

