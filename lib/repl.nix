let
  inherit (builtins) getFlake head match currentSystem;
  flake = getFlake "flake:self";
  hostname = head (match "([a-zA-Z0-9]+)\n" (builtins.readFile "/etc/hostname"));
  nixpkgs = flake.pkgs.${currentSystem}.nixpkgs;
in
{ inherit flake; }
// flake
// builtins
// flake.nixosConfigurations.${hostname} or {}
// (removeAttrs nixpkgs.lib [ "options" ])
  // (removeAttrs nixpkgs [ "config" ])
