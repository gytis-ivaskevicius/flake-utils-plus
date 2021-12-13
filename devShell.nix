{ system ? builtins.currentSystem }:
let
  # nixpkgs / devshell is only used for development. Don't add it to the flake.lock.
  nixpkgsGitRev = "1a551cf64a7e0be8667f9d6987d2b563a6ea4081";
  devshellGitRev = "0e56ef21ba1a717169953122c7415fa6a8cd2618";

  nixpkgsSrc = fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/${nixpkgsGitRev}.tar.gz";
    sha256 = "0p63g88j3cnigzyr0qgbpsh7y5y5rgikqhhhbnnr5cdhl5qb9zpx";
  };

  devshellSrc = fetchTarball {
    url = "https://github.com/numtide/devshell/archive/${devshellGitRev}.tar.gz";
    sha256 = "1g3aadlccd7c0ypycnirmvmwdx4w9h1gifzd7mchjsmwkd3ii3v5";
  };

  pkgs = import nixpkgsSrc { inherit system; };
  devshell = import devshellSrc { inherit system pkgs; };

  withCategory = category: attrset: attrset // { inherit category; };
  util = withCategory "utils";

  rootDir = "$PRJ_ROOT";

  test = name: withCategory "tests" {
    name = "check-${name}";
    help = "Checks ${name} testcases";
    command = ''
      set -e
      echo -e "\n\n##### Building ${name}\n"
      cd ${rootDir}/tests/${name}
      nix flake show --allow-import-from-derivation --no-write-lock-file "$@"
      nix flake check --no-write-lock-file "$@"
    '';
  };

  dry-nixos-build = example: host: withCategory "dry-build" {
    name = "build-${example}-${host}";
    command = ''
      set -e
      echo -e "\n\n##### Building ${example}-${host}\n"
      cd ${rootDir}/examples/${example}
      nix flake show --no-write-lock-file "$@"
      nix build .#nixosConfigurations.${host}.config.system.build.toplevel --no-write-lock-file --no-link "$@"
    '';
  };

in
devshell.mkShell {
  name = "flake-utils-plus";
  packages = with pkgs; [
    fd
    nixpkgs-fmt
  ];

  commands = [
    {
      command = "git rm --ignore-unmatch -f ${rootDir}/{tests,examples}/*/flake.lock";
      help = "Remove all lock files";
      name = "rm-locks";
    }
    {
      name = "fmt";
      help = "Check Nix formatting";
      command = "nixpkgs-fmt \${@} ${rootDir}";
    }
    {
      name = "evalnix";
      help = "Check Nix parsing";
      command = "fd --extension nix --exec nix-instantiate --parse --quiet {} >/dev/null";
    }

    (test "channel-patching")
    (test "derivation-outputs")
    (test "hosts-config")
    (test "overlays-flow")
    (test "all" // { command = "check-channel-patching && check-derivation-outputs && check-hosts-config && check-overlays-flow"; })

    (dry-nixos-build "minimal-multichannel" "Hostname1")
    (dry-nixos-build "minimal-multichannel" "Hostname2")
    (dry-nixos-build "home-manager+nur+neovim" "Rick")
    (dry-nixos-build "exporters" "Morty")
    (withCategory "dry-build" { name = "build-all"; command = "build-exporters-Morty && build-home-manager+nur+neovim-Rick && build-minimal-multichannel-Hostname1 && build-minimal-multichannel-Hostname2"; })

  ];

}
