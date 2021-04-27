{
  description = "Pure Nix flake utility functions";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, flake-utils }:
    let
      inherit (builtins) isList isAttrs mapAttrs;
      fupArgs = { flake-utils-plus = self; };
      systemFlake = import ./systemFlake.nix fupArgs;
      packagesFromOverlaysBuilderConstructor = import ./packagesFromOverlaysBuilderConstructor.nix fupArgs;
      overlaysFromChannelsExporter = import ./overlaysFromChannelsExporter.nix fupArgs;
      modulesFromList = import ./moduleFromListExporter.nix fupArgs;
    in
    rec {

      nixosModules.saneFlakeDefaults = import ./modules/saneFlakeDefaults.nix;

      devShell.x86_64-linux = import ./shell.nix { system = "x86_64-linux"; };

      lib = flake-utils.lib // {
        # modulesFromList is deprecated, will be removed in future releases
        inherit systemFlake modulesFromList;

        builder = {
          inherit packagesFromOverlaysBuilderConstructor;
        };

        exporter = {
          inherit overlaysFromChannelsExporter modulesFromList;
        };

        repl = ./repl.nix;

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


