{ flake-utils-plus }:
let

  overlaysFromChannelsExporter = channels:
    /**
      Synopsis: overlaysFromChannelsExporter _channels_

      channels: channels.<name>.overlays

      Returns an attribute set of all packages defined in an overlay by any channel
      intended to be passed to be exported via _self.overlays_. This method of
      sharing has the advantage over _self.packages_, that the user will instantiate
      overlays with his proper nixpkgs version, and thereby significantly reduce their system's
      closure as they avoid depending on entirely different nixpkgs versions dependency
      trees. On the flip side, any caching that is set up for one's packages will essentially
      be useless to users.

      It can happen that an overlay is not compatible with the version of nixpkgs a user tries
      to instantiate it. In order to provide users with a visual clue for which nixpkgs version
      an overlay was originally created, we prefix the channle name: "<channelname>/<packagekey>".
      In the case of the unstable channel, this information is still of varying usefulness,
      as effective cut dates can vary heavily between repositories.

      Example:

      overlays = [
      "unstable/development" = final: prev: { };
      "nixos2009/chromium" = final: prev: { };
      "nixos2009/pythonPackages" = final: prev: { };
      ];

      **/
    let
      inherit (builtins) mapAttrs attrNames concatMap listToAttrs;
      nameValuePair = name: value: { inherit name value; };

      pathStr = path: builtins.concatStringsSep "/" path;

      channelNames = attrNames channels;
      overlayNames = overlay: attrNames (overlay null null);

      extractAndNamespaceEachOverlay = channelName: overlay:
        map
          (overlayName:
            nameValuePair
              (pathStr [ channelName overlayName ])
              (final: prev: {
                ${overlayName} = (overlay final prev).${overlayName};
              })
          )
          (overlayNames overlay);

    in
    listToAttrs (
      concatMap
        (channelName:
          concatMap
            (overlay:
              extractAndNamespaceEachOverlay channelName overlay
            )
            channels.${channelName}.overlays
        )
        channelNames
    );

in
overlaysFromChannelsExporter
