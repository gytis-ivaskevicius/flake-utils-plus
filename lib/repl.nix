{ flakePath ? null, hostnamePath ? "/etc/hostname" }:

let
  inherit (builtins) getFlake head match currentSystem readFile pathExists filter fromJSON;
  selfFlake = filter (it: it.from.id == "self") (fromJSON (readFile /etc/nix/registry.json)).flakes;
  flakePath' =
    if flakePath != null
    then flakePath
    else if selfFlake != []
    then (head selfFlake).to.path
    else "/etc/nixos";

  flake = getFlake (toString flakePath');
  hostname = if pathExists hostnamePath then head (match "([a-zA-Z0-9]+)\n" (readFile hostnamePath)) else "";

  nixpkgsFromInputsPath = flake.inputs.nixpkgs.outPath or "";
  nixpkgs = flake.pkgs.${currentSystem}.nixpkgs or (if nixpkgsFromInputsPath != "" then import nixpkgsFromInputsPath { } else { });

  nixpkgsOutput = (removeAttrs (nixpkgs // nixpkgs.lib or { }) [ "options" "config" ]);
in
{ inherit flake; }
// flake
// builtins
// (flake.nixosConfigurations or { })
// flake.nixosConfigurations.${hostname} or { }
  // nixpkgsOutput
