{ pkgs, ... }:

let
  sonarrData = "/var/lib/sonarr/.config/NzbDrone";
  radarrData = "/var/lib/radarr/.config/Radarr";
  prowlarrData = "/var/lib/prowlarr";

  prowlarrDb = "${prowlarrData}/prowlarr.db";
  sonarrDb = "${sonarrData}/sonarr.db";
  radarrDb = "${radarrData}/radarr.db";
  arrDbs = "${prowlarrDb} ${sonarrDb} ${radarrDb}";

  sonarrUrl = "http://127.0.0.1:8989";
  radarrUrl = "http://127.0.0.1:7878";
  prowlarrUrl = "http://192.168.15.1:9696";

  batchSize = 25;

  sqlite = "${pkgs.sqlite}/bin/sqlite3 -cmd '.timeout 5000'";
  curl = "${pkgs.curl}/bin/curl";
  jq = "${pkgs.jq}/bin/jq";
  grep = "${pkgs.gnugrep}/bin/grep";
  ip = "${pkgs.iproute2}/bin/ip";

  blockedSql = "select count(*) from IndexerStatus where datetime(DisabledTill) > datetime('now');";

  resetIndexerStatus = pkgs.writeShellScript "arr-reset-indexer-status" ''
    for db in ${arrDbs}; do
      [ -f "$db" ] || continue
      ${sqlite} "$db" "delete from IndexerStatus;" || true
    done
  '';

  recoverIndexers = pkgs.writeShellScript "arr-recover-indexers" ''
    set -u

    blocked=0
    for db in ${arrDbs}; do
      [ -f "$db" ] || continue
      n=$(${sqlite} "$db" "${blockedSql}") || continue
      blocked=$((blocked + n))
    done

    if [ "$blocked" -gt 0 ]; then
      if ${ip} netns exec wg ${curl} -s -o /dev/null --max-time 15 https://indexers.prowlarr.com/; then
        ${resetIndexerStatus}
        echo "cleared backoff on $blocked indexers"
      else
        echo "$blocked indexers in backoff, wg namespace still can't reach out; leaving them"
      fi
    fi

    health() {
      key=$(${grep} -oP '(?<=<ApiKey>)[^<]+' "$2") || return 0
      ${curl} -sf --max-time 10 -X POST \
        -H @- <<<"X-Api-Key: $key" -H "Content-Type: application/json" \
        -d '{"name":"CheckHealth"}' "$1/command" >/dev/null || true
    }

    health ${prowlarrUrl}/api/v1 ${prowlarrData}/config.xml
    health ${sonarrUrl}/api/v3 ${sonarrData}/config.xml
    health ${radarrUrl}/api/v3 ${radarrData}/config.xml
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

      ids=$(${curl} -sf --max-time 60 -H @- <<<"X-Api-Key: $key" \
        "$url/api/v3/wanted/missing?pageSize=${toString batchSize}&sortDirection=descending&monitored=true" \
        | ${jq} -c '[.records[].id]') || return 0

      [ "$ids" = "[]" ] && return 0

      ${curl} -sf --max-time 60 -X POST \
        -H @- <<<"X-Api-Key: $key" -H "Content-Type: application/json" \
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
      db=$5

      if [ ! -r "$cfg" ]; then
        echo "$name: cannot read config (try sudo)"
        return
      fi

      key=$(${grep} -oP '(?<=<ApiKey>)[^<]+' "$cfg")

      echo "== $name =="
      ${curl} -sf --max-time 10 -H @- <<<"X-Api-Key: $key" "$url/$api/indexer" \
        | ${jq} -r '.[] | "  \(.id) \(.name)  enabled=\(.enable // "-")  rss=\(.enableRss // "-") auto=\(.enableAutomaticSearch // "-") interactive=\(.enableInteractiveSearch // "-")"' \
        || echo "  unreachable"
      ${sqlite} -readonly "$db" \
        "select '  BACKOFF id=' || ProviderId || ' till=' || DisabledTill || ' level=' || EscalationLevel from IndexerStatus where datetime(DisabledTill) > datetime('now');" \
        | ${grep} . || echo "  no backoff"
      echo
    }

    report prowlarr ${prowlarrUrl} ${prowlarrData}/config.xml api/v1 ${prowlarrDb}
    report sonarr ${sonarrUrl} ${sonarrData}/config.xml api/v3 ${sonarrDb}
    report radarr ${radarrUrl} ${radarrData}/config.xml api/v3 ${radarrDb}
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

  systemd.services.arr-recover-indexers = {
    description = "Clear *arr indexer backoff once the VPN path works again";
    after = [ "wg-resolv-options.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${recoverIndexers}";
    };
  };

  systemd.timers.arr-recover-indexers = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "10min";
      OnUnitActiveSec = "15min";
    };
  };

  systemd.services.sonarr.after = [ "arr-reset-indexer-status.service" ];
  systemd.services.radarr.after = [ "arr-reset-indexer-status.service" ];

  environment.systemPackages = [ arrStatus ];
}
