{ lib, config, inputs, ... }:

let
  inherit (lib) mkIf filterAttrs mapAttrsToList mapAttrs' mkOption types;
  mkFalseOption = description: mkOption {
    inherit description;
    default = false;
    example = true;
    type = types.bool;
  };

  flakes = filterAttrs (name: value: value ? outputs) inputs;
  flakesWithPkgs = filterAttrs (name: value: value.outputs ? legacyPackages || value.outputs ? packages) flakes;

  nixRegistry = builtins.mapAttrs
    (name: v: { flake = v; })
    flakes;
in
{
  options = {
    nix.generateNixPathFromInputs = mkFalseOption "Generate NIX_PATH available inputs.";
    nix.generateRegistryFromInputs = mkFalseOption "Generate Nix registry from available inputs.";
    nix.linkInputs = mkFalseOption "Symlink inputs to /etc/nix/inputs.";
  };

  config = {
    nix.registry =
      if config.nix.generateRegistryFromInputs
      then nixRegistry
      else { self.flake = flakes.self; };

    environment.etc = mkIf (config.nix.linkInputs || config.nix.generateNixPathFromInputs) (mapAttrs'
      (name: value: { name = "nix/inputs/${name}"; value = { source = value.outPath; }; })
      inputs);

    nix.nixPath = mkIf config.nix.generateNixPathFromInputs (mapAttrsToList
      (name: _: "${name}=/etc/nix/inputs/${name}")
      flakesWithPkgs);
  };
}

