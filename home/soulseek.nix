{ pkgs, config, ... }:
let
  staging = "/mnt/media/slsk";

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

  music-fill = pkgs.writeShellApplication {
    name = "music-fill";
    runtimeInputs = [
      album-doctor
      config.programs.beets.package
      pkgs.findutils
      pkgs.gnugrep
      pkgs.coreutils
      pkgs.flac
    ];
    text = ''
      report="$HOME/music-fill-report.txt"

      clean() {
        find ${staging} -name '*.part' -delete
        find ${staging} -name '*.flac' -print0 | while IFS= read -r -d "" f; do
          flac -st "$f" 2>/dev/null || { echo "broken: $f"; rm -f -- "$f"; }
        done
      }

      echo "== pass 1: soulseek"
      album-doctor --go --transfer-timeout 120 "$@" || true
      echo "waiting for transfers to settle"
      while find ${staging} -type f -mmin -2 -print -quit | grep -q .; do
        sleep 30
      done
      clean
      beet import -q -g ${staging} || true

      echo "== pass 2: youtube music"
      album-doctor --go --ytmusic "$@" || true
      clean
      beet import -q -g ${staging} || true

      echo "== report"
      album-doctor "$@" > "$report" 2>/dev/null || true
      tail -n 1 "$report"
      echo "full list: $report"
      echo "left in staging (needs a manual 'beet import -g ${staging}'):"
      find ${staging} -type f \( -name '*.flac' -o -name '*.mp3' -o -name '*.opus' -o -name '*.m4a' \) \
        -not -path '*/dupes/*' -not -path '*/superseded/*' | wc -l
    '';
  };
  # Nicotine+ "run command after folder finishes" hook: afterfolder = slsk-import $
  slsk-import = pkgs.writeShellApplication {
    name = "slsk-import";
    runtimeInputs = [
      config.programs.beets.package
      pkgs.coreutils
      pkgs.findutils
      pkgs.util-linux
      pkgs.libnotify
    ];
    text = ''
      src="$1"
      [ -d "$src" ] || exit 0
      log="${config.xdg.stateHome}/slsk-import.log"
      mkdir -p ${staging} "$(dirname "$log")"
      exec >>"$log" 2>&1

      name="$(basename "$src")"
      dest="${staging}/$name"
      [ -e "$dest" ] && dest="$dest.$(date +%s)"
      echo "== $(date -Is) $src -> $dest"
      mv -- "$src" "$dest"

      # one beets run at a time; the library is a single sqlite db
      flock "''${XDG_RUNTIME_DIR:-/tmp}/slsk-import.lock" beet import -q "$dest" || true
      find "$dest" -depth -type d -empty -delete 2>/dev/null || true

      if [ -d "$dest" ]; then
        notify-send -a Nicotine+ "beets skipped: $name" "left in ${staging}, run: beet import ${staging}" || true
      else
        notify-send -a Nicotine+ "Imported: $name" || true
      fi
    '';
  };
in
{
  home.packages = [
    pkgs.soulseek-rs
    pkgs.flac
    pkgs.mp3val
    album-doctor
    music-fill
    slsk-import
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
        "fetchart"
        "badfiles"
        "unimported"
        "edit"
        "info"
        "mbsync"
      ];
      ignore = [
        ".*"
        "*~"
        "System Volume Information"
        "lost+found"
        "*.part"
        "superseded"
        "dupes"
      ];
      clutter = [
        "Thumbs.DB"
        ".DS_Store"
        "*.nfo"
        "*.log"
        "*.cue"
        "*.m3u"
        "*.m3u8"
        "*.txt"
        "*.url"
      ];
      match = {
        strong_rec_thresh = 0.10;
        max_rec.missing_tracks = "strong";
        ignored_media = [
          "Data CD"
          "DVD"
          "DVD-Video"
          "DVD-Audio"
          "Blu-ray"
          "HD-DVD"
          "VCD"
          "SVCD"
          "UMD"
          "VHS"
        ];
        preferred = {
          media = [
            "Digital Media"
            "CD"
          ];
          original_year = true;
        };
      };
      musicbrainz.extra_tags = [
        "year"
        "catalognum"
        "country"
        "media"
        "label"
      ];
      import = {
        move = true;
        write = true;
        log = "${config.xdg.dataHome}/beets/import.log";
        quiet_fallback = "skip";
        duplicate_action = "merge";
        incremental = true;
        incremental_skip_later = true;
        bell = true;
      };
      fetchart = {
        auto = true;
        cautious = true;
        minwidth = 500;
        cover_names = [
          "cover"
          "front"
          "folder"
          "art"
          "album"
        ];
      };
      unimported.ignore_extensions = [
        "jpg"
        "jpeg"
        "png"
        "webp"
        "cue"
        "log"
        "nfo"
        "txt"
        "m3u"
        "m3u8"
      ];
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
      StartLimitIntervalSec = 3600;
      StartLimitBurst = 6;
    };
    Service = {
      ExecStart = "${pkgs.soulseek-rs}/bin/soulseek-rs daemon";
      Environment = [
        "SOULSEEK_SERVER=server.slsknet.org:2242"
        "SOULSEEK_LISTENER_PORT=2234"
      ];
      Restart = "on-failure";
      RestartSec = 120;
    };
  };
}
