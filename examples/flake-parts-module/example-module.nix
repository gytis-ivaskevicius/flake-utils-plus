{ lib, pkgs, ... }: {
  environment.systemPackages = [ pkgs.hello ];
}
