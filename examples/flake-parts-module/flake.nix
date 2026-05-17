{
  description = "FUP concepts as a composable flake-parts module";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-parts.url = "github:hercules-ci/flake-parts";

    # Uncomment to test darwin:
    # nix-darwin.url = "github:LnL7/nix-darwin";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" ];

      # Import the FUP-as-flake-parts-module
      imports = [ ./fup-module.nix ];

      # ====================================================================
      # FUP-style configuration via flake-parts module options
      # ====================================================================
      fup = {
        # 1. MULTI-CHANNEL — declare multiple nixpkgs versions
        channels = {
          nixpkgs = {
            input = inputs.nixpkgs;
            config.allowUnfree = false;
            # Per-channel overlays: receives all channel pkgs for cross-refs
            overlaysBuilder = allPkgs: [
              (final: prev: {
                inherit (allPkgs.stable) hello;
              })
            ];
          };

          stable = {
            input = inputs.nixpkgs-stable;
            config.allowUnfree = true;
          };
        };

        # 2. SHARED OVERLAYS — applied to every channel
        sharedOverlays = [
          (final: prev: {
            hello-fup = final.hello.overrideAttrs (old: {
              pname = "${old.pname}-fup";
            });
          })
        ];

        # 3. HOST ABSTRACTION — declarative machines
        hostDefaults = {
          system = "x86_64-linux";
          channelName = "nixpkgs";
        };

        hosts = {
          # Reverse-DNS: "com.example.server" → hostname: "server", domain: "example.com"
          "com.example.server" = {
            system = "x86_64-linux";
            modules = [
              ({ pkgs, ... }: {
                environment.systemPackages = [ pkgs.hello-fup ];
              })
            ];
          };

          "com.example.laptop" = {
            system = "x86_64-linux";
            channelName = "stable";
          };
        };

        # 4. AUTO-REGISTRY
        autoRegistry = true;
        autoNixPath = true;
      };

      # ── Everything else works normally alongside fup options ──
      perSystem = { pkgs, fupChannels, system, ... }: {
        devShells.default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [ nix nixpkgs-fmt ];
          shellHook = ''
            echo "Channels available: ${toString (builtins.attrNames fupChannels)}"
          '';
        };

        packages.hello-from-stable = fupChannels.stable.hello;

        apps.show-channels = {
          type = "app";
          program = toString (pkgs.writeShellScript "show-channels" ''
            echo "Channel versions for ${system}:"
            echo "  nixpkgs: ${fupChannels.nixpkgs.lib.version or "N/A"}"
            echo "  stable:  ${fupChannels.stable.lib.version or "N/A"}"
          '');
        };
      };
    };
}
