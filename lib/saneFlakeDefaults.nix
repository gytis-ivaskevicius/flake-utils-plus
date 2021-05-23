{ lib, pkgs, inputs, ... }:

let
  flakes = lib.filterAttrs (name: value: value ? outputs) inputs;

  nixRegistry = builtins.mapAttrs
    (name: v: { flake = v; })
    flakes;
in
{

  nix.registry = nixRegistry;

}
