{ pkgs, ... }:

let
  sonarrData = "/var/lib/sonarr/.config/NzbDrone";
  radarrData = "/var/lib/radarr/.config/Radarr";
  prowlarrData = "/var/lib/prowlarr";

  sonarrUrl = "http://127.0.0.1:8989";
  radarrUrl = "http://127.0.0.1:7878";
  prowlarrUrl = "http://192.168.15.1:9696";

  batchSize = 25;

  sqlite = "${pkgs.sqlite}/bin/sqlite3";
  curl = "${pkgs.curl}/bin/curl";
  jq = "${pkgs.jq}/bin/jq";
  grep = "${pkgs.gnugrep}/bin/grep";

  resetIndexerStatus = pkgs.writeShellScript "arr-reset-indexer-status" ''
    for db in \
      ${prowlarrData}/prowlarr.db \
      ${prowlarrData}/.config/Prowlarr/prowlarr.db \
      ${sonarrData}/sonarr.db \
      ${radarrData}/radarr.db
    do
      [ -f "$db" ] || continue
      ${sqlite} "$db" "delete from IndexerStatus;" || true
    done
  '';

  backlogSearch = pkgs.writeShellScript "arr-backlog-search" ''
    set -u

    search() {
      app=$1
      url=$2
      cfg=$3
      cmd=$4
      field=$5

      [ -f "$cfg" ] || return 0
      key=$(${grep} -oP '(?<=<ApiKey>)[^<]+' "$cfg") || return 0

      ids=$(${curl} -sf --max-time 60 -H "X-Api-Key: $key" \
        "$url/api/v3/wanted/missing?pageSize=${toString batchSize}&sortDirection=descending&monitored=true" \
        | ${jq} -c '[.records[].id]') || return 0

      [ "$ids" = "[]" ] && return 0

      ${curl} -sf --max-time 60 -X POST \
        -H "X-Api-Key: $key" -H "Content-Type: application/json" \
        -d "{\"name\":\"$cmd\",\"$field\":$ids}" \
        "$url/api/v3/command" >/dev/null || return 0

      echo "$app: dispatched search for $(echo "$ids" | ${jq} length) items"
    }

    search sonarr ${sonarrUrl} ${sonarrData}/config.xml EpisodeSearch episodeIds
    search radarr ${radarrUrl} ${radarrData}/config.xml MoviesSearch movieIds
  '';

  arrStatus = pkgs.writeShellScriptBin "arr-status" ''
    set -u

    [ "$(${pkgs.coreutils}/bin/id -u)" -eq 0 ] || exec /run/wrappers/bin/sudo "$0" "$@"

    report() {
      name=$1
      url=$2
      cfg=$3
      api=$4

      if [ ! -r "$cfg" ]; then
        echo "$name: cannot read config (try sudo)"
        return
      fi

      key=$(${grep} -oP '(?<=<ApiKey>)[^<]+' "$cfg")

      echo "== $name =="
      ${curl} -sf --max-time 10 -H "X-Api-Key: $key" "$url/$api/indexer" \
        | ${jq} -r '.[] | "  \(.name)  enabled=\(.enable // "-")  rss=\(.enableRss // "-") auto=\(.enableAutomaticSearch // "-") interactive=\(.enableInteractiveSearch // "-")"' \
        || echo "  unreachable"
      ${curl} -sf --max-time 10 -H "X-Api-Key: $key" "$url/$api/indexerstatus" \
        | ${jq} -r 'if length == 0 then "  no backoff" else .[] | "  BACKOFF id=\(.indexerId) till=\(.disabledTill)" end' \
        || true
      echo
    }

    report prowlarr ${prowlarrUrl} ${prowlarrData}/config.xml api/v1
    report sonarr ${sonarrUrl} ${sonarrData}/config.xml api/v3
    report radarr ${radarrUrl} ${radarrData}/config.xml api/v3
  '';
in
{
  systemd.services.arr-reset-indexer-status = {
    description = "Clear stale indexer failure backoff before the *arrs start";
    wantedBy = [ "multi-user.target" ];
    after = [ "wg.service" ];
    before = [
      "prowlarr.service"
      "sonarr.service"
      "radarr.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${resetIndexerStatus}";
    };
  };

  systemd.services.arr-backlog-search = {
    description = "Search a batch of wanted/missing items";
    after = [
      "sonarr.service"
      "radarr.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${backlogSearch}";
    };
  };

  systemd.timers.arr-backlog-search = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      RandomizedDelaySec = "2h";
      Persistent = true;
    };
  };

  systemd.services.sonarr.after = [ "arr-reset-indexer-status.service" ];
  systemd.services.radarr.after = [ "arr-reset-indexer-status.service" ];

  environment.systemPackages = [ arrStatus ];
}
