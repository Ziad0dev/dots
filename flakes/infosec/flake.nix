{
  description = "Curated infosec toolkit";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      each =
        f:
        lib.genAttrs systems (
          system:
          f (
            import nixpkgs {
              inherit system;
              config.allowUnfree = true;
            }
          )
        );

      load =
        pkgs:
        import ./packages.nix {
          inherit (pkgs) lib;
          inherit pkgs;
        };
    in
    {
      packages = each (
        pkgs:
        let
          p = load pkgs;
          env =
            name: paths:
            pkgs.buildEnv {
              name = "infosec-${name}";
              inherit paths;
              ignoreCollisions = true;
            };
          report = pkgs.writeText "infosec-missing" (
            lib.concatStringsSep "\n" (
              lib.mapAttrsToList (
                n: ms: "${n}: ${if ms == [ ] then "ok" else lib.concatStringsSep " " ms}"
              ) p.missing
            )
          );
        in
        lib.mapAttrs env p.sets
        // {
          default = env "core" p.sets.core;
          all = env "all" (lib.concatLists (builtins.attrValues p.sets));
          audit = pkgs.writeShellScriptBin "infosec-audit" "cat ${report}";
        }
      );

      devShells = each (
        pkgs:
        let
          p = load pkgs;
          shell =
            name: paths:
            pkgs.mkShellNoCC {
              name = "infosec-${name}";
              packages = paths;
            };
        in
        lib.mapAttrs shell p.sets
        // {
          default = shell "core" p.sets.core;
          all = shell "all" (lib.concatLists (builtins.attrValues p.sets));
        }
      );

      apps = lib.genAttrs systems (system: {
        audit = {
          type = "app";
          program = "${self.packages.${system}.audit}/bin/infosec-audit";
        };
      });

      nixosModules.default = import ./module.nix { target = "nixos"; };
      homeManagerModules.default = import ./module.nix { target = "home"; };

      formatter = each (pkgs: pkgs.nixpkgs-fmt);
    };
}
