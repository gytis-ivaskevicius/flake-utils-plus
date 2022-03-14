{
  description = "Pure Nix flake utility functions";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, flake-utils }:
    let
      inherit (builtins) isList isAttrs mapAttrs;
      fupArgs = { flake-utils-plus = self; };

      mkFlake = import ./lib/mkFlake.nix fupArgs;
      exportModules = import ./lib/exportModules.nix fupArgs;
      exportOverlays = import ./lib/exportOverlays.nix fupArgs;
      exportPackages = import ./lib/exportPackages.nix fupArgs;
      genPkgOverlay = import ./lib/genPkgOverlay.nix;
      internal-functions = import ./lib/internal-functions.nix;
      overlay = import ./lib/overlay.nix;
    in
    rec {
      inherit overlay;

      nixosModules.autoGenFromInputs = import ./lib/options.nix;
      darwinModules.autoGenFromInputs = import ./lib/options.nix;

      devShell.x86_64-linux = import ./devShell.nix { system = "x86_64-linux"; };

      lib = flake-utils.lib // {
        inherit mkFlake exportModules exportOverlays exportPackages genPkgOverlay;

        # DO NOT USE - subject to change without notice
        internal = internal-functions;

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
            name = if channel ? shortRev then "nixpkgs-patched-${channel.shortRev}" else "nixpkgs-patched";
            src = channel;
            patches = patches;
          };

      };
    };
}


