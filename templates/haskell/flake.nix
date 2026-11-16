{
  description = "Haskell devshell — GHC + cabal + HLS (Clash extras commented)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      eachSystem = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      devShells = eachSystem (
        pkgs:
        let
          hs = pkgs.haskellPackages;
        in
        {
          default = pkgs.mkShell {
            packages = [
              (hs.ghcWithPackages (ps: [

              ]))
              hs.cabal-install
              hs.haskell-language-server
            ];
          };
        }
      );
    };
}
