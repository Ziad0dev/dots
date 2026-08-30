{
  description = "Zig devshell — pick a matched Zig/zls pair per project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    zig-overlay = {
      url = "github:mitchellh/zig-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zls = {
      url = "github:zigtools/zls/0.16.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zls-edge = {
      url = "github:zigtools/zls";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      zig-overlay,
      zls,
      zls-edge,
      ...
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      eachSystem =
        f:
        nixpkgs.lib.genAttrs systems (
          system:
          f {
            pkgs = nixpkgs.legacyPackages.${system};
            zig = zig-overlay.packages.${system};
            zlsStable = zls.packages.${system}.zls;
            zlsEdge = zls-edge.packages.${system}.zls;
          }
        );
    in
    {
      devShells = eachSystem (
        {
          pkgs,
          zig,
          zlsStable,
          zlsEdge,
        }:
        {
          default = pkgs.mkShell {
            packages = [
              zig."0.16.0"
              zlsStable
            ];
          };

          edge = pkgs.mkShell {
            packages = [
              zig."master-2026-05-25"
              zlsEdge
            ];
          };

          nightly = pkgs.mkShell {
            packages = [
              zig.master
              zlsEdge
            ];
          };
        }
      );
    };
}
