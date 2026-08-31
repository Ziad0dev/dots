{ lib, pkgs }:
let
  names = import ./names.nix;

  try =
    e:
    let
      r = builtins.tryEval e;
    in
    if r.success then r.value else null;
  lookup = n: try (lib.attrByPath (lib.splitString "." n) null pkgs);
  usable = p: p != null && (try (p.meta.available or true)) == true;

  resolve = ns: lib.filter usable (map lookup ns);
  gone = ns: lib.filter (n: !(usable (lookup n))) ns;

  extra = {
    python = [
      (pkgs.python3.withPackages (
        ps: with ps; [
          sympy
          mpmath
          numpy
          scipy
          matplotlib
          networkx
          jupyterlab
        ]
      ))
    ];
  };
in
{
  inherit names;
  sets = lib.mapAttrs (n: ns: resolve ns ++ (extra.${n} or [ ])) names;
  missing = lib.mapAttrs (_: gone) names;
}
