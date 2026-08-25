{
  description = "LaTeX document with latexmk and reproducible nix builds";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachSystem [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ] (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        tex = pkgs.texliveMedium.withPackages (ps: [
          ps.latexmk
          ps.biblatex
          ps.biber
          ps.microtype
          ps.enumitem
          ps.booktabs
          ps.siunitx
        ]);

        mainDoc = "main";
      in
      {
        packages.default = pkgs.stdenvNoCC.mkDerivation {
          pname = "document";
          version = "0.1.0";
          src = ./.;

          nativeBuildInputs = [
            tex
            pkgs.coreutils
          ];

          buildPhase = ''
            runHook preBuild

            # latexmk wants somewhere to write; the sandbox has no $HOME.
            export HOME=$TMPDIR
            export TEXMFHOME=$TMPDIR/texmf
            export TEXMFVAR=$TMPDIR/texmf-var

            # pdfTeX stamps /CreationDate into the PDF. These two make it
            # deterministic — without them, no two builds hash the same.
            export SOURCE_DATE_EPOCH=''${SOURCE_DATE_EPOCH:-0}
            export FORCE_SOURCE_DATE=1

            latexmk \
              -pdf \
              -interaction=nonstopmode \
              -halt-on-error \
              -file-line-error \
              -synctex=1 \
              -outdir=build \
              ${mainDoc}.tex

            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            install -Dm644 build/${mainDoc}.pdf $out/${mainDoc}.pdf
            runHook postInstall
          '';
        };

        checks.default = pkgs.stdenvNoCC.mkDerivation {
          name = "document-check";
          src = ./.;
          nativeBuildInputs = [ tex ];
          buildPhase = ''
            export HOME=$TMPDIR
            chktex -q -n 1 -n 3 -n 8 ${mainDoc}.tex | tee chktex.log
            test ! -s chktex.log
          '';
          installPhase = "touch $out";
        };

        devShells.default = pkgs.mkShell {
          packages = [
            tex
            pkgs.texlab
            pkgs.zathura
          ];
          shellHook = ''
            echo "latexmk -pvc -pdf ${mainDoc}.tex   # continuous rebuild"
          '';
        };
      }
    )
    // {
      templates.latex = {
        path = ./.;
        description = "LaTeX document with latexmk and reproducible nix builds";
      };
    };
}
