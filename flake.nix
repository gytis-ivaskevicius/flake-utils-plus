{
  description = "Pure Nix flake utility functions";

  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.lib.url = "https://github.com/divnix/nixpkgs.lib";

  outputs = { self, flake-utils, lib }:
    let
      removeSuffix = suffix: str:
        let
          sufLen = builtins.stringLength suffix;
          sLen = builtins.stringLength str;
        in
        if sufLen <= sLen && suffix == builtins.substring (sLen - sufLen) sufLen str then
          builtins.substring 0 (sLen - sufLen) str
        else
          str;

      genAttrs' = func: values: builtins.listToAttrs (map func values);
    in
    rec {

      nixosModules.saneFlakeDefaults = import ./modules/saneFlakeDefaults.nix;

      lib = flake-utils.lib // {

        repl = ./repl.nix;
        systemFlake = import ./systemFlake.nix { flake-utils-plus = self; inherit lib; };

        modulesFromList = paths: genAttrs'
          (path: {
            name = removeSuffix ".nix" (baseNameOf path);
            value = import path;
          })
          paths;

      };
    };
}


