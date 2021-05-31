{ flake-utils-plus }:

{ self
, defaultSystem ? "x86_64-linux" # will be deprecated soon use hostDefaults.system instead
, supportedSystems ? flake-utils-plus.lib.defaultSystems
, inputs

, channels ? { }
, channelsConfig ? { }
, sharedOverlays ? [ ]

, nixosProfiles ? { } # will be deprecated soon, use hosts, instead.
, hosts ? nixosProfiles
, sharedExtraArgs ? { } # deprecate soon, prefer hostDefaults
, sharedModules ? [ ] # deprecate soon, prefer hostDefaults
, hostDefaults ? {
    system = defaultSystem;
    modules = sharedModules;
    extraArgs = sharedExtraArgs;
  }

, outputsBuilder ? null

, packagesBuilder ? null
, defaultPackageBuilder ? null
, appsBuilder ? null
, defaultAppBuilder ? null
, devShellBuilder ? null
, checksBuilder ? null
, ...
}@args:

let
  inherit (flake-utils-plus.lib) eachSystem patchChannel mergeAny;
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
    isString
    length
    listToAttrs
    mapAttrs
    removeAttrs
    split
    tail
    ;

  fupOverlay = final: prev: {
    fup-repl = final.writeShellScriptBin "repl" ''
      if [ -z "$1" ]; then
        nix repl ${./repl.nix}
      else
        nix repl --arg flakePath $(readlink -f $1 | sed 's|/flake.nix||') ${./repl.nix}
      fi
    '';
  };

  filterAttrs = pred: set:
    listToAttrs (concatMap (name: let value = set.${name}; in if pred name value then [ ({ inherit name value; }) ] else [ ]) (attrNames set));

  reverseList = xs:
    let l = length xs; in genList (n: elemAt xs (l - n - 1)) l;

  partitionString = sep: s:
    filter (v: isString v) (split "${sep}" s);


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
      modules = modules ++ [ ./autoRegistry.options.nix ];
    };

  foldHosts = foldl' mergeAny { };

  optionalAttrs = check: value: if check then value else { };

  otherArguments = removeAttrs args [
    "defaultSystem" # TODO: deprecated, remove
    "sharedExtraArgs" # deprecated
    "inputs"
    "hosts"
    "hostDefaults"
    "nixosProfiles"
    "channels"
    "channelsConfig"
    "self"
    "sharedModules" # deprecated
    "sharedOverlays"
    "supportedSystems"

    "outputsBuilder"
    "packagesBuilder"
    "defaultPackageBuilder"
    "appsBuilder"
    "defaultAppBuilder"
    "devShellBuilder"
    "checksBuilder"
  ];

  getChannels = system: self.pkgs.${system};
  getNixpkgs = host: (getChannels host.system).${host.channelName};

  configurationBuilder = reverseDnsFqdn: host': (
    let
      dnsLabels = reverseList (partitionString "\\." reverseDnsFqdn);
      hostname = head dnsLabels;
      domain = let
        domainLabels = tail dnsLabels;
      in
        if domainLabels == [] then (lib.mkDefault null) # null is the networking.domain option's default
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
        check = false;
        modules = baseModules ++ host.modules;
        args = { inherit inputs; } // host.extraArgs;
        specialArgs = nixosSpecialArgs // specialArgs;
      }).config;
    in
    {
      ${host.output}.${reverseDnsFqdn} = host.builder ({
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
                  nixpkgs.config = selectedNixpkgs.config;
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
                          overlays = selectedNixpkgs.overlays ++ hostConfig.nixpkgs.overlays;
                          config = selectedNixpkgs.config // config.nixpkgs.config;
                        } // { inherit (selectedNixpkgs) name input; };
                }
              else { _module.args.pkgs = selectedNixpkgs; })

              (optionalAttrs (options ? system.configurationRevision) {
                system.configurationRevision = lib.mkIf (self ? rev) self.rev;
              })

              (optionalAttrs (options ? nix.package) {
                nix.package = lib.mkDefault pkgs.nixUnstable;
              })

              (optionalAttrs (options ? nix.extraOptions) {
                nix.extraOptions = "experimental-features = nix-command ca-references flakes";
              })

              {
                # at this point we assume, that an evaluator at least
                # uses nixpkgs.lib to evaluate modules.
                _module.args = { inherit inputs; } // host.extraArgs;
              }
            ];
          })
        ] ++ host.modules;
        inherit specialArgs;
      } // (optionalAttrs (host.output == "nixosConfigurations") {
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

        channelFlakes = filterAttrs (_: value: value ? legacyPackages) inputs;
        channelsFromFlakes = mapAttrs (name: input: { inherit input; }) channelFlakes;

        importChannel = name: value: (import (patchChannel system value.input (value.patches or [ ])) {
          inherit system;
          overlays = [
            (final: prev: {
              __dontExport = true; # in case user uses overlaysFromChannelsExporter, doesn't hurt for others
              inherit srcs;
            })
          ] ++ sharedOverlays ++ (if (value ? overlaysBuilder) then (value.overlaysBuilder pkgs) else [ ]) ++ [ fupOverlay ];
          config = channelsConfig // (value.config or { });
        }) // { inherit name; inherit (value) input; };

        pkgs = mapAttrs importChannel (mergeAny channelsFromFlakes channels);


        deprecatedBuilders = channels: { }
        // optionalAttrs (packagesBuilder != null) { packages = packagesBuilder channels; }
        // optionalAttrs (defaultPackageBuilder != null) { defaultPackage = defaultPackageBuilder channels; }
        // optionalAttrs (appsBuilder != null) { apps = appsBuilder channels; }
        // optionalAttrs (defaultAppBuilder != null) { defaultApp = defaultAppBuilder channels; }
        // optionalAttrs (devShellBuilder != null) { devShell = devShellBuilder channels; }
        // optionalAttrs (checksBuilder != null) { checks = checksBuilder channels; };

        systemOutputs = (if outputsBuilder == null then deprecatedBuilders else outputsBuilder) pkgs;

        mkOutput = output:
          mergeAny
            # prevent override of nested outputs in otherArguments
            (optionalAttrs (otherArguments ? ${output}.${system})
              { ${output} = otherArguments.${output}.${system}; })
            (optionalAttrs (systemOutputs ? ${output})
              { ${output} = systemOutputs.${output}; });

      in
      { inherit pkgs; }
      // mkOutput "packages"
      // mkOutput "defaultPackage"
      // mkOutput "apps"
      // mkOutput "defaultApp"
      // mkOutput "devShell"
      // mkOutput "checks"
    )
  # produces attrset in the shape of
  # { nixosConfigurations = {}; darwinConfigurations = {};  ... }
  # according to profile.output or the default `nixosConfigurations`
  // foldHosts (attrValues (mapAttrs configurationBuilder hosts))
)

