{ pkgs, ... }:
let
  kdeconnect = pkgs.kdePackages.kdeconnect-kde;

  # RQuickShare's WebKitGTK window renders blank on NVIDIA with compositing mode on
  # (its README, "blank window"); the fix is this variable, so it's set for every launch
  rquickshare = pkgs.symlinkJoin {
    name = "rquickshare-nvidia-fix";
    paths = [ pkgs.rquickshare ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/rquickshare --set-default WEBKIT_DISABLE_COMPOSITING_MODE 1
    '';
  };

  phone = pkgs.writeShellApplication {
    name = "dots-phone";
    runtimeInputs = with pkgs; [
      kdeconnect
      scrcpy
      android-tools
      qrencode
      imv
      wl-clipboard
      libnotify
      networkmanager # nmcli, for wifi-qr
      zenity
      fuzzel
      jq
      procps
      coreutils
      gnused
      gawk
      gnugrep
      systemd
      rquickshare
    ];
    text = builtins.readFile ../scripts/dots-phone.sh;
  };
in
{
  # Phones as part of the desktop (docs/desktop.md → Phone). The firewall ports, the webcam
  # loopback device and the port/device numbers are in modules/phone.nix.

  # KDE Connect: notifications, clipboard both ways, SMS, media, files, ring, remote input.
  # Android and iPhone (the iOS app does less: iOS limits it)
  services.kdeconnect = {
    enable = true;
    indicator = true; # tray icon: devices, battery, send file
    package = kdeconnect;
  };

  home.packages = [
    phone
    rquickshare
    pkgs.scrcpy
    pkgs.android-tools # adb, for scrcpy and wireless debugging
    pkgs.qrencode
  ];
}
