{
  description = "Pure Nix flake utility functions";
  outputs = { self }: {
    lib =
      let
        mapAttrsToList = f: attrs:
          map (name: f name attrs.${name}) (builtins.attrNames attrs);
      in
      rec {
        systemFlake = import ./systemFlake.nix { };

        nixPathFromInputs = inputs: mapAttrsToList (name: _: "${name}=${inputs.${name}}") inputs;

        nixRegistryFromInputs = inputs: builtins.mapAttrs (name: v: { flake = v; }) inputs;

        nixDefaultsFromInputs = inputs: {
          extraOptions = "experimental-features = nix-command flakes";
          nixPath = nixPathFromInputs inputs;
          registry = nixRegistryFromInputs inputs;
        };

      };
  };
}


