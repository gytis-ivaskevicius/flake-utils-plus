{ flakePath ? "flake:self", hostnamePath ? "/etc/hostname" }:

let
  inherit (builtins) getFlake head match currentSystem readFile pathExists;
  flake = getFlake (toString flakePath);
  hostname = if pathExists hostnamePath then head (match "([a-zA-Z0-9]+)\n" (readFile hostnamePath)) else "";

  nixpkgsFromInputsPath = flake.inputs.nixpkgs.outPath or "";
  nixpkgs = flake.pkgs.${currentSystem}.nixpkgs or (if nixpkgsFromInputsPath != "" then import nixpkgsFromInputsPath { } else { });

  nixpkgsOutput = (removeAttrs (nixpkgs // nixpkgs.lib or { }) [ "options" "config" ]);
in
{ inherit flake; }
// flake
// builtins
// (flake.nixosConfigurations or { })
// flake.nixosConfigurations.${builtins.trace hostname hostname} or { }
  // nixpkgsOutput
