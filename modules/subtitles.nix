{
  config,
  lib,
  pkgs,
  ...
}:

let
  mediaRoot = "/mnt/media";
  bazarrData = "/var/lib/bazarr";
  bazarrUrl = "http://127.0.0.1:6767";
  sonarrConfig = "/var/lib/sonarr/.config/NzbDrone/config.xml";
  radarrConfig = "/var/lib/radarr/.config/Radarr/config.xml";

  # Sources with a free account or API key turn on once their keys are in the
  # sops file. sops keeps key names in clear text; declaring a secret whose
  # key is missing would make sops-nix fail every secret, so check first.
  hasSecret =
    k:
    config.dots.secrets.enable
    && lib.hasInfix "\n${k}:" ("\n" + builtins.readFile config.dots.secrets.file);
  osSecrets = [
    "opensubtitles-username"
    "opensubtitles-password"
  ];
  hasOpenSubtitles = lib.all hasSecret osSecrets;
  # subdl.com and subsource.net: free API keys, each with its own daily limit
  hasSubdl = hasSecret "subdl-api-key";
  hasSubsource = hasSecret "subsource-api-key";
  # the web UI login: the MD5 of the password, which is what Bazarr stores
  # and compares against (an MD5 is quick to crack, so it stays in sops)
  hasUiLogin = hasSecret "bazarr-ui-password";
  secretNames =
    lib.optionals hasOpenSubtitles osSecrets
    ++ lib.optional hasSubdl "subdl-api-key"
    ++ lib.optional hasSubsource "subsource-api-key"
    ++ lib.optional hasUiLogin "bazarr-ui-password";

  # Sources that need no account: gestdown covers TV, yifysubtitles films,
  # bsplayer, subtitlecat and subf2m both. (tvsubtitles is left out: its
  # search page has returned 404 since the site changed.)
  providers = [
    "gestdown"
    "yifysubtitles"
    "bsplayer"
    "subtitlecat"
    "subf2m"
  ]
  ++ lib.optional hasOpenSubtitles "opensubtitlescom"
  ++ lib.optional hasSubdl "subdl"
  ++ lib.optional hasSubsource "subsource";

  # Profile 1: English, not hearing-impaired-only, not forced-only.
  englishProfile = builtins.toJSON [
    {
      profileId = 1;
      name = "English";
      cutoff = null;
      items = [
        {
          id = 1;
          language = "en";
          hi = "False";
          forced = "False";
          audio_exclude = "False";
          audio_only_include = "False";
        }
      ];
      mustContain = [ ];
      mustNotContain = [ ];
      originalFormat = null;
      tag = null;
    }
  ];

  # The language profile lives in Bazarr's database and the *arr API keys in
  # their own config.xml, so neither can be a Nix setting. This posts them to
  # Bazarr's API. Keys go through files and stdin, never the command line.
  setup = pkgs.writeShellApplication {
    name = "bazarr-setup";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      gnugrep
      yq-go
    ];
    text = ''
      cfg=${bazarrData}/config/config.yaml
      for _ in $(seq 60); do
        [ -s "$cfg" ] && break
        sleep 2
      done
      key=$(yq -r '.auth.apikey' "$cfg")
      [ -n "$key" ] && [ "$key" != null ] || { echo "no Bazarr API key in $cfg" >&2; exit 1; }

      api() {
        curl -sf --max-time 30 --retry 30 --retry-connrefused --retry-delay 2 \
          -H @- "$@" <<<"X-API-KEY: $key"
      }

      # wait until Bazarr answers
      api -o /dev/null "${bazarrUrl}/api/system/status"

      # `bazarr-setup search`: start the missing-subtitle searches now
      # instead of at Bazarr's next 6-hourly run
      if [ "''${1:-}" = search ]; then
        # clear provider pauses first: Bazarr pauses a provider for 12 h after
        # a failed login and keeps that across restarts, so a corrected login
        # would otherwise wait it out. Runs only on start-up or by hand.
        api -o /dev/null -X POST --data-urlencode action=reset "${bazarrUrl}/api/providers"
        for task in wanted_search_missing_subtitles_series wanted_search_missing_subtitles_movies; do
          api -o /dev/null -X POST "${bazarrUrl}/api/system/tasks?taskid=$task"
        done
        echo "Bazarr: missing-subtitle searches started"
        exit 0
      fi

      api -o /dev/null -X POST \
        --data-urlencode "languages-enabled=en" \
        --data-urlencode ${lib.escapeShellArg "languages-profiles=${englishProfile}"} \
        "${bazarrUrl}/api/system/settings"

      dir=$(mktemp -d)
      trap 'rm -rf "$dir"' EXIT
      for app in sonarr radarr; do
        conf=${sonarrConfig}
        [ "$app" = radarr ] && conf=${radarrConfig}
        if ! [ -r "$conf" ] || ! appkey=$(grep -oP '(?<=<ApiKey>)[^<]+' "$conf"); then
          echo "$app: no API key yet, skipping" >&2
          continue
        fi
        printf '%s' "$appkey" >"$dir/$app"
        # Bazarr saves the key, then reconnects to the *arr before replying,
        # which can take long. Post once (a retry would resend it) and check
        # the saved value instead of waiting on the reply.
        curl -s -o /dev/null --max-time 15 -H @- -X POST \
          --data-urlencode "settings-$app-apikey@$dir/$app" \
          "${bazarrUrl}/api/system/settings" <<<"X-API-KEY: $key" || true
        saved=$(yq -r ".$app.apikey" "$cfg")
        if [ "$saved" = "$appkey" ]; then
          echo "$app: API key saved"
        else
          echo "$app: API key did not save" >&2
          exit 1
        fi
      done

      # pick up the libraries now instead of at the next daily sync
      for task in update_series update_movies; do
        api -o /dev/null -X POST "${bazarrUrl}/api/system/tasks?taskid=$task" || true
      done
      echo "Bazarr: English profile set, sync started"
    '';
  };
  setupSandbox = import ../lib/hardening.nix // {
    Type = "oneshot";
    TimeoutStartSec = "5min";
    ProtectSystem = "strict";
    CapabilityBoundingSet = [ "CAP_DAC_READ_SEARCH" ];
    IPAddressAllow = "localhost";
    IPAddressDeny = "any";
  };
  # Bazarr 1.6.2's subsyncer writes to a fixed `<name>.synced.srt`, then
  # deletes the subtitle and renames the result over it. Two searches that
  # reach the same episode at once (the scheduled one and one started from
  # the web UI) race on those names: one deletes the other's finished
  # subtitle, which is lost until the next search. A per-run temp name and an
  # atomic os.replace remove the race; a failed run cleans up its temp file.
  # --replace-fail stops the build if upstream changes these lines.
  bazarr = pkgs.bazarr.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace bazarr/subtitles/tools/subsyncer.py \
        --replace-fail \
          "self.srtout = f'{os.path.splitext(self.srtin)[0]}.synced{extension}'" \
          "self.srtout = f'{os.path.splitext(self.srtin)[0]}.synced.{os.getpid()}-{id(self)}{extension}'" \
        --replace-fail "os.remove(self.srtin)" "pass" \
        --replace-fail "os.rename(self.srtout, self.srtin)" "os.replace(self.srtout, self.srtin)" \
        --replace-fail \
          "f'BAZARR an exception occurs during the synchronization process for this subtitle file: {self.srtin}')" \
          "f'BAZARR an exception occurs during the synchronization process for this subtitle file: {self.srtin}')
                  if os.path.isfile(self.srtout):
                      os.remove(self.srtout)"
    '';
  });
in
{
  services.bazarr = {
    enable = true;
    package = bazarr;
    group = "media";
    openFirewall = false;
    # Emitted as DYNACONF_* at start, so they win over edits in the web UI.
    settings = {
      general = {
        ip = "127.0.0.1";
        use_sonarr = true;
        use_radarr = true;
        enabled_providers = providers;
        serie_default_enabled = true;
        serie_default_profile = 1;
        movie_default_enabled = true;
        movie_default_profile = 1;
        # an embedded English track counts as having English subtitles
        use_embedded_subs = true;
        # Episode scores are out of 360: series 180, year 90, season 30,
        # episode 30, then a few points for release details. 66% is a match
        # on series, season and episode alone (240), which is all a file
        # named only `Show.S01E01.mkv` can offer; the default 90% needs
        # the year as well, which many sources don't list. Such subtitles
        # are re-timed to the audio below, and Bazarr swaps in a
        # better-scoring one if it finds one within 7 days.
        minimum_score = 66;
        # Bazarr runs this command after every download; never let it be set
        use_postprocessing = false;
        postprocessing_cmd = "";
      };
      # With no auth Bazarr's page hands its API key to anyone on loopback
      # (a DNS-rebinding web page included), and the key can set a
      # post-processing command. Without a `bazarr-ui-password` in sops, the
      # stored password is empty and form login can never succeed (it
      # compares an MD5 hash against ""), so the web UI stays locked;
      # bazarr-setup uses the API key and isn't affected.
      auth = {
        type = "form";
        username = if hasUiLogin then "admin" else "locked";
        password = if hasUiLogin then { _secret = config.sops.secrets.bazarr-ui-password.path; } else "";
      };
      subtitlecat.include_machine_translated = false;
      # Re-time subtitles that didn't match the release (below 90%) to the
      # audio with ffsubsync, which Bazarr bundles; ffmpeg is on its PATH.
      subsync = {
        use_subsync = true;
        use_subsync_threshold = true;
        subsync_threshold = 90;
        use_subsync_movie_threshold = true;
        subsync_movie_threshold = 90;
      };
      # subf2m refuses to start without one, and the site serves browsers
      subf2m.user_agent = "Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 Firefox/140.0";
    }
    # API keys and logins are read at start through LoadCredential, never in
    # the store
    // lib.optionalAttrs hasSubdl {
      subdl = {
        api_key._secret = config.sops.secrets.subdl-api-key.path;
        include_ai_translated = false;
      };
    }
    // lib.optionalAttrs hasSubsource {
      subsource.apikey._secret = config.sops.secrets.subsource-api-key.path;
    }
    // lib.optionalAttrs hasOpenSubtitles {
      opensubtitlescom = {
        username._secret = config.sops.secrets.opensubtitles-username.path;
        password._secret = config.sops.secrets.opensubtitles-password.path;
        # hash matching: exact for files with no release info in the name
        use_hash = true;
        include_ai_translated = false;
        include_machine_translated = false;
      };
    };
  };

  # a changed login or key restarts Bazarr (it reads them only at start)
  sops.secrets = lib.genAttrs secretNames (_: {
    restartUnits = [ "bazarr.service" ];
  });

  # Subtitles are written next to the videos on the media drive.
  systemd.services.bazarr.unitConfig.RequiresMountsFor = [ mediaRoot ];
  # Syncing decodes each video's audio; keep that from slowing the desktop.
  systemd.services.bazarr.serviceConfig = {
    Nice = 19;
    IOSchedulingClass = "idle";
  };

  # Root only to read three services' private state; no writes, loopback only.
  systemd.services.bazarr-setup = {
    description = "Connect Bazarr to Sonarr/Radarr and set its English profile";
    wantedBy = [ "multi-user.target" ];
    wants = [ "bazarr.service" ];
    after = [
      "bazarr.service"
      "sonarr.service"
      "radarr.service"
    ];
    serviceConfig = setupSandbox // {
      ExecStart = "${setup}/bin/bazarr-setup";
    };
  };

  # The first search: ten minutes after setup, when the library sync is done.
  systemd.services.bazarr-search = {
    description = "Start Bazarr's missing-subtitle searches";
    after = [ "bazarr-setup.service" ];
    serviceConfig = setupSandbox // {
      ExecStart = "${setup}/bin/bazarr-setup search";
    };
  };
  systemd.timers.bazarr-search = {
    wantedBy = [ "timers.target" ];
    # restarted with Bazarr (e.g. a new provider), so a search follows
    partOf = [ "bazarr.service" ];
    timerConfig.OnActiveSec = "10min";
  };
}
