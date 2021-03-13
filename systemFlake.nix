{}:
{ self
, inputs
, defaultSystem ? "x86_64-linux"
, nixosProfiles ? { }
, pkgs ? { }
, pkgsConfig ? { }
, sharedModules ? [ ]
, sharedOverlays ? [ ]
, extraArgs ? { inherit inputs; }
, ...
}@args:


let
  otherArguments = builtins.removeAttrs args [
    "defaultSystem"
    "extraArgs"
    "inputs"
    "nixosProfiles"
    "pkgs"
    "pkgsConfig"
    "self"
    "sharedModules"
    "sharedOverlays"
  ];
in
otherArguments //
{

  pkgs = builtins.mapAttrs
    (name: value: import value.input {
      system = (if (value ? system) then value.system else defaultSystem);
      overlays = sharedOverlays;
      config = pkgsConfig // (if (value ? config) then value.config else { });
    })
    pkgs;

  nixosConfigurations = builtins.mapAttrs
    (name: value:
      let
        selectedNixpkgs = if (value ? nixpkgs) then value.nixpkgs else self.pkgs.nixpkgs;
      in
      inputs.nixpkgs.lib.nixosSystem (
        with selectedNixpkgs.lib;
        {
          system = selectedNixpkgs.system;
          modules = [
            {
              networking.hostName = name;
              nixpkgs = rec { pkgs = selectedNixpkgs; config = pkgs.config; };
              system.configurationRevision = mkIf (self ? rev) self.rev;

              nix.package = mkDefault selectedNixpkgs.nixFlakes;
            }
          ]
          ++ sharedModules
          ++ (optionals (value ? modules) value.modules);
          extraArgs = extraArgs // optionalAttrs (value ? extraArgs) value.extraArgs;
        }
      ))
    nixosProfiles;

}

