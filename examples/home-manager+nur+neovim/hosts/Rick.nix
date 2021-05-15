{ ... }: {
  # Root file system and bootloader is required for CI to build system configuration
  boot.loader.grub.devices = [ "nodev" ];
  fileSystems."/" = { device = "test"; fsType = "ext4"; };
}
