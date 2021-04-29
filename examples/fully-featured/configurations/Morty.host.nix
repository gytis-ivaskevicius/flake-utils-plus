# auto-special args <streamName>ModulesPath for easy backporting of modules
{ unstableModulesPath, ... }: {

  imports = [ "${unstableModulesPath}/installer/cd-dvd/installation-cd-minimal-new-kernel.nix" ];
  disabledModules = [ "installer/cd-dvd/installation-cd-minimal-new-kernel.nix" ];

  boot.loader.grub.devices = [ "nodev" ];
}
