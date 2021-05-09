{
  hasKey = nixpkgs: attrset: key:
    if (attrset ? ${key})
    then nixpkgs.runCommandNoCC "success-${key}" { } "echo success > $out"
    else nixpkgs.runCommandNoCC "falure-key-${key}'-does-not-exist-in-attrset" { } "exit 1";
}
