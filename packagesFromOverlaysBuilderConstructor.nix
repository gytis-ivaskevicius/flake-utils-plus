{ flake-utils-plus }: let

 overlayFromPackagesBuilderConstructor = channels: let
   # channels: channels.<name>.overlays

   overlayFromPackagesBuilder = pkgs:
    /**
    Synopsis: overlayFromPackagesBuilder _pkgs_

    pkgs:     pkgs.<system>.<tree>

    Returns valid packges that have been defined within an overlay so they
    can be shared via _self.packages_ with the world. This is especially useful
    over sharing one's art via _self.overlays_ in case you have a binary cache
    running from which third parties could benefit.

    First, flattens an arbitrarily nested _pkgs_ tree for each system into a flat
    key in which nesting is aproximated by a "/" (e.g. "development/kakoune").
    Also filter the resulting packages for attributes that _trivially_ would
    fail flake checks (broken, system not supported or not a derivation).

    Second, collects all overlays' packages' keys of all channels into a flat list.

    Finally, only passes packages through the seive that are prefixed with a top level
    key exposed by any of the overlays. Since overlays override (and do not emrge)
    top level attributes, by filtering on the prefix, an overlay's entire packages
    tree will be correctly captured.

    Example:

    pkgs'.<system> = {
      "development/kakoune" = { ... };
      "development/vim" = { ... };
    };

    overlays' = [
      "development"
    ];

    overlays' will pass both pkgs' through the sieve.

    **/
    let

      inherit (flake-utils-plus.lib) flattenTree filterPackages;
      inherit (builtins) attrNames mapAttrs listToAttrs attrValues concatStringSep concatMap any;
      nameValuePair = name: value: { inherit name value; };
      filterAttrs = pred: set:
        listToAttrs (concatMap (name: let v = set.${name}; in if pred name v then [(nameValuePair name v)] else []) (attrNames set));
      hasPrefix =
        pref:
        str: builtins.substring 0 (builtins.stringLength pref) str == pref;


      # first, flatten and filter on valid packages (by nix flake check criterion)
      flattenedPackages =
        let
          f = system: tree: (filterPackages system (flattenTree tree));
        in
        mapAttrs f pkgs;

      # second, flatten all overlays' packages' keys into a single list
      flattendOverlaysNames =
        let
          allOverlays = concatMap (c: c.overlays) (attrValues channels);

          overlayNamesList = overlay:
            attrNames (overlay null null);
        in
          concatMap (o: overlayNamesList o) allOverlays;

    in
      # finally, only retain those packages defined by overlays
      # pkgs'.<system>.<prefix/flattend/tree/attributes>
      # overlays' = [ "prefix" ... ];
      mapAttrs (_: pkgs:
        filterAttrs (pkgName:
          any (overlayName: hasPrefix pkgName overlayName) flattendOverlaysNames
        ) pkgs
      ) flattenedPackages;

  in
  overlayFromPackagesBuilder;

in
overlayFromPackagesBuilderConstructor
