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
      in
      flake-utils.lib
      // {

        replApp = pkgs: flake-utils.lib.mkApp {
          drv = pkgs.writeShellScriptBin "repl" ''
            ${pkgs.nixUnstable}/bin/nix repl ${./repl.nix}
          '';
        };

        modulesFromList = paths:
          genAttrs'
            (path: {
              name = removeSuffix ".nix" (baseNameOf path);
              value = import path;
            })
            paths;

        systemFlake = import ./systemFlake.nix { inherit flake-utils; };

      };
  };
}


