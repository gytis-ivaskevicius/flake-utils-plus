{ flake-utils-plus }: let

modulesFromListExporter =

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

    paths: genAttrs'
      (path: {
        name = removeSuffix ".nix" (baseNameOf path);
        value = import path;
      })
      paths;

in
modulesFromListExporter
