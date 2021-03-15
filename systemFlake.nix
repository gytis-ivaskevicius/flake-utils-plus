{ flake-utils }:

{ self
, defaultSystem ? "x86_64-linux"
, sharedExtraArgs ? { inherit inputs; }
, supportedSystems ? flake-utils.lib.defaultSystems
, inputs
, nixosConfigurations ? { }
, nixosProfiles ? { }
, channels ? { }
, channelsConfig ? { }
, sharedModules ? [ ]
, sharedOverlays ? [ ]

  # Very experimental
, packagesFunc ? null
, defaultPackageFunc ? null
, appsFunc ? null
, defaultAppFunc ? null
, devShellFunc ? null
, checksFunc ? null

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

    # Very experimental
    "packagesFunc"
    "defaultPackageFunc"
    "appsFunc"
    "defaultAppFunc"
    "devShellFunc"
    "checksFunc"
  ];

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
          nix.package = mkDefault selectedNixpkgs.nixFlakes;
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
    pkgs = builtins.mapAttrs
      (name: value: import value.input {
        inherit system;
        overlays = sharedOverlays ++ (if (value ? overlaysFunc) then (value.overlaysFunc pkgs) else [ ]);
        config = channelsConfig // (if (value ? config) then value.config else { });
      })
      channels;

    optional = check: value: (if check != null then value else { });
  in
  { inherit pkgs; }
  // optional packagesFunc { packages = packagesFunc pkgs; }
  // optional defaultPackageFunc { defaultPackage = defaultPackageFunc pkgs; }
  // optional appsFunc { apps = appsFunc pkgs; }
  // optional defaultAppFunc { defaultApp = defaultAppFunc pkgs; }
  // optional devShellFunc { devShell = devShellFunc pkgs; }
  // optional checksFunc { checks = checksFunc pkgs; }
)

  // {
  nixosConfigurations = nixosConfigurations // (builtins.mapAttrs nixosConfigurationBuilder nixosProfiles);
}

