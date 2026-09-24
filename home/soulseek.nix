{ pkgs, config, ... }:
let
  python = pkgs.python3.withPackages (ps: [
    ps.mutagen
    ps.musicbrainzngs
  ]);
  album-doctor = pkgs.writeShellApplication {
    name = "album-doctor";
    runtimeInputs = [
      pkgs.soulseek-rs
      pkgs.yt-dlp
    ];
    text = ''exec ${python}/bin/python3 ${../scripts/album-doctor.py} "$@"'';
  };
in
{
  home.packages = [
    pkgs.soulseek-rs
    album-doctor
  ];

  programs.beets = {
    enable = true;
    settings = {
      directory = "/mnt/media/music";
      library = "${config.xdg.dataHome}/beets/library.db";
      plugins = [
        "musicbrainz"
        "fromfilename"
        "missing"
        "duplicates"
      ];
      match = {
        strong_rec_thresh = 0.10;
        max_rec.missing_tracks = "strong";
        preferred = {
          media = [
            "Digital Media"
            "CD"
          ];
          original_year = true;
        };
      };
      import = {
        move = true;
        write = true;
        log = "${config.xdg.dataHome}/beets/import.log";
        quiet_fallback = "skip";
        duplicate_action = "skip";
        incremental = true;
        incremental_skip_later = true;
      };
      paths = {
        default = "$albumartist/$album%aunique{}/$track $title";
        comp = "Compilations/$album%aunique{}/$track $title";
        singleton = "Non-Album/$artist/$title";
      };
    };
  };

  xdg.dataFile."beets/.keep".text = "";

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
