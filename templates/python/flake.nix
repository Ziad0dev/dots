{

  description = "Python devshell: nix-first with uv escape hatch";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      eachSystem = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {

      templates = {
        python = {
          path = ./.;
          description = "Python devshell: nix-first with uv escape hatch";
        };
        default = self.templates.python;
      };

      devShells = eachSystem (
        pkgs:
        let

          python = pkgs.python312.withPackages (
            ps: with ps; [
              requests

            ]
          );
        in
        {
          default = pkgs.mkShell {
            packages = [
              python
              pkgs.ruff
              pkgs.pyright
              pkgs.uv
            ];

            env.LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
              pkgs.stdenv.cc.cc.lib
              pkgs.zlib
              pkgs.openssl

            ];

            shellHook = ''
              # Auto-provision .envrc so `direnv allow` is the only step.
              if [ ! -f .envrc ]; then
                echo "use flake" > .envrc
                echo "created .envrc — run: direnv allow"
              fi

              # Venv layered on the nix python, for tier-2 packages only.
              # Delete this block (and pkgs.uv above) if tier 1 covers you.
              if [ ! -d .venv ]; then
                ${pkgs.uv}/bin/uv venv --python ${python}/bin/python .venv >/dev/null
              fi
              source .venv/bin/activate

              echo "python $(python --version | cut -d' ' -f2) | $(ruff --version) | venv: .venv"
            '';
          };
        }
      );
    };
}
