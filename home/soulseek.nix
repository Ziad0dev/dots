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

  # new releases from library artists, and similar artists (the bar's media
  # panel calls `music-scout similar --json`)
  music-scout = pkgs.writeShellApplication {
    name = "music-scout";
    text = ''exec ${python}/bin/python3 ${../scripts/music-scout.py} "$@"'';
  };

  # Open a search tab in Nicotine+, starting it if need be. The Discover panel
  # calls this; scripts/nicotine-bridge is the plugin on the other end.
  slsk-search = pkgs.writeShellApplication {
    name = "slsk-search";
    runtimeInputs = [
      pkgs.nicotine-plus
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gnused
      pkgs.procps
      pkgs.util-linux
      pkgs.libnotify
    ];
    text = ''
      query="$*"
      [ -n "$query" ] || { echo "usage: slsk-search QUERY" >&2; exit 2; }

      queue="$XDG_RUNTIME_DIR/slsk-search"
      mkdir -p "$queue"
      tmp="$(mktemp "$queue/.XXXXXX")"
      printf '%s' "$query" > "$tmp"
      mv "$tmp" "$queue/$(date +%s%N)"

      # Nicotine+ owns its config file, so the plugin can't be enabled from
      # nix; switch it on here, while the client isn't running to overwrite it.
      cfg="${config.xdg.configHome}/nicotine/config"
      if [ -f "$cfg" ] && ! grep -q dots_bridge "$cfg"; then
        if pgrep -f 'bin/\.?nicotine' >/dev/null; then
          notify-send -a Nicotine+ "Search queued: $query" \
            "Restart Nicotine+ once (or enable Dots Bridge under Preferences › Plugins) to run it." || true
        else
          sed -i "/^\[plugins\]/,/^\[/ s/^enabled = \[/enabled = ['dots_bridge', /" "$cfg"
        fi
      fi

      # a second launch only raises the window of the one already running
      setsid -f nicotine >/dev/null 2>&1
    '';
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
      app="''${IMPORT_APP:-Nicotine+}"
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
        notify-send -a "$app" "beets skipped: $name" "left in ${staging}, run: beet import ${staging}" || true
      else
        notify-send -a "$app" "Imported: $name" || true
      fi
    '';
  };

  # Bought albums: every zip of audio that lands in ~/Downloads (a Bandcamp or
  # Qobuz purchase) is unpacked and handed to beets, then filed under
  # ~/Downloads/imported-music so it is kept but not picked up twice. The
  # music-buy-import path unit below runs this whenever the folder changes.
  music-buy-import = pkgs.writeShellApplication {
    name = "music-buy-import";
    runtimeInputs = [
      slsk-import
      pkgs.unzip
      pkgs.coreutils
      pkgs.findutils
      pkgs.gnugrep
      pkgs.util-linux
      pkgs.libnotify
    ];
    text = ''
      downloads="''${1:-$HOME/Downloads}"
      exec 9>"''${XDG_RUNTIME_DIR:-/tmp}/music-buy-import.lock"
      flock -n 9 || exit 0

      sleep 3   # let the browser finish renaming its partial file
      find "$downloads" -maxdepth 1 -type f -iname '*.zip' -print0 | while IFS= read -r -d "" zip; do
        # only archives that are mostly music; a game mod with a few sound
        # files, or anything else in Downloads, is left alone
        files="$(unzip -Z1 "$zip" 2>/dev/null | grep -v '/$' || true)"
        audio="$(grep -ciE '\.(flac|mp3|m4a|wav|aiff?|ogg|opus)$' <<<"$files" || true)"
        total="$(grep -c . <<<"$files" || true)"
        [ "$audio" -gt 0 ] && [ $((audio * 2)) -ge "$total" ] || continue
        # still being written (or damaged): the next change to the folder retries
        unzip -tqq "$zip" >/dev/null 2>&1 || continue

        name="$(basename "$zip")"
        name="''${name%.[zZ][iI][pP]}"
        work="$(mktemp -d ${staging}/.buy.XXXXXX)"
        # </dev/null: beets must not read the rest of this loop's file list
        if unzip -qq "$zip" -d "$work/$name" </dev/null; then
          mkdir -p "$downloads/imported-music"
          kept="$downloads/imported-music/$(basename "$zip")"
          # bought twice, or re-downloaded: keep both, or it would import forever
          [ -e "$kept" ] && kept="$kept.$(date +%s)"
          mv -- "$zip" "$kept"
          IMPORT_APP="Music purchases" slsk-import "$work/$name" </dev/null
        else
          notify-send -a "Music purchases" "Couldn't unpack $name" "left in $downloads" || true
        fi
        rm -rf -- "$work"
      done
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
    music-scout
    slsk-import
    slsk-search
    music-buy-import
  ];

  systemd.user.paths.music-buy-import = {
    Unit.Description = "Watch Downloads for bought albums";
    Path.PathChanged = "%h/Downloads";
    Install.WantedBy = [ "default.target" ];
  };
  systemd.user.services.music-buy-import = {
    Unit = {
      Description = "Import bought albums from Downloads into beets";
      RequiresMountsFor = [ "/mnt/media" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${music-buy-import}/bin/music-buy-import";
    };
  };

  xdg.dataFile."nicotine/plugins/dots_bridge".source = ../scripts/nicotine-bridge;

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
