{
  config,
  lib,
  pkgs,
  ...
}:
let
  link = config.lib.file.mkOutOfStoreSymlink;
  dots = config.dots.repoPath;
in
{
  programs.yazi = {
    enable = true;
    shellWrapperName = "y";
    enableFishIntegration = true;

    extraPackages = with pkgs; [
      _7zz
      chafa
      exiftool
      fd
      ffmpeg-full
      file
      fzf
      glow
      imagemagick
      jq
      lazygit
      mediainfo
      miller
      ouch
      poppler-utils
      ripgrep
      zoxide
    ];

    plugins = lib.genAttrs [
      "chmod"
      "diff"
      "full-border"
      "git"
      "jump-to-char"
      "mount"
      "ouch"
      "piper"
      "relative-motions"
      "restore"
      "smart-enter"
      "smart-filter"
      "starship"
      "toggle-pane"
    ] (n: pkgs.yaziPlugins.${n});
  };

  xdg.configFile = {
    "yazi/yazi.toml".source = link "${dots}/config/yazi/yazi.toml";
    "yazi/keymap.toml".source = link "${dots}/config/yazi/keymap.toml";
    "yazi/init.lua".source = link "${dots}/config/yazi/init.lua";
    "yazi/theme.toml".source = link "${config.xdg.stateHome}/dots/theme/yazi.toml";
  };
}
