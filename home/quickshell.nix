{
  config,
  lib,
  pkgs,
  ...
}:
let
  homeDir = config.home.homeDirectory;
  dots = "${homeDir}/dots";

  themeScan = pkgs.writeShellApplication {
    name = "dots-theme-scan";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      gnused
      imagemagick
    ];
    text = builtins.readFile ../scripts/dots-theme-scan.sh;
  };

  setWallpaper = pkgs.writeShellApplication {
    name = "dots-set-wallpaper";
    runtimeInputs = [ pkgs.coreutils ];
    text = builtins.readFile ../scripts/dots-set-wallpaper.sh;
  };

  currentWallpaper = pkgs.writeShellApplication {
    name = "dots-current-wallpaper";
    runtimeInputs = with pkgs; [
      coreutils
      gnused
    ];
    text = builtins.readFile ../scripts/dots-current-wallpaper.sh;
  };

  pickerPalette = pkgs.writeShellApplication {
    name = "dots-picker-palette";
    runtimeInputs = with pkgs; [
      coreutils
      gnused
    ];
    text = builtins.readFile ../scripts/dots-picker-palette.sh;
  };

  helpers = [
    themeScan
    setWallpaper
    currentWallpaper
    pickerPalette
  ];

  pickerPath = lib.makeBinPath (
    helpers
    ++ (with pkgs; [
      bash
      coreutils
      findutils
      gawk
      gnused
      imagemagick
    ])
  );
in
{
  home.packages = helpers ++ [
    pkgs.imagemagick
    pkgs.material-symbols
  ];

  programs.quickshell = {
    enable = true;
    package = pkgs.quickshell;
    activeConfig = "picker";
    systemd = {
      enable = true;
      target = "hyprland-session.target";
    };
  };

  systemd.user.services.quickshell = {
    Unit.PartOf = [ "hyprland-session.target" ];
    Service = {
      Environment = [
        "PATH=${pickerPath}:/etc/profiles/per-user/${config.home.username}/bin:${homeDir}/.nix-profile/bin:/run/wrappers/bin:/run/current-system/sw/bin"
      ];
      Slice = "app-graphical.slice";
      RestartSec = 2;
    };
  };
}
