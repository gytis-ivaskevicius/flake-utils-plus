{ system ? builtins.currentSystem }:
let
  # nixpkgs / devshell is only used for development. Don't add it to the flake.lock.
  nixpkgsGitRev = "82d05e980543e1703cbfd3b5ccd1fdcd4b0f1f00";
  devshellGitRev = "26f25a12265f030917358a9632cd600b51af1d97";

  nixpkgsSrc = fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/${nixpkgsGitRev}.tar.gz";
    sha256 = "02yqgivv8kxksv7n6vmh22qxprlfjh4rfkgf98w46nssq5ahdb1q";
  };

  devshellSrc = fetchTarball {
    url = "https://github.com/numtide/devshell/archive/${devshellGitRev}.tar.gz";
    sha256 = "sha256:0f6fph5gahm2bmzd399mba6b0h6wp6i1v3gryfmgwp0as7mwqpj7";
  };

  pkgs = import nixpkgsSrc { inherit system; };
  devshell = import devshellSrc { inherit system pkgs; };

  withCategory = category: attrset: attrset // { inherit category; };
  util = withCategory "utils";

  test = name: withCategory "tests" {
    name = "check-${name}";
    help = "Checks ${name} testcases";
    command = ''
      set -e
      echo -e "\n\n##### Building ${name}\n"
      cd $DEVSHELL_ROOT/tests/${name}
      nix flake show --no-write-lock-file "$@"
      nix flake check --no-write-lock-file "$@"
    '';
  };

  dry-nixos-build = example: host: withCategory "dry-build" {
    name = "build-${example}-${host}";
    command = ''
      set -e
      echo -e "\n\n##### Building ${example}-${host}\n"
      cd $DEVSHELL_ROOT/examples/${example}
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
      command = "git rm --ignore-unmatch -f $DEVSHELL_ROOT/{tests,examples}/*/flake.lock";
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

    (test "derivation-outputs")
    (test "derivation-outputs-old")
    (test "hosts-config")
    (test "overlays-flow")
    (test "all" // { command = "check-derivation-outputs && check-derivation-outputs-old && check-hosts-config && check-overlays-flow"; })

    (dry-nixos-build "minimal-multichannel" "Hostname1")
    (dry-nixos-build "minimal-multichannel" "Hostname2")
    (dry-nixos-build "home-manager+nur+neovim" "Rick")
    (dry-nixos-build "exporters" "Morty")
    (withCategory "dry-build" { name = "build-all"; command = "build-exporters-Morty && build-home-manager+nur+neovim-Rick && build-minimal-multichannel-Hostname1 && build-minimal-multichannel-Hostname2"; })

  ];

}
