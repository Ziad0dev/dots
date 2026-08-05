{
  description = "Zig devshell — zig master via zig-overlay, zls";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    zig-overlay.url = "github:mitchellh/zig-overlay";
  };

  outputs = { nixpkgs, zig-overlay, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = [
          zig-overlay.packages.${system}.master
          pkgs.zls
        ];
      };
    };
}
