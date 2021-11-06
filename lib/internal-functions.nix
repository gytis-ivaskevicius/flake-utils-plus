with builtins;
rec {
  filterAttrs = pred: set:
    listToAttrs (concatMap (name: let value = set.${name}; in if pred name value then [ ({ inherit name value; }) ] else [ ]) (attrNames set));

  /* Generate an attribute set by mapping a function over a list of
    attribute names.

    Example:
    genAttrs [ "foo" "bar" ] (name: "x_" + name)
    => { foo = "x_foo"; bar = "x_bar"; }
  */
  genAttrs' = func: values: builtins.listToAttrs (map func values);

  getAttrs = names: attrs: genAttrs names (name: attrs.${name});

  hasFileAttr = o: builtins.hasAttr "_file" o;

  # Definition in nixpkgs
  hasSuffix =
    # Suffix to check for
    suffix:
    # Input string
    content:
    let
      lenContent = stringLength content;
      lenSuffix = stringLength suffix;
    in
    lenContent >= lenSuffix &&
    substring (lenContent - lenSuffix) lenContent content == suffix;

  # Definition in nixpkgs
  mapAttrs' = f: set:
    listToAttrs (map (attr: f attr set.${attr}) (attrNames set));

  /* Partition string s based on sep

    Example:
    partitionString "," "nix,json,yaml"
    => [ "nix" "json" "yaml" ]
  */
  partitionString = sep: s:
    filter (v: isString v) (split "${sep}" s);

  # Returns the type of a path: regular (for file), symlink, or directory
  pathType = p: getAttr (baseNameOf p) (readDir (dirOf p));

  peek = f: f (builtins.functionArgs f);

  removeSuffix = suffix: str:
    let
      sufLen = builtins.stringLength suffix;
      sLen = builtins.stringLength str;
    in
    if sufLen <= sLen && suffix == builtins.substring (sLen - sufLen) sufLen str then
      builtins.substring 0 (sLen - sufLen) str
    else
      str;

  reverseList = xs:
    let l = length xs; in genList (n: elemAt xs (l - n - 1)) l;

}
