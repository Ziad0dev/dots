{
  config,
  lib,
  pkgs,
  inputs,
  username,
  ...
}:

{

  programs.nh = {
    enable = true;
    flake = "/home/${username}/dots";
    clean = {
      enable = true;
      extraArgs = "--keep 3 --keep-since 4d";
    };
  };

  nix.settings.warn-dirty = false;

  nix.registry.nixpkgs.flake = inputs.nixpkgs;
  nix.nixPath = [ "nixpkgs=flake:nixpkgs" ];

}
