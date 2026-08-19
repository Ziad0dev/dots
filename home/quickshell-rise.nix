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
    "omarchy-audio-input-mute"
    "omarchy-brightness-display"
    "omarchy-capture-screenrecording"
    "omarchy-hw-display"
    "omarchy-launch-audio"
    "omarchy-launch-bluetooth"
    "omarchy-launch-floating-terminal-with-presentation"
    "omarchy-launch-or-focus-tui"
    "omarchy-launch-wifi"
    "omarchy-screenrecord-filename"
    "omarchy-shell"
    "omarchy-swayosd-brightness"
    "omarchy-swayosd-client"
    "omarchy-theme-bg-set"
    "omarchy-theme-set"
    "omarchy-toggle-idle"
    "omarchy-toggle-notification-silencing"
    "omarchy-tz-select"
    "omarchy-update"
    "omarchy-update-available"
    "omarchy-voxtype-config"
    "omarchy-voxtype-model"
    "omarchy-weather"
    "omarchy-weather-status"
  ];

  compatBase = pkgs.writeShellApplication {
    name = "omarchy-compat";
    runtimeInputs = with pkgs; [
      coreutils
      gnugrep
      procps
      wireplumber
    ];
    text = builtins.readFile ../scripts/omarchy-compat.sh;
  };

  # every shim is the same script; $0 selects the branch
  omarchyShims = pkgs.runCommandLocal "omarchy-shims" { } ''
    mkdir -p $out/bin
    for n in ${lib.escapeShellArgs shimNames}; do
      ln -s ${compatBase}/bin/omarchy-compat $out/bin/$n
    done
  '';

  risePath = lib.makeBinPath (
    with pkgs;
    [
      bash
      coreutils
      findutils
      gawk
      gnugrep
      gnused
      imagemagick
      procps
      wireplumber
    ]
  );
in
{
  home.packages = [
    omarchyShims
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
        "PATH=${risePath}:${omarchyShims}/bin:/etc/profiles/per-user/${config.home.username}/bin:${homeDir}/.nix-profile/bin:/run/wrappers/bin:/run/current-system/sw/bin"
        "OMARCHY_PATH=${dots}/config/quickshell/rise"
      ];
      Slice = "app-graphical.slice";
      RestartSec = 2;
    };
  };
}
