{
  description = "Typst document with reproducible typix builds";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    typix = {
      url = "github:loqusion/typix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      typix,
      ...
    }@inputs:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        typixLib = typix.lib.${system};

        src = typixLib.cleanTypstSource ./.;

        fontPaths = [
          "${pkgs.newcomputermodern}/share/fonts/opentype"
          "${pkgs.libertinus}/share/fonts/opentype"
          "${pkgs.stix-two}/share/fonts/opentype"
          "${pkgs.dejavu_fonts}/share/fonts/truetype"
          "${pkgs.noto-fonts-cjk-sans}/share/fonts/opentype/noto-cjk"
        ];

        commonArgs = {
          typstSource = "main.typ";
          inherit fontPaths;
        };

        build-drv = typixLib.buildTypstProject (commonArgs // { inherit src; });
        build-script = typixLib.buildTypstProjectLocal (commonArgs // { inherit src; });
        watch-script = typixLib.watchTypstProject commonArgs;
      in
      {

        packages.default = build-drv;

        apps.default = flake-utils.lib.mkApp { drv = watch-script; };

        checks.default = build-drv;

        devShells.default = typixLib.devShell {
          inherit fontPaths;
          packages = [
            pkgs.typst
            pkgs.tinymist
            pkgs.typstyle
            build-script
            watch-script
          ];
        };

        templates.typst = {
          path = ./.;
          description = "Typst document with reproducible typix builds";
        };
      }
    );
}
