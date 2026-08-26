{ pkgs, lib, config, ... }:

{
  # Pull in both Qt5 and Qt6 engines (needed for mixed apps)
  home.packages = with pkgs; [
    libsForQt5.qtstyleplugin-kvantum
    kdePackages.qtstyleplugin-kvantum   # or qt6Packages.qtstyleplugin-kvantum
  ];

  qt = {
    enable = true;
    # Keep KDE platform theme so Plasma integration stays intact.
    # Switch to "kvantum" only if you want pure Kvantum platform behaviour.
    platformTheme.name = "kde";
    style.name = "kvantum";
  };

  qt.kvantum = {
    enable = true;

    # Optional: set a default theme. Leave empty if you manage themes
    # via kvantummanager or your themectl pipeline.
    settings = {
      General = {
        theme = "KvAdapta";          # change to whatever theme you prefer
        # other keys from kvantum.kvconfig can go here
      };
      # Applications = {
      #   SomeTheme = [ "dolphin" "kate" ];
      # };
    };

    # Optional: ship extra theme packages
    # themes = with pkgs; [
    #   catppuccin-kvantum
    #   gruvbox-kvantum
    # ];
  };
}
