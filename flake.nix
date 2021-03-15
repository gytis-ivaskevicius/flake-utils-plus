{
  description = "Pure Nix flake utility functions";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, flake-utils }: {
    lib =
      let
        mapAttrsToList = f: attrs:
          map (name: f name attrs.${name}) (builtins.attrNames attrs);
      in
      flake-utils.lib
      // rec {
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


