{
  # ───────────────────────────────────────────────────────────────────────
  # Python dev environment — self-contained template flake
  #
  # Location:   ~/dots/templates/python/flake.nix   (this file, committed)
  #
  # This flake is self-referential: it IS the dev environment *and* it
  # exposes itself as a template, so no changes to your root dots flake
  # are strictly required.
  #
  # New project:
  #   mkdir ~/projects/thing && cd ~/projects/thing
  #   nix flake init -t path:$HOME/dots/templates/python
  #   git init && git add . && direnv allow    # .envrc is auto-created
  #
  # Optional nicety — short alias via the registry (system or HM config):
  #   nix.registry.pydev.to = {
  #     type = "git"; url = "file:///home/ziad0dev/dots"; dir = "templates/python";
  #   };
  # then:  nix flake init -t pydev
  # ───────────────────────────────────────────────────────────────────────

  description = "Python devshell: nix-first with uv escape hatch";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      eachSystem = f: nixpkgs.lib.genAttrs systems
        (system: f nixpkgs.legacyPackages.${system});
    in
    {
      # This flake offers itself as a template.
      templates = {
        python = {
          path = ./.;
          description = "Python devshell: nix-first with uv escape hatch";
        };
        default = self.templates.python;
      };

      devShells = eachSystem (pkgs:
        let
          # ── Tier 1: pure nix — everything that exists in nixpkgs ──────
          # Check availability:  nix search nixpkgs python312Packages.<name>
          python = pkgs.python312.withPackages (ps: with ps; [
            requests
            # numpy
            # httpx
            # rich
          ]);
        in
        {
          default = pkgs.mkShell {
            packages = [
              python
              pkgs.ruff        # lint + format (replaces black/flake8/isort)
              pkgs.pyright     # LSP — matches the nvim lsp setup
              pkgs.uv          # tier-2 escape hatch below
            ];

            # ── Tier 2: uv/pip wheels missing from nixpkgs ───────────────
            # manylinux wheels dlopen system libs at FHS paths that don't
            # exist on NixOS; exposing them here makes `uv pip install`
            # just work inside the shell.
            env.LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
              pkgs.stdenv.cc.cc.lib   # libstdc++ (numpy/scipy/torch wheels)
              pkgs.zlib
              pkgs.openssl
              # pkgs.libGL            # opencv / anything GL
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
        });
    };
}
