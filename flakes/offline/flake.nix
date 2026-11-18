{
  description = "Offline knowledge, maps and AI for when the internet is gone";

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
      # imports = [ offline.nixosModules.default ]; then set zi.offline.*
      nixosModules.default = import ./module.nix;

      packages = forAll (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            # open-webui's licence counts as unfree
            config.allowUnfree = true;
          };
        in
        import ./packages.nix { inherit pkgs; }
      );

      formatter = forAll (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}
