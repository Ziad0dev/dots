{
  config,
  lib,
  pkgs,
  username,
  ...
}:

{

  programs.nh = {
    enable = true;
    flake = config.dots.repoPath;
    clean = {
      enable = true;
      extraArgs = "--keep 3 --keep-since 4d";
    };
  };

  nix.settings.warn-dirty = false;

}
