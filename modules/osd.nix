{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.swayosd ];

  systemd.services.swayosd-libinput-backend = {
    description = "SwayOSD libinput backend";
    wantedBy = [ "graphical.target" ];
    partOf = [ "graphical.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.swayosd}/bin/swayosd-libinput-backend";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };
}
