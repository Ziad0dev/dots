{ pkgs, ... }:
let
  python = pkgs.python313.withPackages (ps: [
    ps.mutagen
    ps.musicbrainzngs
  ]);

  albumDoctor = pkgs.writeShellApplication {
    name = "album-doctor";
    runtimeInputs = [ pkgs.soulseek-rs ];
    text = ''exec ${python}/bin/python3 ${../scripts/album-doctor.py} "$@"'';
  };
in
{
  home.packages = [
    pkgs.soulseek-rs
    albumDoctor
  ];

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
