{ flake-utils-plus }:
let

  modulesFromListExporter = paths:
    /**
      Synopsis: modulesFromListExporter _paths_

      paths:    [ <path> <path> ]

      Returns an attribute set of modules from a list of paths by converting
      the path's basename into the attribute key.

      Example:

      paths:    [ ./path/to/moduleA.nix ./path/to/moduleBfolder ]

      {
      moduleA = import ./path/to/moduleA.nix;
      moduleBfolder = import ./path/to/moduleBfolder;
      }

      **/

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

    genAttrs'
      (path: {
        name = removeSuffix ".nix" (baseNameOf path);
        value = import path;
      })
      paths;

in
modulesFromListExporter
