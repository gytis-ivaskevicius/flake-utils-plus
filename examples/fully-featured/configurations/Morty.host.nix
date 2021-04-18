{ ... }: {
  boot.loader.grub.devices = [ "nodev" ];
  fileSystems."/" = { device = "test"; fsType = "ext4"; };
}
