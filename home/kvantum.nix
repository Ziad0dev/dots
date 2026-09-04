{ ... }:

{
  qt = {
    enable = true;
    platformTheme.name = "qtct";
    style.name = "kvantum";
    qt5ctSettings.Appearance.style = "kvantum";
    qt6ctSettings.Appearance.style = "kvantum";
    qt5ctSettings.Appearance.icon_theme = "candy-icons";
    qt6ctSettings.Appearance.icon_theme = "candy-icons";
  };

  qt.kvantum = {
    enable = true;
    settings.General.theme = "KvGlass";
  };
}
