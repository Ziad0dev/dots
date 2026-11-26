{ pkgs, ... }:

{

  boot.kernelPackages = pkgs.linuxPackages_cachyos-bore;

  services.scx-loader = {
    enable = false;
    config.default_sched = "scx_lavd";
  };

  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;

    extraCompatPackages = [
      pkgs.proton-cachyos-bin_edge
    ];
    remotePlay.openFirewall = false;
    dedicatedServer.openFirewall = false;
  };

  programs.gamemode.enable = true;

  services.ananicy = {
    enable = true;
    package = pkgs.ananicy-cpp;
    # The CachyOS rules give shells the "Doc-View" type, nice -4, so every shell-script job and all
    # it starts ran above normal priority, even under `systemd-run -p Nice=19` (a test run starved
    # the desktop and pushed it into swap). Shells are dropped; terminals keep their rule, and a
    # shell opened in one inherits its priority, so interactive windows stay snappy.
    rulesProvider = pkgs.runCommand "ananicy-rules-cachyos-no-shells" { } ''
      cp -r ${pkgs.ananicy-rules-cachyos_git} $out
      chmod -R u+w $out
      rm "$out/etc/ananicy.d/00-default/Terminals & Shells/"{bash,zsh,fish,dash,ksh,tcsh,nu}.rules
      if grep -rqE '"name": ?"(bash|zsh|fish|dash|sh|ksh|tcsh|nu)"' $out; then
        echo "a shell still has an ananicy rule; update the list above" >&2
        exit 1
      fi
    '';
  };

  environment.systemPackages = with pkgs; [

    protonup-qt
    heroic
  ];

}
