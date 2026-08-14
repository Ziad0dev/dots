{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{

  programs.nh = {
    enable = true;
    flake = "/home/ziad0dev/dots";
    clean = {
      enable = true;
      extraArgs = "--keep 3 --keep-since 4d";
    };
  };

  nix.settings.warn-dirty = false;

  nix.registry.nixpkgs.flake = inputs.nixpkgs;
  nix.nixPath = [ "nixpkgs=flake:nixpkgs" ];

}
