{
  description = "Common Lisp — SBCL + ocicl (project-local deps, no global quicklisp)";

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
      devShells = eachSystem (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [

            (sbcl.withPackages (
              ps: with ps; [
                swank
                alexandria
              ]
            ))
            rlwrap
          ];

          shellHook = ''
            echo "Common Lisp — $(sbcl --version)"
            echo "  rlwrap sbcl     bare REPL with line editing"
            echo "  nvim x.lisp     then <localleader>cc to connect nvlime"
            echo ""
            echo "  Deps are declarative: add systems to sbcl.withPackages in"
            echo "  flake.nix. ocicl/qlot are not packaged in nixpkgs."
          '';
        };
      });
    };
}
