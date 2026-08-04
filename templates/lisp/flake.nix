{
  description = "Common Lisp — SBCL + ocicl (project-local deps, no global quicklisp)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          sbcl
          ocicl      # deps land in ./systems/ — the project is self-contained
          rlwrap
        ];

        shellHook = ''
          echo "Common Lisp — $(sbcl --version)"
          echo "  ocicl install <system>   add a dependency to this project"
          echo "  rlwrap sbcl              bare REPL with line editing"
          echo "  nvim file.lisp           then <localleader>cc to connect nvlime"
        '';
      };
    };
}
