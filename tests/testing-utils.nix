{ nixpkgs }:

let
  str = it: if it == null then "null" else (toString it);
in
{
  # Options that keep Nix from complaining
  base-nixos = {
    boot.loader.grub.devices = [ "nodev" ];
    fileSystems."/" = { device = "test"; fsType = "ext4"; };
  };

  isEqual = a: b:
    if a == b
    then nixpkgs.runCommandNoCC "SUCCESS__${str a}__IS_EQUAL__${str b}" { } "echo success > $out"
    else nixpkgs.runCommandNoCC "FAILURE__${str a}__NOT_EQUAL__${str b}" { } "exit 0";

  hasKey = attrset: key:
    if attrset ? ${key}
    then nixpkgs.runCommandNoCC "SUCCESS__${str key}__EXISTS_IN_ATTRSET" { } "echo success > $out"
    else nixpkgs.runCommandNoCC "FAILURE__${str key}__DOES_NOT_EXISTS_IN_ATTRSET_SIZE_${str(nixpkgs.lib.length (builtins.attrNames attrset))}" { } "exit 0";
}
