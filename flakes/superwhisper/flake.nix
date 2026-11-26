{
  description = "Superwhisper dictation for NixOS (packaged release archive)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAll = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAll (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            # the app is proprietary
            config.allowUnfreePredicate = pkg: nixpkgs.lib.getName pkg == "superwhisper";
          };
        in
        rec {
          superwhisper = pkgs.callPackage ./package.nix { };
          default = superwhisper;
        }
      );

      # imports = [ superwhisper.homeManagerModules.default ];
      # services.superwhisper.enable = true;
      homeManagerModules.default = import ./module.nix;

      formatter = forAll (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}
