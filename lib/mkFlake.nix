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
    patchChannel
    ;
  inherit (flake-utils-plus.lib.internal)
    filterAttrs
    partitionString
    reverseList
    ;
  inherit (builtins)
    pathExists
    attrNames
    attrValues
    concatMap
    concatStringsSep
    elemAt
    filter
    foldl'
    genList
    head
    isString
    length
    listToAttrs
    mapAttrs
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
    "outputsBuilder"
  ];

  getChannels = system: self.pkgs.${system};
  getNixpkgs = host: (getChannels host.system).${host.channelName};

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

      selectedNixpkgs = getNixpkgs host;
      host = evalHostArgs (mergeAny hostDefaults host');
      patchedChannel = selectedNixpkgs.path;
      channels = getChannels host.system;

      specialArgs = host.specialArgs // { channel = selectedNixpkgs; };

      /* nixos specific arguments */
      # Use lib from patched nixpkgs
      lib = selectedNixpkgs.lib;
      # Use nixos modules from patched nixpkgs
      baseModules = import (patchedChannel + "/nixos/modules/module-list.nix");
      nixosSpecialArgs =
        let
          f = channelName:
            { "${channelName}ModulesPath" = toString (channels.${channelName}.input + "/nixos/modules"); };
        in
        # Add `<channelName>ModulesPath`s
        (foldl' (lhs: rhs: lhs // rhs) { } (map f (attrNames channels)))
        # Override `modulesPath` because otherwise imports from there will not use patched nixpkgs
        // { modulesPath = toString (patchedChannel + "/nixos/modules"); };


      # The only way to find out if a host has `nixpkgs.config` set to
      # the non-default value is by evalling most of the config.
      hostConfig = (lib.evalModules {
        prefix = [ ];
        modules = baseModules ++ host.modules ++ [{
          _module.check = false;
          _module.args = { inherit inputs; };
        }];
        specialArgs = nixosSpecialArgs // specialArgs;
      }).config;
    in
    {
      ${host.output}.${reverseDomainName} = host.builder ({
        inherit (host) system;
        modules = [
          ({ pkgs, lib, options, config, ... }: {
            # 'mkMerge` to separate out each part into its own module
            _type = "merge";
            contents = [
              (optionalAttrs (options ? networking.hostName) {
                networking.hostName = hostname;
              })

              (optionalAttrs (options ? networking.domain) {
                networking.domain = domain;
              })

              (if options ? nixpkgs.pkgs then
                {
                  nixpkgs.pkgs =
                    # Make sure we don't import nixpkgs again if not
                    # necessary. We can't use `config.nixpkgs.config`
                    # because that triggers infinite recursion.
                    if (hostConfig.nixpkgs.config == { }) then
                      selectedNixpkgs
                    else
                      import patchedChannel
                        {
                          inherit (host) system;
                          overlays = selectedNixpkgs.overlays;
                          config = selectedNixpkgs.config // config.nixpkgs.config;
                        } // { inherit (selectedNixpkgs) name input; };
                }
              else { })

              (optionalAttrs (options ? system.configurationRevision) {
                system.configurationRevision = lib.mkIf (self ? rev) self.rev;
              })

              (optionalAttrs (options ? nix.package) {
                nix.package = lib.mkDefault pkgs.nixUnstable;
              })

              (optionalAttrs (options ? nix.extraOptions) {
                nix.extraOptions = "extra-experimental-features = nix-command flakes";
              })

              {
                # at this point we assume, that an evaluator at least
                # uses nixpkgs.lib to evaluate modules.
                _module.args = (optionalAttrs (host.output != "darwinConfigurations") { inherit inputs; }) // host.extraArgs;
              }
            ];
          })
        ] ++ host.modules;
        inherit specialArgs;
      } // (optionalAttrs (host.output == "darwinConfigurations") {
        inherit inputs;
        pkgs = selectedNixpkgs;
      }) // (optionalAttrs (host.output == "nixosConfigurations") {
        inherit lib baseModules;
        specialArgs = nixosSpecialArgs // specialArgs;
      }));
    }
  );

in
mergeAny otherArguments (

  eachSystem supportedSystems
    (system:
      let
        filterAttrs = pred: set:
          listToAttrs (concatMap (name: let value = set.${name}; in if pred name value then [ ({ inherit name value; }) ] else [ ]) (attrNames set));

        # Little hack, we make sure that `legacyPackages` contains `nix` to make sure that we are dealing with nixpkgs.
        # For some odd reason `devshell` contains `legacyPackages` out put as well
        channelFlakes = filterAttrs (_: value: value ? legacyPackages && value.legacyPackages.x86_64-linux ? nix) inputs;
        channelsFromFlakes = mapAttrs (name: input: { inherit input; }) channelFlakes;

        importChannel = name: value: (import (patchChannel system value.input (value.patches or [ ])) {
          inherit system;
          overlays = [
            (final: prev: {
              __dontExport = true; # in case user uses overlaysFromChannelsExporter, doesn't hurt for others
              inherit srcs;
            })
          ] ++ sharedOverlays ++ (if (value ? overlaysBuilder) then (value.overlaysBuilder pkgs) else [ ]) ++ [ flake-utils-plus.overlay ];
          config = channelsConfig // (value.config or { });
        }) // { inherit name; inherit (value) input; };

        pkgs = mapAttrs importChannel (mergeAny channelsFromFlakes channels);

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
