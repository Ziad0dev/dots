{ pkgs, ... }:
{
  home.packages = [ pkgs.soulseek-rs ];

  systemd.user.services.soulseek-rs = {
    Unit = {
      Description = "Soulseek session shared by every soulseek-rs command";
      RequiresMountsFor = [ "/mnt/media" ];
    };
    Service = {
      ExecStart = "${pkgs.soulseek-rs}/bin/soulseek-rs daemon";
      Restart = "always";
      RestartSec = 5;
    };
  };
}
