{
  config,
  lib,
  pkgs,
  ...
}:
let
  homeDir = config.home.homeDirectory;
  dots = "${homeDir}/dots";

  shimNames = [
    "dots-audio-input-mute"
    "dots-brightness-display"
    "dots-capture-screenrecording"
    "dots-hw-display"
    "dots-launch-audio"
    "dots-launch-bluetooth"
    "dots-launch-floating-terminal-with-presentation"
    "dots-launch-or-focus-tui"
    "dots-launch-wifi"
    "dots-screenrecord-filename"
    "dots-shell"
    "dots-swayosd-brightness"
    "dots-swayosd-client"
    "dots-theme-bg-set"
    "dots-theme-set"
    "dots-toggle-idle"
    "dots-toggle-notification-silencing"
    "dots-tz-select"
    "dots-files"
    "dots-update"
    "dots-update-available"
    "dots-voxtype-config"
    "dots-voxtype-model"
    "dots-cli"
    "dots-launch-editor"
    "dots-updates"
    "dots-weather"
    "dots-weather-status"
  ];

  setWallpaper = pkgs.writeShellApplication {
    name = "dots-set-wallpaper";
    runtimeInputs = [ pkgs.coreutils ];
    text = builtins.readFile ../scripts/dots-set-wallpaper.sh;
  };

  currentWallpaper = pkgs.writeShellApplication {
    name = "dots-current-wallpaper";
    runtimeInputs = with pkgs; [ coreutils gnused ];
    text = builtins.readFile ../scripts/dots-current-wallpaper.sh;
  };

  themeScan = pkgs.writeShellApplication {
    name = "dots-theme-scan";
    runtimeInputs = with pkgs; [ coreutils gawk gnused imagemagick ];
    text = builtins.readFile ../scripts/dots-theme-scan.sh;
  };

  pickerPalette = pkgs.writeShellApplication {
    name = "dots-picker-palette";
    runtimeInputs = with pkgs; [ coreutils gnused ];
    text = builtins.readFile ../scripts/dots-picker-palette.sh;
  };

  helpers = [
    setWallpaper
    currentWallpaper
    themeScan
    pickerPalette
  ];

  compatBase = pkgs.writeShellApplication {
    name = "dots-compat";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      gnugrep
      ghostty
      procps
      systemd
      wireplumber
    ];
    text = builtins.readFile ../scripts/dots-compat.sh;
  };

  # every shim is the same script; $0 selects the branch
  dotsShims = pkgs.runCommandLocal "dots-shims" { } ''
    mkdir -p $out/bin
    for n in ${lib.escapeShellArgs shimNames}; do
      ln -s ${compatBase}/bin/dots-compat $out/bin/$n
    done
  '';

  risePath = lib.makeBinPath (
    helpers
    ++ (with pkgs; [
      bash
      coreutils
      findutils
      gawk
      gnugrep
      gnused
      imagemagick
      libnotify
      pamixer
      procps
      pulseaudio
      systemd
      wireplumber
    ])
  );
in
{
  home.packages = helpers ++ [
    dotsShims
    pkgs.pulseaudio
    pkgs.wireplumber
    pkgs.material-symbols
    pkgs.nerd-fonts.jetbrains-mono
  ];

  programs.quickshell = {
    enable = true;
    package = pkgs.quickshell;
    activeConfig = "rise";
    systemd = {
      enable = true;
      target = "hyprland-session.target";
    };
  };

  systemd.user.services.quickshell = {
    Unit.PartOf = [ "hyprland-session.target" ];
    Service = {
      Environment = [
        "PATH=${risePath}:${dotsShims}/bin:/etc/profiles/per-user/${config.home.username}/bin:${homeDir}/.nix-profile/bin:/run/wrappers/bin:/run/current-system/sw/bin"
        "DOTS_SHELL_PATH=${dots}/config/quickshell/rise"
      ];
      Slice = "app-graphical.slice";
      KillMode = "process";
      RestartSec = 2;
    };
  };
}
