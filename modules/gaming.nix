{ pkgs, username, ... }:

{

  boot.kernelPackages = pkgs.linuxPackages_cachyos;

  services.scx = {
    enable = true;
    scheduler = "scx_lavd";
  };

  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;

    extraCompatPackages = [
      pkgs.proton-ge-bin
      pkgs.proton-cachyos
    ];
    remotePlay.openFirewall = false;
    dedicatedServer.openFirewall = false;
  };

  programs.gamemode.enable = true;

  services.ananicy = {
    enable = true;
    package = pkgs.ananicy-cpp;
    rulesProvider = pkgs.ananicy-rules-cachyos_git;
  };

  environment.systemPackages = with pkgs; [

    protonup-qt
    heroic
  ];

  systemd.tmpfiles.rules = [
    "d /data/games 0755 ${username} users -"
  ];
}
