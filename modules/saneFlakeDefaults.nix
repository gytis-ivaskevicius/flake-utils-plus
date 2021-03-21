{ lib, pkgs, inputs, ... }:

let
  flakes = lib.filterAttrs (name: value: value ? outputs) inputs;

  nixPath = lib.mapAttrsToList
    (name: _: "${name}=${inputs.${name}}")
    flakes;

  nixRegistry = builtins.mapAttrs
    (name: v: { flake = v; })
    flakes;
in {

  nix =  {
    extraOptions = "experimental-features = nix-command ca-references flakes";
    nixPath = nixPath;
    registry = nixRegistry;
    package = pkgs.nixUnstable;
  };

}
