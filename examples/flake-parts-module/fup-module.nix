{ config, lib, flake-parts-lib, self, inputs, ... }:

let
  inherit (lib)
    types mkOption mkIf mkDefault
    mapAttrs mapAttrsToList filterAttrs optionalAttrs
    foldl' recursiveUpdate unique elem
    concatStringsSep head tail removeSuffix;

  inherit (builtins)
    attrNames attrValues listToAttrs removeAttrs
    concatMap isString filter genList elemAt
    length toString baseNameOf;

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Detect whether an input looks like nixpkgs (has x86_64-linux nix).
  isNixpkgsLike = name: value:
    value ? legacyPackages
    && value.legacyPackages ? x86_64-linux
    && value.legacyPackages.x86_64-linux ? nix;

  # Reverse a list.
  reverseList = xs:
    let l = length xs; in genList (n: elemAt xs (l - n - 1)) l;

  # Partition a dotted name into segments.
  splitLabels = dotted:
    filter isString (builtins.split "\\." dotted);

  # Extract hostname from reverse-DNS (e.g. "com.example.mybox" -> "mybox").
  hostnameFromReverseDNS = reverseDomain:
    head (reverseList (splitLabels reverseDomain));

  # Extract domain from reverse-DNS (e.g. "com.example.mybox" -> "example.com").
  domainFromReverseDNS = reverseDomain:
    let
      labels = reverseList (splitLabels reverseDomain);
      domainLabels = tail labels;
    in
    if domainLabels == [ ] then null
    else concatStringsSep "." domainLabels;

  # Generate a NixOS module fragment for registry / nixPath.
  mkRegistryModule = { autoRegistry, autoNixPath }:
    { lib, ... }:
    let cfg = autoRegistry; nixPathCfg = autoNixPath; in
    {
      config.nix = {
        registry = mkIf cfg
          (mapAttrs (name: v: { flake = v; })
            (filterAttrs (_: v: v ? outputs) inputs));
        nixPath = mkIf nixPathCfg
          (mkDefault [ "/etc/nix/inputs" ]);
      };
    };

  # Merge a raw host declaration with hostDefaults.
  resolveHost = name: host: hostDefaults:
    let d = hostDefaults; in
    {
      system = if host.system != "" then host.system else d.system;
      channelName = if host.channelName != "" then host.channelName else d.channelName;
      output = if host.output != "" then host.output else d.output;
      modules = host.modules;
      extraArgs = host.extraArgs;
      specialArgs = host.specialArgs;
      builder =
        if host.builder != null then host.builder
        else d.builder;
    };

in
{
  options.fup = {
    channels = mkOption {
      description = "Nixpkgs channels. Each key is a channel name.";
      type = types.lazyAttrsOf (types.submodule {
        options = {
          input = mkOption {
            type = types.raw;
            description = "The nixpkgs flake input.";
          };
          config = mkOption {
            type = types.attrsOf types.unspecified;
            default = { };
            description = "nixpkgs config (allowUnfree, etc.).";
          };
          overlaysBuilder = mkOption {
            type = types.nullOr (types.functionTo (types.listOf types.raw));
            default = null;
            description = ''
              Function: (allChannelPkgs) -> [ overlay ].
              Receives every channel's evaluated pkgs for cross-channel references.
            '';
          };
        };
      });
      default = { };
      example = {
        nixpkgs = { input = "nixpkgs"; };
        unstable = { input = "nixpkgs-unstable"; unstable.config.allowUnfree = true; };
      };
    };

    sharedOverlays = mkOption {
      type = types.listOf types.raw;
      default = [ ];
      description = "Overlays applied to every channel.";
    };

    channelsConfig = mkOption {
      type = types.attrsOf types.unspecified;
      default = { };
      description = "Default nixpkgs config for all channels.";
    };

    hostDefaults = mkOption {
      description = "Default host configuration applied to every host.";
      type = types.submodule {
        options = {
          system = mkOption { type = types.str; default = "x86_64-linux"; };
          channelName = mkOption { type = types.str; default = "nixpkgs"; };
          output = mkOption { type = types.str; default = "nixosConfigurations"; };
          builder = mkOption { type = types.nullOr types.raw; default = null; };
          modules = mkOption { type = types.listOf types.raw; default = [ ]; };
          extraArgs = mkOption { type = types.attrsOf types.unspecified; default = { }; };
          specialArgs = mkOption { type = types.attrsOf types.unspecified; default = { }; };
        };
      };
      default = { };
    };

    hosts = mkOption {
      description = ''
        Machine declarations keyed by reverse-DNS name, e.g. "com.example.mybox".
      '';
      type = types.lazyAttrsOf (types.submodule {
        options = {
          system = mkOption { type = types.str; default = ""; };
          channelName = mkOption { type = types.str; default = ""; };
          output = mkOption { type = types.str; default = ""; };
          builder = mkOption { type = types.nullOr types.raw; default = null; };
          modules = mkOption { type = types.listOf types.raw; default = [ ]; };
          extraArgs = mkOption { type = types.attrsOf types.unspecified; default = { }; };
          specialArgs = mkOption { type = types.attrsOf types.unspecified; default = { }; };
        };
      });
      default = { };
    };

    autoDetectChannels = mkOption {
      type = types.bool;
      default = false;
      description = "Auto-detect nixpkgs-like inputs as channels when `channels` is empty.";
    };

    autoRegistry = mkOption {
      type = types.bool;
      default = false;
      description = "Generate nix.registry from flake inputs (added to host modules).";
    };

    autoNixPath = mkOption {
      type = types.bool;
      default = false;
      description = "Generate nix.nixPath from flake inputs (added to host modules).";
    };

    exportOverlays = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Export per-channel overlays as namespaced flake overlays.
        Each package defined in a channel's overlays is exported as
        "channelName/packageName" under flake.overlays.
      '';
    };

    exportPackages = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Export overlay-defined packages as flake packages per system.
        Only derivations whose meta.platforms includes the current system are exported.
      '';
    };

    nixosModules = mkOption {
      type = types.listOf types.path;
      default = [ ];
      description = ''
        Paths to NixOS modules to export as flake.nixosModules,
        keyed by their basename (without .nix extension).
      '';
    };
  };

  config =
    let
      cfg = config.fup;

      # -----------------------------------------------------------------------
      # Channel resolution
      # -----------------------------------------------------------------------
      detectedChannels =
        if cfg.autoDetectChannels && cfg.channels == { }
        then
          mapAttrs (name: input: { inherit input; })
            (filterAttrs isNixpkgsLike inputs)
        else { };

      allChannels = cfg.channels // detectedChannels;

      # -----------------------------------------------------------------------
      # System → channel pkgs cache, evaluated at the flake level.
      #
      # Strategy: evaluate nixpkgs once per (system, channel) pair, cache the
      # result, and use it for both host building and perSystem injection.
      #
      # This avoids the double-eval hack in FUP's main mkFlake (which evaluates
      # NixOS config twice to sniff nixpkgs.config), and avoids cross-module-
      # system data transfer issues inside flake-parts.
      # -----------------------------------------------------------------------
      resolvedHosts = mapAttrs (name: host: resolveHost name host cfg.hostDefaults) cfg.hosts;

      # Systems we actually need channels for
      neededSystems = lib.unique (
        (map (h: h.system) (attrValues resolvedHosts))
        ++ config.systems
      );

      # system -> { channelName -> pkgs }
      # Lazily evaluated: a system's channels are only imported when accessed.
      channelCache = listToAttrs (map
        (system: {
          name = system;
          value =
            if allChannels == { } then { }
            else
              let
                # allPkgs is lazy — overlaysBuilder receives unevaluated thunks
                allPkgs = mapAttrs
                  (name: ch:
                    let
                      pkgs = import ch.input {
                        inherit system;
                        overlays = cfg.sharedOverlays
                          ++ (if ch.overlaysBuilder != null
                        then ch.overlaysBuilder allPkgs
                        else [ ]);
                        config = cfg.channelsConfig // ch.config;
                      };
                    in
                    pkgs // { inherit (ch) input; }
                  )
                  allChannels;
              in
              allPkgs;
        })
        neededSystems);

      # Convenience accessor
      getChannelsFor = system: channelCache.${system} or { };

      # -----------------------------------------------------------------------
      # Overlay introspection helpers
      # -----------------------------------------------------------------------

      # A representative system for overlay name extraction (any will do).
      oneSystem = head config.systems;

      # Return attribute names defined by an overlay, using real evaluated pkgs
      # (passed as both final and prev — values are wrong, but keys are correct).
      # Returns [] if the overlay fails to evaluate (e.g. cross-channel refs).
      overlayAttrNames = channelName: overlay:
        let
          pkgs = channelCache.${oneSystem}.${channelName} or { };
          result = builtins.tryEval (attrNames (overlay pkgs pkgs));
        in
        filter (n: n != "__dontExport") (if result.success then result.value else [ ]);

      # All overlay-defined package names across all channels (deduplicated).
      allOverlayPackageNames = system:
        let chanPkgs = getChannelsFor system; in
        unique (concatMap (channelName:
          let pkgs = chanPkgs.${channelName} or { }; in
          concatMap (overlay: overlayAttrNames channelName overlay) (pkgs.overlays or [ ])
        ) (attrNames allChannels));

      # Build the overlays attrset: "channelName/pkgName" -> single-attr overlay.
      computedExportedOverlays =
        listToAttrs (concatMap (channelName:
          let
            chanPkgs = channelCache.${oneSystem}.${channelName} or null;
            overlays = if chanPkgs != null then chanPkgs.overlays or [ ] else [ ];
          in
          concatMap (overlay:
            map (pkgName: {
              name = "${channelName}/${pkgName}";
              value = final: prev: { ${pkgName} = (overlay final prev).${pkgName}; };
            }) (overlayAttrNames channelName overlay)
          ) overlays
        ) (attrNames allChannels));

      # -----------------------------------------------------------------------
      # Host building
      # -----------------------------------------------------------------------
      registryModule = mkRegistryModule {
        autoRegistry = cfg.autoRegistry;
        autoNixPath = cfg.autoNixPath;
      };

      # Build one host declaration into flake output attributes
      buildOneHost = name: hostRaw:
        let
          h = resolveHost name hostRaw cfg.hostDefaults;

          # Grab channel pkgs for this host's system
          chanPkgsSet = getChannelsFor h.system;
          chanPkgs =
            if allChannels == { } then
            # No channels configured — fallback: hosts must provide their own
            # pkgs through nixpkgs.pkgs in a module
              null
            else
              chanPkgsSet.${h.channelName} or
                (throw "fup: host '${name}' references channel '${h.channelName}' which is not available on '${h.system}'. Available: ${toString (attrNames chanPkgsSet)}");

          hostname = hostnameFromReverseDNS name;
          domain = domainFromReverseDNS name;

          # Wiring module: injects pkgs, hostname, domain, revision
          wiringModule = { lib, options, ... }: {
            networking.hostName = lib.mkDefault hostname;
            networking.domain = lib.mkIf (domain != null) (lib.mkDefault domain);
            system.configurationRevision = lib.mkIf (self ? rev && options ? system.configurationRevision) self.rev;
          } // optionalAttrs (chanPkgs != null) {
            nixpkgs.pkgs = chanPkgs;
          };

          baseModules = h.modules ++ [ wiringModule ]
            ++ optionalAttrs (cfg.autoRegistry || cfg.autoNixPath) [ registryModule ];

          # Resolve builder function
          builder =
            if h.builder != null then h.builder
            else if h.output == "darwinConfigurations" then
              throw "fup: host '${name}' has output 'darwinConfigurations' but no builder set. "
              + "Set 'hostDefaults.builder = inputs.nix-darwin.lib.darwinSystem' or override per-host."
            else
              chanPkgs.lib.nixosSystem;

          # Build the config — different top-level args per output type
          result =
            if h.output == "darwinConfigurations" then
              builder
                {
                  modules = baseModules;
                  specialArgs = h.specialArgs;
                  pkgs = chanPkgs;
                  inherit (h) system;
                }
            else
              builder {
                modules = baseModules;
                specialArgs = h.specialArgs;
                inherit (h) system;
              };
        in
        { ${h.output}.${name} = result; };

    in
    {
      # -----------------------------------------------------------------------
      # Per-system: expose evaluated channels as a module argument so they can
      # be used in devShells, packages, etc.
      #
      # Usage: perSystem = { fupChannels, ... }: { packages.foo = fupChannels.unstable.callPackage ...; };
      # -----------------------------------------------------------------------
      perSystem = { system, ... }: {
        config._module.args.fupChannels = getChannelsFor system;

        config.packages = mkIf (cfg.exportPackages && allChannels != { }) (
          let
            chanPkgs = getChannelsFor system;
            mergedPkgs = foldl' recursiveUpdate { } (attrValues chanPkgs);
            pkgNames = allOverlayPackageNames system;
            isExportable = name:
              let pkg = mergedPkgs.${name} or null; in
              pkg != null
              && pkg ? type && pkg.type == "derivation"
              && (!(pkg ? meta && pkg.meta ? platforms)
                  || elem system pkg.meta.platforms);
          in
          listToAttrs (
            concatMap (name:
              if isExportable name
              then [{ inherit name; value = mergedPkgs.${name}; }]
              else [ ]
            ) pkgNames
          )
        );
      };

      # -----------------------------------------------------------------------
      # Flake-level: build host configuration sets, exported overlays, modules
      # -----------------------------------------------------------------------
      flake = foldl' recursiveUpdate { } (
        (mapAttrsToList buildOneHost cfg.hosts)
        ++ lib.optional (cfg.exportOverlays && allChannels != { } && config.systems != [ ])
          { overlays = computedExportedOverlays; }
        ++ lib.optional (cfg.nixosModules != [ ]) {
          nixosModules = listToAttrs (map (path: {
            name = removeSuffix ".nix" (baseNameOf (toString path));
            value = import path;
          }) cfg.nixosModules);
        }
      );
    };
}
