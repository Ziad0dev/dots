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
          zig-overlay.packages.${system}.master # pin e.g. ."0.14.1" if zls lags master
          pkgs.zls
        ];
      };
    };
}
