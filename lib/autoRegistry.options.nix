{ lib, config, inputs, ... }:

let
  flakes = lib.filterAttrs (name: value: value ? outputs) inputs;

  nixRegistry = builtins.mapAttrs
    (name: v: { flake = v; })
    flakes;
in
{
  options.nix.generateRegistryFromInputs = lib.mkEnableOption "Generates Nix registry from available inputs.";

  config = {
    nix.registry =
      if config.nix.generateRegistryFromInputs
      then nixRegistry
      else { self.flake = flakes.self; };
  };

}
