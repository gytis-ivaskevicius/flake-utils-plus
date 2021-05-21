{ flake-utils-plus }:
let

  modulesFromListExporter = args:
    /**
      Synopsis: modulesFromListExporter _paths_

      paths:    [ <path> <path> ] or { paths = [ ]; _import = <function>; }

      Returns an attribute set of modules from a list of paths by converting
      the path's basename into the attribute key.

      Optionally, an attrset can be passed containing `paths` and `_import`
      to control how paths get imported

      Example:

      paths:    [ ./path/to/moduleA.nix ./path/to/moduleBfolder ]

      {
      moduleA = import ./path/to/moduleA.nix;
      moduleBfolder = import ./path/to/moduleBfolder;
      }

      **/

    let

      # To allow for the default to just pass a list
      # or pass an attrset with `paths` and `_import`
      paths = args.paths or args;
      _import = args._import or import;

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
        name = removeSuffix ".toml" (removeSuffix ".nix" (baseNameOf path));
        value = _import path;
      })
      paths;

in
modulesFromListExporter
