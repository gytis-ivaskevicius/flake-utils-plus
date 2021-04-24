let
  flake = builtins.getFlake "flake:self";
  hostname = builtins.head (builtins.match "([a-zA-Z0-9]+)\n" (builtins.readFile "/etc/hostname"));
  nixpkgs = flake.pkgs.${builtins.currentSystem}.nixpkgs;
in
{ inherit flake; }
// flake
// builtins
// flake.nixosConfigurations.${hostname}
// nixpkgs.lib
  // (builtins.removeAttrs nixpkgs [ "config" ])
