{ lib, ... }:

{
  qt = {
    enable = true;
    platformTheme.name = "qtct";
    style.name = "kvantum";
    # qt5ct.conf/qt6ct.conf (style=kvantum, icon theme, fonts) are written by
    # dots-appearance (home/desktop-tools.nix), so they can change at runtime
  };

  # kvantum.kvconfig (which theme) is written by dots-appearance: "KvGlass#",
  # the copy themectl recolours, unless a theme's look.conf names another
  qt.kvantum.enable = true;
  # the module's settings default is never {} (General.theme = null), so it
  # always writes a "theme=null" kvantum.kvconfig that would fight the above
  xdg.configFile."Kvantum/kvantum.kvconfig".enable = lib.mkForce false;
}
