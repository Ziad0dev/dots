{ lib, pkgs }:
let
  names = import ./names.nix;

  try = e: let r = builtins.tryEval e; in if r.success then r.value else null;
  lookup = n: try (lib.attrByPath (lib.splitString "." n) null pkgs);
  usable = p: p != null && (try (p.meta.available or true)) == true;

  resolve = ns: lib.filter usable (map lookup ns);
  gone = ns: lib.filter (n: !(usable (lookup n))) ns;
in
{
  inherit names;
  sets = lib.mapAttrs (_: resolve) names;
  missing = lib.mapAttrs (_: gone) names;
}
