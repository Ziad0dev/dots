{
  config,
  pkgs,
  inputs,
  lib,
  ...
}:
let
  theme = config.dots.theme;

  palette =
    let
      raw = builtins.readFile ../config/themes/${theme}/colors.sh;
      lines = lib.splitString "\n" raw;
      parse =
        line:
        let
          m = builtins.match "([a-zA-Z0-9_]+)=\"#([0-9a-fA-F]{6})\"" line;
        in
        if m == null then null else lib.nameValuePair (builtins.elemAt m 0) (builtins.elemAt m 1);
    in
    lib.listToAttrs (builtins.filter (x: x != null) (map parse lines));

  hexChars = "0123456789abcdef";
  hexVal =
    c:
    {
      "0" = 0;
      "1" = 1;
      "2" = 2;
      "3" = 3;
      "4" = 4;
      "5" = 5;
      "6" = 6;
      "7" = 7;
      "8" = 8;
      "9" = 9;
      "a" = 10;
      "b" = 11;
      "c" = 12;
      "d" = 13;
      "e" = 14;
      "f" = 15;
    }
    .${lib.toLower c};
  byte = s: i: (hexVal (builtins.substring i 1 s)) * 16 + hexVal (builtins.substring (i + 1) 1 s);
  hex2 =
    n:
    (builtins.substring (builtins.div n 16) 1 hexChars) + (builtins.substring (lib.mod n 16) 1 hexChars);
  mix =
    a: b: w:
    lib.concatMapStrings (i: hex2 (builtins.div ((byte a i) * (100 - w) + (byte b i) * w) 100)) [
      0
      2
      4
    ];

  fg = palette.foreground;
  bg = palette.background;
  inherit (palette) accent;

  dim = mix fg bg 35;
  muted = mix fg bg 60;
  surface = mix bg fg 8;
  elevated = mix bg fg 18;
  horizon = mix bg accent 12;

  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [ inputs.spicetify-nix.homeManagerModules.default ];

  programs.spicetify = {
    enable = true;

    theme = spicePkgs.themes.starryNight;

    enabledExtensions = with spicePkgs.extensions; [
      hidePodcasts
      fullAppDisplayMod
      featureShuffle
      playNext
      showQueueDuration
      volumePercentage
      autoVolume
      history
      songStats
      seekSong
      powerBar
      sleepTimer
      copyToClipboard
      listPlaylistsWithSong
    ];

    enabledCustomApps = with spicePkgs.apps; [
      marketplace
      lyricsPlus
      betterLibrary
      historyInSidebar
      newReleases
    ];

    customColorScheme = {
      text = fg;
      subtext = dim;
      misc = muted;

      main = bg;
      "main-elevated" = surface;
      card = elevated;
      highlight = surface;
      "highlight-elevated" = elevated;
      shadow = bg;

      sidebar = horizon;
      "sidebar-alt" = bg;
      player = bg;

      button = accent;
      "button-active" = accent;
      "button-disabled" = muted;
      "tab-active" = surface;
      "selected-row" = fg;

      notification = accent;
      "notification-error" = palette.red;

      star = fg;
      "star-glow" = accent;
      "shooting-star" = fg;
      "shooting-star-glow" = accent;
    };
  };
}
