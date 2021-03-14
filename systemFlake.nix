{ flake-utils }:

{ self
, defaultSystem ? "x86_64-linux"
, sharedExtraArgs ? { inherit inputs; }
, inputs
, nixosConfigurations ? { }
, nixosProfiles ? { }
, channels ? { }
, channelsConfig ? { }
, sharedModules ? [ ]
, sharedOverlays ? [ ]
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
  ];

  nixosConfigurationBuilder = name: value: (
    # It would be nice to get `nixosSystem` reference from `selectedNixpkgs` but it is not possible at this moment
    inputs.nixpkgs.lib.nixosSystem (genericConfigurationBuilder name value)
  );

  genericConfigurationBuilder = name: value: (
    let
      selectedNixpkgs = if (value ? nixpkgs) then value.nixpkgs else self.pkgs.nixpkgs;
    in
    with selectedNixpkgs.lib; {
      inherit (selectedNixpkgs) system;
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
otherArguments //
{

  pkgs = builtins.mapAttrs
    (name: value: import value.input {
      system = (if (value ? system) then value.system else defaultSystem);
      overlays = sharedOverlays ++ (if (value ? overlays) then value.overlays else [ ]);
      config = channelsConfig // (if (value ? config) then value.config else { });
    })
    channels;

  nixosConfigurations = nixosConfigurations // (builtins.mapAttrs nixosConfigurationBuilder nixosProfiles);

}

