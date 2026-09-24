{ ... }:
{
  programs.sway = {
    enable = true;
    extraOptions = [ "--unsupported-gpu" ];
    extraPackages = [ ];
    extraSessionCommands = ''
      export XDG_SESSION_TYPE=wayland
      export XDG_SESSION_DESKTOP=sway
      export WLR_RENDERER=vulkan
      export GDK_BACKEND=wayland,x11
      export CLUTTER_BACKEND=wayland
      export QT_QPA_PLATFORMTHEME=qt6ct
      export XCURSOR_THEME=Bibata-Modern-Classic
      export XCURSOR_SIZE=24
    '';
  };

  systemd.user.targets.sway-session.unitConfig.PropagatesStopTo = [ "graphical-session.target" ];
}
