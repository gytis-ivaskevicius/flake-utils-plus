{ nixpkgs }:

{
  # Options that keep Nix from complaining
  base-nixos = {
    boot.loader.grub.devices = [ "nodev" ];
    fileSystems."/" = { device = "test"; fsType = "ext4"; };
  };

  isEqual = a: b:
    if a == b
    then nixpkgs.runCommandNoCC "success-${a}-IS-EQUAL-${b}" { } "echo success > $out"
    else nixpkgs.runCommandNoCC "falure-${a}-IS-NOT-EQUAL-${b}" { } "exit 1";

  hasKey = attrset: key:
    if attrset ? ${key}
    then nixpkgs.runCommandNoCC "success-${key}-exists-in-attrset" { } "echo success > $out"
    else nixpkgs.runCommandNoCC "falure-key-${key}-does-not-exist-in-attrset" { } "exit 1";
}
