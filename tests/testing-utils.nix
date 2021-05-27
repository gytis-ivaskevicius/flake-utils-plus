{ nixpkgs }:

{
  # Options that keep Nix from complaining
  base-nixos = {
    boot.loader.grub.devices = [ "nodev" ];
    fileSystems."/" = { device = "test"; fsType = "ext4"; };
  };

  isEqual = a: b: let
    stringifyNull = s:
      if s == null then "-null-" else s;
  in
    if a == b
    then nixpkgs.runCommandNoCC "success-${stringifyNull a}-IS-EQUAL-${stringifyNull b}" { } "echo success > $out"
    else nixpkgs.runCommandNoCC "faliure-${stringifyNull a}-IS-NOT-EQUAL-${stringifyNull b}" { } "exit 1";

  hasKey = attrset: key:
    if attrset ? ${key}
    then nixpkgs.runCommandNoCC "success-${key}-exists-in-attrset" { } "echo success > $out"
    else nixpkgs.runCommandNoCC "faliure-key-${key}-does-not-exist-in-attrset" { } "exit 1";
}
