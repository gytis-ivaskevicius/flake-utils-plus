{ flake-utils-plus }:
let

  packagesFromOverlaysBuilderConstructor = overlays:
    let
      # overlays: self.overlays

      packagesFromOverlaysBuilder = streams:
        /**
          Synopsis: packagesFromOverlaysBuilder _streams_

          streams: builder `streams` argument

          Returns valid packges that have been defined within an overlay so they
          can be shared via _self.packages_ with the world. This is especially useful
          over sharing one's art via _self.overlays_ in case you have a binary cache
          running from which third parties could benefit.

          Steps:
          1. merge all streams into one nixpkgs attribute set
          2. collect all overlays' packages' keys into one flat list
          3. pick out each package from the nixpkgs set into one packages set
          $. flatten package set and filter out disallowed packages - by flake check requirements

          example input and output:
          ```
          overlays = {
          "unstable/firefox" = prev: final: {
          firefox = prev.override { privacySupport = true; };
          }; 
          }

          self.packages = {
          firefox = *firefox derivation with privacySupport*;
          }
          ```

          **/
        let

          inherit (flake-utils-plus.lib) flattenTree filterPackages;
          inherit (builtins) foldl' attrNames mapAttrs listToAttrs
            attrValues concatStringSep concatMap any head;
          nameValuePair = name: value: { inherit name value; };

          flattenedPackages =
            # merge all streams into one package set
            foldl' (a: b: a // b) { } (attrValues streams);

          # flatten all overlays' packages' keys into a single list
          flattenedOverlaysNames =
            let
              allOverlays = attrValues overlays;

              overlayNamesList = overlay:
                attrNames (overlay null null);
            in
            concatMap overlayNamesList allOverlays;

          # create list of single-attribute sets that contain each package
          exportPackagesList = map
            (name:
              { ${name} = flattenedPackages.${name}; }
            )
            flattenedOverlaysNames;

          # fold list into one attribute set
          exportPackages = foldl' (lhs: rhs: lhs // rhs) { } exportPackagesList;

          system = (head (attrValues streams)).system;

        in
        # flatten nested sets with "/" delimiter then drop disallowed packages
        filterPackages system (flattenTree exportPackages);

    in
    packagesFromOverlaysBuilder;

in
packagesFromOverlaysBuilderConstructor
