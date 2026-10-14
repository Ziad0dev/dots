{
  description = "Curated infosec toolkit";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    (import ../lib/toolkit.nix).mkFlake {
      inherit self nixpkgs;
      name = "infosec";
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      packages = ./packages.nix;
      module = import ./module.nix;
    };
}
