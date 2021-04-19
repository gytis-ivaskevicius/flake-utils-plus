{ lib, ... }: {
  boot.loader.grub.devices = [ "nodev" ];
  fileSystems."/" = { device = "test"; fsType = "ext4"; };
  patchedModule.test = lib.patchedFunction "test";
  nixpkgs.config.packageOverrides = pkgs: { };
}
