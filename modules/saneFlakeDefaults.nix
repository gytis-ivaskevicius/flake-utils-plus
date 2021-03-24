{ lib, pkgs, inputs, ... }:

let
  flakes = lib.filterAttrs (name: value: value ? outputs) inputs;

  nixRegistry = builtins.mapAttrs
    (name: v: { flake = v; })
    flakes;
in {

  nix =  {
    extraOptions = "experimental-features = nix-command ca-references flakes";
    registry = nixRegistry;
    package = pkgs.nixUnstable;
  };

}
