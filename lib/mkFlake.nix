{ flake-utils-plus }:

{ self
, supportedSystems ? flake-utils-plus.lib.defaultSystems
, inputs
, channels ? { }
, channelsConfig ? { }
, sharedOverlays ? [ ]
, hosts ? { }
, hostDefaults ? {
    system = "x86_64-linux";
    modules = [ ];
    extraArgs = { };
  }
, outputsBuilder ? _: { }
, ...
}@args:

let
  inherit (flake-utils-plus.lib)
    eachSystem
    mergeAny
    ;
  inherit (flake-utils-plus.lib.internal)
    filterAttrs
    partitionString
    reverseList
    ;
  inherit (builtins)
    attrNames
    attrValues
    concatMap
    concatStringsSep
    elemAt
    filter
    foldl'
    genList
    head
    isAttrs
    isFunction
    isString
    length
    listToAttrs
    mapAttrs
    pathExists
    removeAttrs
    split
    tail
    ;


  srcs = filterAttrs (_: value: !value ? outputs) inputs;

  # set defaults and validate host arguments
  evalHostArgs =
    { channelName ? "nixpkgs"
    , system ? "x86_64-linux"
    , output ? "nixosConfigurations"
    , builder ? (getChannels system).${channelName}.input.lib.nixosSystem
    , modules ? [ ]
    , extraArgs ? { }
      # These are not part of the module system, so they can be used in `imports` lines without infinite recursion
    , specialArgs ? { }
    }: {
      inherit channelName system output builder extraArgs specialArgs;
      modules = modules ++ [ ./options.nix ];
    };

  optionalAttrs = check: value: if check then value else { };

  otherArguments = removeAttrs args [
    "inputs"
    "hosts"
    "hostDefaults"
    "nixosProfiles"
    "channels"
    "channelsConfig"
    "self"
    "sharedOverlays"
    "supportedSystems"
  ];

  getChannels = system: self.pkgs.${system};
  ensureChannelsWitsInputs = mapAttrs
    (n: v:
      if (!v ? input) then
        v // {
          input = inputs.${n} or (
            throw ''
              No input is inferable by name from flake inputs for channel "${n}"
            '');
        }
      else v
    )
    channels;
  getNixpkgs = host: (getChannels host.system).${host.channelName};
  mergeNixpkgsConfigs = input: lconf: rconf: (
    input.lib.evalModules {
      modules = [
        "${input}/nixos/modules/misc/assertions.nix"
        "${input}/nixos/modules/misc/nixpkgs.nix"
        {
          nixpkgs.config = lconf;
        }
        {
          nixpkgs.config = rconf;
        }
      ];
    }
  ).config.nixpkgs.config;

  configurationBuilder = reverseDomainName: host': (
    let
      dnsLabels = reverseList (partitionString "\\." reverseDomainName);
      hostname = head dnsLabels;
      domain =
        let
          domainLabels = tail dnsLabels;
        in
        if domainLabels == [ ] then (lib.mkDefault null) # null is the networking.domain option's default
        else concatStringsSep "." domainLabels;

      host = evalHostArgs (mergeAny hostDefaults host');
      selectedNixpkgs = getNixpkgs host;
      channels' = getChannels host.system;
      lib = selectedNixpkgs.lib;

      specialArgs = host.specialArgs // { channel = selectedNixpkgs; };

      /* nixos specific arguments */
      nixosSpecialArgs =
        let
          f = channelName:
            { "${channelName}ModulesPath" = toString (channels'.${channelName}.input + "/nixos/modules"); };
        in
        # Add `<channelName>ModulesPath`s
        (foldl' (lhs: rhs: lhs // rhs) { } (map f (attrNames channels')))
      ;

      # genericModule MUST work gracefully with distinct module sets and
      # cannot make any assumption other than the nixpkgs module system
      # is used.
      # See: https://github.com/NixOS/nixpkgs/blob/master/lib/modules.nix
      # Exemplary module sets are: nixos, darwin, home-manager, etc
      genericModule = preflight: { pkgs, lib, options, ... }: {
        # 'mkMerge` to separate out each part into its own module
        _type = "merge";
        contents = (
          if ((preflight == null) || (!options ? nixpkgs.pkgs)) then
          # equivalent to nixpkgs.pkgs = selectedNixpkgs
            [{ _module.args.pkgs = selectedNixpkgs; }]
          else
          # if preflight.nixpkgs.config == {},
          # then the memorized evaluation of selectedNixpkgs will be used
          # and we won't incur in an additional (expensive) evaluation.
          # This works because nixos invokes at some point the same function
          # with the same arguments as we already have in importChannel.
          # DYOR:
          #   -> https://github.com/NixOS/nixpkgs/blob/b63a54f81ce96391e6da6aab5965926e7cdbce47/nixos/modules/misc/nixpkgs.nix#L58-L60
          #   -> https://github.com/NixOS/nixpkgs/blob/master/pkgs/top-level/default.nix
          #   -> lib.systems.elaborate is idempotent
            [
              {
                nixpkgs = { inherit (selectedNixpkgs) system overlays; };
              }
              {
                # however, let the module system merge -> advanced config merge (sic!)
                nixpkgs = { inherit (selectedNixpkgs) config; };
              }
              {
                nixpkgs = { inherit (preflight.config.nixpkgs) config; };
              }
            ]
        )
        ++
        [
          {
            _module.args = { inherit inputs; } // host.extraArgs;
          }

          (optionalAttrs (options ? networking.hostName) {
            networking.hostName = hostname;
          })

          (optionalAttrs (options ? networking.domain) {
            networking.domain = domain;
          })

          (optionalAttrs (options ? system.configurationRevision) {
            system.configurationRevision = lib.mkIf (self ? rev) self.rev;
          })

          (optionalAttrs (options ? nix.package) {
            nix.package = lib.mkDefault pkgs.nixUnstable;
          })

          (optionalAttrs (options ? nix.extraOptions) {
            nix.extraOptions = "extra-experimental-features = nix-command ca-references flakes";
          })
        ];
      };

      evalArgs = {
        inherit (host) system;
        modules = [ (genericModule null) ] ++ host.modules;
        inherit specialArgs;
      }
      //
      (optionalAttrs (host.output == "nixosConfigurations") {
        specialArgs = nixosSpecialArgs // specialArgs;
      }
      );

      # The only way to find out if a host has `nixpkgs.config` set to
      # the non-default value is by evalling the config.
      # If it's not set, repeating the evaluation is cheap since
      # all module evaluations except misc/nixpkgs.nix are memorized
      # since `pkgs` would not change.
      preFlightEvaled = host.builder (evalArgs // {
        modules = [ (genericModule null) ] ++ host.modules;
      });

    in
    {
      ${host.output}.${reverseDomainName} = host.builder (evalArgs // {
        modules = [ (genericModule preFlightEvaled) ] ++ host.modules;
      });
    }
  );

in
mergeAny otherArguments (

  eachSystem supportedSystems
    (system:
      let
        importChannel = name: value: (import value.input {
          inherit system;
          overlays = [
            (final: prev: {
              __dontExport = true; # in case user uses overlaysFromChannelsExporter, doesn't hurt for others
              inherit srcs name;
              inherit (value) input;
            })
          ]
          ++
          sharedOverlays ++ (if (value ? overlaysBuilder) then (value.overlaysBuilder pkgs) else [ ])
          ++
          [ flake-utils-plus.overlay ];
          config = mergeNixpkgsConfigs value.input channelsConfig (value.config or { });
        });

        pkgs = mapAttrs importChannel ensureChannelsWitsInputs;

        systemOutputs = outputsBuilder pkgs;

        mkOutputs = attrs: output:
          attrs //
          mergeAny
            # prevent override of nested outputs in otherArguments
            (optionalAttrs (otherArguments ? ${output}.${system})
              { ${output} = otherArguments.${output}.${system}; })
            (optionalAttrs (systemOutputs ? ${output})
              { ${output} = systemOutputs.${output}; });

      in
      { inherit pkgs; }
      // (foldl' mkOutputs { } (attrNames systemOutputs))
    )
  # produces attrset in the shape of
  # { nixosConfigurations = {}; darwinConfigurations = {};  ... }
  # according to profile.output or the default `nixosConfigurations`
  // foldl' mergeAny { } (attrValues (mapAttrs configurationBuilder hosts))
)

