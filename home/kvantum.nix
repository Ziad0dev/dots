{ pkgs, ... }:

{
  home.packages = with pkgs; [
    libsForQt5.qtstyleplugin-kvantum
    kdePackages.qtstyleplugin-kvantum
  ];

  qt = {
    enable = true;
    platformTheme.name = "kde";
    style.name = "kvantum";
  };

  qt.kvantum = {
    enable = true;
    settings.General.theme = "KvGlass";
  };
}
