{
  description = "Pure maths and proof assistant toolkit";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    (import ../lib/toolkit.nix).mkFlake {
      inherit self nixpkgs;
      name = "maths";
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      packages = ./packages.nix;
      module = import ./module.nix;
      extraShells = pkgs: p: {
        mathlib = pkgs.mkShellNoCC {
          name = "maths-mathlib";
          packages = p.sets.lean ++ [
            pkgs.git
            pkgs.curl
            pkgs.cacert
          ];
          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
            pkgs.stdenv.cc.cc.lib
            pkgs.gmp
            pkgs.zlib
          ];
        };
      };
    };
}
