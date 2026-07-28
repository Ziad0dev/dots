# DaVinci Resolve — wrapped so it survives being launched from a Qt desktop.
#
# Two problems this solves:
#   1. Resolve can't run on native Wayland (its bundled Qt 5.15 vs qtwayland
#      version mismatch), so it has to go through XWayland — QT_QPA_PLATFORM=xcb.
#   2. Resolve ships its own Qt. If the session exports QT_PLUGIN_PATH (Plasma
#      does), Resolve loads nixpkgs' Qt plugins into its own Qt and segfaults on
#      startup. The --unset lines strip that inherited env.
#
# symlinkJoin keeps the .desktop file and icon, so the menu launcher picks up
# the wrapper too — which is the path that actually needs it.
{ pkgs, ... }:
let
  resolve = pkgs.symlinkJoin {
    name = "davinci-resolve-wrapped";
    paths = [ pkgs.davinci-resolve ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/davinci-resolve \
        --set QT_QPA_PLATFORM xcb \
        --unset QT_PLUGIN_PATH \
        --unset QT_QPA_PLATFORM_PLUGIN_PATH \
        --unset QT_STYLE_OVERRIDE \
        --unset QML2_IMPORT_PATH
    '';
  };
in
{
  # ffmpeg-full for the DNxHR transcode step — the free edition of Resolve has
  # no H.264/H.265 and no AAC on Linux, so normal MP4s need converting first.
  # See the `dnx` fish function in home.nix.
  environment.systemPackages = [ resolve pkgs.ffmpeg-full ];
}
