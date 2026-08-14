{
  description = "Haskell devshell — GHC + cabal + HLS (Clash extras commented)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      hs = pkgs.haskellPackages;
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = [
          (hs.ghcWithPackages (ps: [

          ]))
          hs.cabal-install
          hs.haskell-language-server
        ];
      };
    };
}
