let
  flake = builtins.getFlake "flake:self";
  hostname = builtins.head (builtins.match "([a-zA-Z0-9]+)\n" (builtins.readFile "/etc/hostname"));
  nixpkgs = import flake.inputs.nixpkgs { };
in
{ inherit flake; }
// flake
// builtins
// nixpkgs
// nixpkgs.lib
  // flake.nixosConfigurations.${hostname}
