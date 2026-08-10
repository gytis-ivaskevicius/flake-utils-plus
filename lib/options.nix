{ lib, config, inputs, ... }:

let
  inherit (lib) mkIf filterAttrs mapAttrs' mkOption types;
  mkFalseOption = description: mkOption {
    inherit description;
    default = false;
    example = true;
    type = types.bool;
  };

  flakes = filterAttrs (name: value: value ? outputs) inputs;

  nixRegistry = builtins.mapAttrs
    (name: v: { flake = v; })
    flakes;

  cfg = config.nix;
in
{
  options.fup = {
    channel = {
      name = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "The flake-utils-plus channel name used for this host.";
      };
      input = mkOption {
        type = types.nullOr types.unspecified;
        default = null;
        internal = true;
        description = "The flake input used for this host's channel.";
      };
    };
  };

  options.nix = {
    generateNixPathFromInputs = mkFalseOption "Generate NIX_PATH from available inputs.";
    generateRegistryFromInputs = mkFalseOption "Generate Nix registry from available inputs.";
    linkInputs = mkFalseOption "Symlink inputs to /etc/nix/inputs.";
  };

  config = {
    assertions = [
      {
        assertion = !cfg.generateNixPathFromInputs || cfg.linkInputs;
        message = "When using 'nix.generateNixPathFromInputs' please make sure to set 'nix.linkInputs = true'";
      }
    ];

    nix.registry =
      if cfg.generateRegistryFromInputs
      then nixRegistry
      else { self.flake = flakes.self; };

    environment.etc = mkIf (cfg.linkInputs || cfg.generateNixPathFromInputs) (mapAttrs'
      (name: value: { name = "nix/inputs/${name}"; value = { source = value.outPath; }; })
      inputs);

    nix.nixPath = mkIf cfg.generateNixPathFromInputs [ "/etc/nix/inputs" ];
  };
}

