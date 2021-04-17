{ lib, pkgs, config, ... }: {
  boot.loader.grub.devices = [ "nodev" ];
  fileSystems."/".device = "/dev/disk/by-label/Two";
}
