{ flake-utils-plus }:

let
  inherit (flake-utils-plus.lib.internal)
    genAttrs'
    hasFileAttr
    pathIsDirectory
    pathIsRegularFile
    peek
    rakeLeaves
    removeSuffix
    ;
  exportModules = args:
    /**
      Synopsis: exportModules _paths or modules_

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

    genAttrs'
      (arg:

        # a regular file to be imported
        if pathIsRegularFile arg then
          {
            name = removeSuffix ".nix" (baseNameOf arg);
            value = import arg;
          }

        # a directory to be recursively imported
        else if pathIsDirectory arg then
          rakeLeaves arg

        # a module function with a _file attr
        else if ((builtins.isFunction arg) && (hasFileAttr (peek arg))) then
          {
            name = removeSuffix ".toml" (removeSuffix ".nix" (baseNameOf (peek arg)._file));
            value = arg;
          }

        # panic: a module function without a _file attr
        else if ((builtins.isFunction arg) && (!(hasFileAttr (peek arg)))) then
          builtins.throw ''
            module function has no (required) _file argument key: ${builtins.trace (peek arg) "."}
          ''

        # a simple module with a _file attr
        else if (builtins.isAttrs arg) && (hasFileAttr arg) then
          {
            name = removeSuffix ".toml" (removeSuffix ".nix" (baseNameOf arg._file));
            value = arg;
          }

        # panic: a simple module with a _file attr
        else if (builtins.isAttrs arg) && (hasFileAttr arg) then
          builtins.throw ''
            simple module has no (required) _file argument key: ${builtins.trace arg "."}
          ''

        # panic: something else
        else
          builtins.throw ''
            either pass a path or a module with _file key to exportModules: ${builtins.trace arg "."}
          ''
      )
      args;

in
exportModules
