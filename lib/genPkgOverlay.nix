/**
  Synopsis: generate an overlay that includes a package from an input

  input: a flake input that has a `packages` or `defaultPackage` output
  pname: the name of the package to include.
  If the package isn't in the `packages` output,
  `defaultPackage` will be used, otherwise an
  error will be thrown when trying to use the package.

  Example:
  flake-utils-plus.mkFlake {
  sharedOverlays = [
  (flake-utils-plus.lib.genPkgOverlay neovim "neovim")
  # To use agenix's `defaultPackage`
  (flake-utils-plus.lib.genPkgOverlay agenix "")
  ];
  }
*/
input: pname:
# Returning an overlay
final: prev: {
  __dontExport = true;
  ${pname} = input.packages.${prev.system}.${pname}
    or input.defaultPackage.${prev.system};
}
