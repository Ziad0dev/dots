{ pkgs, ... }:

{

  boot.kernelPackages = pkgs.linuxPackages_cachyos-bore;

  services.scx = {
    enable = false;
    scheduler = "scx_lavd";
  };

  programs.steam = {
    enable = true;
    # Steam with Millennium, for client themes (home/gaming-home.nix)
    package = pkgs.millennium-steam;
    gamescopeSession.enable = true;

    extraCompatPackages = [
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

}
