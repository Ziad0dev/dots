{
  pkgs,
  config,
  username,
  ...
}:
let
  staging = "/mnt/media/slsk";
  # What a release carries besides its music (rip logs, DR reports, cue
  # sheets, checksums, lyrics files, scans, booklets): slsk-import deletes a
  # staging folder once only this is left, music-tidy doesn't count it as
  # music. A find -iregex over the whole path.
  clutter = ".*\\.(txt|log|cue|nfo|m3u8?|pls|sfv|md5|sha1|sha256|crc|ffp|st5|accurip|toc|sfk|lrc|url|ini|db|rtf|html?|md|jpe?g|png|gif|webp|bmp|tiff?|pdf)$";
  # `music-scout playlists` writes here; Tauon reads it (home/flatpak.nix)
  playlists = "/mnt/media/playlists";

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
  # panel calls `music-scout similar --json`); the Spotify export's playlists
  music-scout = pkgs.writeShellApplication {
    name = "music-scout";
    text = ''
      export MUSIC_SCOUT_PLAYLISTS="''${MUSIC_SCOUT_PLAYLISTS:-${playlists}}"
      exec ${python}/bin/python3 ${../scripts/music-scout.py} "$@"
    '';
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

  # Files what beets doesn't know yet, then fills in cover art and lyrics for
  # the whole library. Safe to rerun: each step skips what's already done.
  music-tidy = pkgs.writeShellApplication {
    name = "music-tidy";
    runtimeInputs = [
      config.programs.beets.package
      pkgs.util-linux
      pkgs.gnugrep
      pkgs.findutils
      pkgs.coreutils
    ];
    text = ''
      lock="''${XDG_RUNTIME_DIR:-/tmp}/slsk-import.lock" # one beets run at a time
      lib="${config.xdg.dataHome}/beets/library.db"
      exec 9>"$lock"
      flock 9

      echo "== filing music beets doesn't know yet"
      # `unimported` ignores beets' `ignore` list: leave the compilations alone here
      # only music counts: `unimported` also lists stray clutter and hidden
      # files, which would mark a folder untagged and re-import a library album
      mapfile -t files < <(beet unimported | grep -v '^${config.programs.beets.settings.directory}/playlists/' |
        grep -viE '${clutter}' | grep -vE '/\.[^/]*$|~$')
      # files grouped by folder in one pass
      declare -A byDir=()
      for f in "''${files[@]}"; do
        [ -n "$f" ] && byDir["''${f%/*}"]+="$f"$'\n'
      done
      # `beet import DIR` walks subfolders too, so a folder inside one already
      # listed is covered by it; its files are checked with the parent's
      mapfile -t all < <(printf '%s\n' "''${!byDir[@]}" | grep . | sort)
      dirs=()
      for d in "''${all[@]}"; do
        [ "''${#dirs[@]}" -gt 0 ] && [[ $d == "''${dirs[-1]}"/* ]] && continue
        dirs+=("$d")
      done
      untagged=()
      for d in "''${dirs[@]}"; do
        mine=()
        for k in "''${all[@]}"; do
          if [ "$k" = "$d" ] || [[ $k == "$d"/* ]]; then
            mapfile -t -O "''${#mine[@]}" mine < <(printf '%s' "''${byDir[$k]}")
          fi
        done
        # as slsk-import: split by album (-g) only when the folder holds more
        # than one album tag, or a compilation splits into one album per artist
        group=(-g)
        if ${python}/bin/python3 -I ${../scripts/audio-tagged.py} --one-album "''${mine[@]}"; then
          group=()
        fi
        # MusicBrainz where the match is clear, the files' own tags otherwise,
        # but only when every file has artist and album tags: untagged files
        # filed as-is land in the library as "_/[id]/00.flac"
        fallback=()
        if ${python}/bin/python3 -I ${../scripts/audio-tagged.py} "''${mine[@]}" 2>/dev/null; then
          fallback=(--quiet-fallback=asis)
        else
          untagged+=("$d")
        fi
        beet import -q "''${group[@]}" "''${fallback[@]}" "$d" </dev/null || true
      done
      if [ "''${#untagged[@]}" -gt 0 ]; then
        echo "untagged files, filed only where MusicBrainz matched; tag the rest by hand:"
        printf '  %s\n' "''${untagged[@]}"
      fi

      echo "== cover art: fetch what's missing, put it in the files"
      beet fetchart -q || true
      beet embedart -y || true

      echo "== lyrics"
      beet lyrics || true
      ${python}/bin/python3 ${../scripts/music-lyrics.py} "$lib"
    '';
  };

  music-fill = pkgs.writeShellApplication {
    name = "music-fill";
    runtimeInputs = [
      album-doctor
      music-scout
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

      music-scout playlists --quiet || true

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
  # Moves the folder to the staging dir, files it into the library with beets,
  # then clears it from staging.
  slsk-import = pkgs.writeShellApplication {
    name = "slsk-import";
    runtimeInputs = [
      config.programs.beets.package
      pkgs.systemd
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

      # Sets `left` to the files in $dest other than the clutter a release
      # carries (rip logs, DR reports, cue sheets, checksums, scans). It lists
      # what isn't clutter rather than what is audio, so music in a format
      # nobody listed (wma, m4b, mka, ...) keeps the folder. Fails when find
      # does (drive gone, I/O error), and the caller then keeps everything.
      left=()
      scan() {
        local out
        out="$(mktemp)"
        # hidden files (macOS ._* forks, .DS_Store) and *~ are what beets'
        # `ignore` skips, so they'd never leave either
        if ! find "$dest" -regextype posix-extended -type f \
          -not -iregex '${clutter}' -not -name '.*' -not -name '*~' -print0 >"$out"; then
          rm -f -- "$out"
          return 1
        fi
        mapfile -d "" left <"$out"
        rm -f -- "$out"
      }

      # one beets run at a time; the library is a single sqlite db
      exec 9>"''${XDG_RUNTIME_DIR:-/tmp}/slsk-import.lock"
      flock 9
      # -g: Nicotine+ names a folder by its last path part, so two albums'
      # "Disc 1" can land in one folder; split it by the files' album tags.
      # Only then: -g groups by artist too, which would split a compilation
      # without album-artist tags into one album per track artist
      group=(-g)
      if scan && [ "''${#left[@]}" -gt 0 ] &&
        ${python}/bin/python3 -I ${../scripts/audio-tagged.py} --one-album "''${left[@]}"; then
        group=()
      fi
      beet import -q "''${group[@]}" "$dest" </dev/null || true
      # what MusicBrainz couldn't match clearly (compilations, samplers, odd
      # rips) is filed by its own tags rather than left here, but only when
      # every file left has artist and album tags: untagged files filed as-is
      # land in the library as "_/[id]/00.flac"
      # (-I: the first pass may have recorded this folder as imported)
      if scan && [ "''${#left[@]}" -gt 0 ] &&
        ${python}/bin/python3 -I ${../scripts/audio-tagged.py} "''${left[@]}"; then
        beet import -q "''${group[@]}" -I --quiet-fallback=asis "$dest" </dev/null || true
      fi
      exec 9>&-
      # once the music is in the library the clutter goes too; a folder that
      # still holds anything else is kept
      if scan && [ "''${#left[@]}" -eq 0 ]; then
        rm -rf -- "$dest"
      fi
      find "$dest" -depth -type d -empty -delete 2>/dev/null || true
      # the Spotify playlists (Tauon, Jellyfin) fill in with what just arrived.
      # Queued, not run here: a batch of folders merges into one refresh, and
      # the beets lock isn't held through a full Jellyfin sync
      systemctl --user start --no-block music-playlists.service || true

      if [ -d "$dest" ]; then
        notify-send -a "$app" "Kept in staging: $name" \
          "beets didn't file all of it (untagged, unmatched or an error); see ${config.xdg.stateHome}/slsk-import.log" || true
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
    music-tidy
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

  # On Repeat follows ListenBrainz (Tauon scrobbles there), so it is remade
  # daily even when nothing was imported
  systemd.user.services.music-playlists = {
    Unit = {
      Description = "Refresh the playlists made from the Spotify export";
      RequiresMountsFor = [ "/mnt/media" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${music-scout}/bin/music-scout playlists --quiet";
    };
  };
  systemd.user.timers.music-playlists = {
    Unit.Description = "Refresh the Spotify-export playlists daily";
    Timer = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  xdg.dataFile."nicotine/plugins/dots_bridge".source = ../scripts/nicotine-bridge;
  xdg.configFile."soulseek-rs/config.toml".text = ''
    username = "${username}"
    password_cmd = "cat /run/secrets/soulseek-password"
  '';
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
        "lyrics"
        "embedart"
      ];
      ignore = [
        ".*"
        "*~"
        # the compilations in music/playlists are kept as they are, not split
        # up by artist
        "playlists"
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
      # timed lyrics from LRCLIB (Tauon, rmpc and the bar scroll them), plain
      # ones where it has no timed copy; never replace timed lyrics a file has.
      # No Genius: beets' shared API key is rate-limited (every request 429),
      # so it only added minutes of retries to each import
      lyrics = {
        auto = true;
        synced = true;
        keep_synced = true;
        sources = [ "lrclib" ];
      };
      # the cover goes into the files too (players that don't read cover.jpg,
      # phones, Jellyfin), but never over art a file already carries
      embedart = {
        auto = true;
        ifempty = true;
      };
      unimported.ignore_extensions = [
        "lrc"
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
