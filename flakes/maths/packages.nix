{ lib, pkgs }:
(import ../lib/toolkit.nix).mkPackages {
  inherit lib pkgs;
  names = import ./names.nix;
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
}
