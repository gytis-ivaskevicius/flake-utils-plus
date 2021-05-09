{ system ? builtins.currentSystem }:
let
  # nixpkgs / devshell is only used for development. Don't add it to the flake.lock.
  nixpkgsGitRev = "5268ee2ebacbc73875be42d71e60c2b5c1b5a1c7";
  devshellGitRev = "709fe4d04a9101c9d224ad83f73416dce71baf21";

  nixpkgsSrc = fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/${nixpkgsGitRev}.tar.gz";
    sha256 = "080fvmg0i6z01h6adddfrjp1bbbjhhqk32ks6ch9gv689645ccfq";
  };

  devshellSrc = fetchTarball {
    url = "https://github.com/numtide/devshell/archive/${devshellGitRev}.tar.gz";
    sha256 = "1px9cqfshfqs1b7ypyxch3s3ymr4xgycy1krrcg7b97rmmszvsqr";
  };

  pkgs = import nixpkgsSrc { inherit system; };
  devshell = import devshellSrc { inherit system pkgs; };

  withCategory = category: attrset: attrset // { inherit category; };
  util = withCategory "utils";

  test = name: withCategory "tests" {
    name = "check-${name}";
    help = "Checks ${name} testcases";
    command = "cd $DEVSHELL_ROOT/tests/${name} && nix flake show && nix flake check";
  };

  dry-nixos-build = example: host: withCategory "dry-build" {
    name = "build-${example}-${host}";
    command = "cd $DEVSHELL_ROOT/examples/${example} && nix flake show && nix build .#nixosConfigurations.${host}.config.system.build.toplevel --dry-run";
  };

in
devshell.mkShell {
  name = "flake-utils-plus";
  packages = with pkgs;[
    fd
    nixpkgs-fmt
  ];

  commands = [
    {
      command = "git rm -f $DEVSHELL_ROOT/tests/*/flake.lock ; git rm -f $DEVSHELL_ROOT/examples/*/flake.lock";
      help = "Remove all lock files";
      name = "rm-locks";
    }
    {
      name = "fmt";
      help = "Check Nix formatting";
      command = "nixpkgs-fmt \${@} $DEVSHELL_ROOT";
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
    (dry-nixos-build "minimal-multichannel" "Hostname1")
    (dry-nixos-build "minimal-multichannel" "Hostname2")
    (dry-nixos-build "home-manager+nur+neovim" "Rick")

  ];

}
