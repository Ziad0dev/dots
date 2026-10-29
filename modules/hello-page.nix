{
  lib,
  pkgs,
  username,
  ...
}:

let
  source = ../pkgs/hello-page;
  dir = "/home/${username}/the-page";
  user = username;
  port = 8137;

  hardening = import ../lib/hardening.nix // {
    ProtectHome = "read-only";
    ProtectSystem = "strict";
    # SQLite creates journal/WAL sidecars next to data.db. The service uses
    # this directory only for state; executable code and assets are in the store.
    ReadWritePaths = [ dir ];
    SystemCallFilter = [
      "@system-service"
      "~@privileged"
      "~@resources"
    ];
  };
in
{
  services.tailscale = {
    enable = lib.mkDefault true;
    useRoutingFeatures = lib.mkDefault "client";
  };
  # the tailnet only gets the page (443, tailscale serve) and Jellyfin
  # (media.nix); nothing else on this host is reachable from it
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 443 ];

  systemd.services.hello-page = {
    description = "the page";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    unitConfig.ConditionPathExists = "${dir}/data.db";

    environment = {
      PORT = toString port;
      HOST = "127.0.0.1";
      DB_PATH = "${dir}/data.db";
      CONFIG_PATH = "${dir}/config.json";
      CONTENT_DIR = "${dir}/content";
    };

    serviceConfig = hardening // {
      ExecStart = "${pkgs.python3}/bin/python3 ${source}/app.py";
      WorkingDirectory = "${source}";
      User = user;
      Group = "users";
      Restart = "always";
      RestartSec = 5;
      EnvironmentFile = "-/var/lib/secrets/the-page.env";
    };
  };

  systemd.services.hello-page-serve = {
    description = "publish the page to the tailnet";
    wantedBy = [ "multi-user.target" ];
    after = [
      "tailscaled.service"
      "hello-page.service"
    ];
    wants = [ "tailscaled.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "hello-page-serve" ''
        i=0
        while [ $i -lt 60 ]; do
          if ${pkgs.tailscale}/bin/tailscale status --json >/dev/null 2>&1; then
            exec ${pkgs.tailscale}/bin/tailscale serve --bg --https 443 http://127.0.0.1:${toString port}
          fi
          ${pkgs.coreutils}/bin/sleep 2
          i=$((i + 1))
        done
        echo "tailscaled never became ready" >&2
        exit 1
      '';
    };
  };

  # daily sqlite snapshot of the notes into ${dir}/backups (keeps the last 14)
  systemd.timers.hello-page-backup = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };
  systemd.services.hello-page-backup = {
    description = "snapshot the page's notes";
    unitConfig.ConditionPathExists = "${dir}/data.db";
    environment = {
      DB_PATH = "${dir}/data.db";
      BACKUP_DIR = "${dir}/backups";
    };
    path = with pkgs; [
      sqlite
      coreutils
      findutils
    ];
    serviceConfig = hardening // {
      Type = "oneshot";
      User = user;
      Group = "users";
      ExecStart = "${pkgs.bash}/bin/bash ${source}/tools/backup.sh";
    };
  };

}
