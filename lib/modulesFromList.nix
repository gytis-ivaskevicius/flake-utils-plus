{ flake-utils-plus }:
let

  modulesFromListExporter = args:
    /**
      Synopsis: modulesFromListExporter _paths or modules_

      paths:    [ <path> <module> ]

      Returns an attribute set of modules from a list of paths or modules by converting
      the path's basename / the module's _file attribute's basename into the attribute key.

      Example:

      paths:    [ ./path/to/moduleA.nix { _file = ./path/to/moduleBfolder; ... } ]

      {
      moduleA = import ./path/to/moduleA.nix;
      moduleBfolder = { _file = ./path/to/moduleBfolder; ... }
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

      hasFileAttr = o: builtins.hasAttr "_file" o;
      peek = f: f (builtins.functionArgs f);

    in

    genAttrs'
      (arg:

        # a regular path to be imported
        if builtins.isPath arg then
          {
            name = removeSuffix ".nix" (baseNameOf arg);
            value = import arg;
          }

        # a module function with a _file attr
        else if ((builtins.isFunction arg) && (hasFileAttr (peek args))) then
          {
            name = removeSuffix ".toml" (removeSuffix ".nix" (baseNameOf (peek arg)._file));
            value = arg;
          }

        # a module with a _file attr
        else if (hasFileAttr arg) then
          {
            name = removeSuffix ".toml" (removeSuffix ".nix" (baseNameOf arg._file));
            value = arg;
          }

        # panic: something else
        else
          builtins.throw "either pass a path or a module with _file key to modulesFromListExporter"
      )
      args;

in
modulesFromListExporter
