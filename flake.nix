{
  description = "Pure Nix flake utility functions";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, flake-utils }: {

    nixosModules.saneFlakeDefaults = import ./modules/saneFlakeDefaults.nix;

    lib =
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
        mapAttrsToList = f: attrs:
          map (name: f name attrs.${name}) (builtins.attrNames attrs);
      in
      flake-utils.lib
      // rec {

        modulesFromList = paths:
          genAttrs'
            (path: {
              name = removeSuffix ".nix" (baseNameOf path);
              value = import path;
            })
            paths;

        modulesFromDir = dir:
          modulesFromList (mapAttrsToList (name: value: name) (builtins.readDir dir));

        systemFlake = import ./systemFlake.nix { inherit flake-utils; };

        nixPathFromInputs = inputs:
          mapAttrsToList (name: _: "${name}=${inputs.${name}}") inputs;

        nixRegistryFromInputs = inputs:
          builtins.mapAttrs (name: v: { flake = v; }) inputs;

        nixDefaultsFromInputs = inputs: {
          extraOptions = "experimental-features = nix-command ca-references flakes";
          nixPath = nixPathFromInputs inputs;
          registry = nixRegistryFromInputs inputs;
        };

      };
  };
}


