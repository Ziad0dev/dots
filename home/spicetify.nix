{
  pkgs,
  inputs,
  lib,
  ...
}:
let
  theme = "kanagawa";

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

  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [ inputs.spicetify-nix.homeManagerModules.default ];

  programs.spicetify = {
    enable = true;

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
      text = palette.foreground;
      subtext = palette.color8;
      main = palette.background;
      sidebar = palette.background;
      player = palette.background;
      card = palette.color0;
      shadow = palette.color0;
      "selected-row" = palette.accent;
      button = palette.accent;
      "button-active" = palette.accent;
      "button-disabled" = palette.color8;
      "tab-active" = palette.accent;
      notification = palette.accent;
      "notification-error" = palette.color1;
      misc = palette.color8;
    };
  };
}
