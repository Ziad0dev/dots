{ ... }:

{
  qt = {
    enable = true;
    platformTheme.name = "qtct";
    style.name = "kvantum";
    # qt5ct.conf/qt6ct.conf (style=kvantum, icon theme, fonts) are written by
    # dots-appearance (home/desktop-tools.nix), so they can change at runtime
  };

  qt.kvantum = {
    enable = true;
    # the "#" copy themectl writes (KvGlass + the theme's colours and
    # translucency); plain "KvGlass" never picked up the colours
    settings.General.theme = "KvGlass#";
  };
}
