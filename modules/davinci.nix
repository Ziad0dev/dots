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

  environment.systemPackages = [
    resolve
    pkgs.ffmpeg-full
  ];
}
