{
  description = "Pure Nix flake utility functions";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, flake-utils }:
    let
      inherit (builtins) isList isAttrs mapAttrs;
      fupArgs = { flake-utils-plus = self; };

      systemFlake = import ./lib/systemFlake.nix fupArgs;
      modulesFromList = import ./lib/modulesFromList.nix fupArgs;
      fromOverlays = import ./lib/fromOverlays.nix fupArgs;
      internalOverlays = import ./lib/internalOverlays.nix fupArgs;
      overlay = import ./lib/overlay.nix;
    in
    rec {
      inherit overlay;

      # Deprecated in favor of 'nix.generateRegistryFromInputs = true;'
      nixosModules.saneFlakeDefaults = { nix.generateRegistryFromInputs = true; };

      devShell.x86_64-linux = import ./devShell.nix { system = "x86_64-linux"; };

      lib = flake-utils.lib // {
        # modulesFromList is deprecated, will be removed in future releases
        inherit systemFlake modulesFromList;

        exporters = {
          inherit modulesFromList fromOverlays internalOverlays;
        };

        repl = ./lib/repl.nix;

        # merge nested attribute sets and lists
        mergeAny = lhs: rhs:
          lhs // mapAttrs
            (name: value:
              if isAttrs value then lhs.${name} or { } // value
              else if isList value then lhs.${name} or [ ] ++ value
              else value
            )
            rhs;

        patchChannel = system: channel: patches:
          if patches == [ ] then channel else
          (import channel { inherit system; }).pkgs.applyPatches {
            name = "nixpkgs-patched-${channel.shortRev}";
            src = channel;
            patches = patches;
          };

      };
    };
}


