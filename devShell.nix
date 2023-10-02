{ system ? builtins.currentSystem }:
let
  # nixpkgs / devshell is only used for development. Don't add it to the flake.lock.
  nixpkgsGitRev = "15de3b878a1fab784ddeae4c33cbc56381748505";
  devshellGitRev = "cd4e2fda3150dd2f689caeac07b7f47df5197c31";

  nixpkgsSrc = fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/${nixpkgsGitRev}.tar.gz";
    sha256 = "1nb53mycxj3hqcxg1vwbz76rkbmzkp84jgljqv6q2rby5v9k8cwc";
  };

  devshellSrc = fetchTarball {
    url = "https://github.com/numtide/devshell/archive/${devshellGitRev}.tar.gz";
    sha256 = "02h3j2wqxsgf8sfl476q070ss86palxba48i497kh69nrvhqgz84";
  };

  pkgs = import nixpkgsSrc { inherit system; };
  devshell = import devshellSrc { inherit system; };

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
    {
      category = "dry-build";
      name = "build-darwin";
      command = "nix build ${rootDir}/examples/darwin#darwinConfigurations.Hostname1.system --no-write-lock-file --dry-run";
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
