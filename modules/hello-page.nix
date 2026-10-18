{
  lib,
  pkgs,
  username,
  ...
}:

let
  dir = "/home/${username}/the-page";
  user = username;
  port = 8137;

  hardening = import ../lib/hardening.nix // {
    ProtectHome = false;
    ProtectSystem = "strict";
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
    # the app lives outside the repo; a fresh install doesn't have it yet
    unitConfig.ConditionPathExists = "${dir}/app.py";

    environment = {
      PORT = toString port;
      HOST = "127.0.0.1";
      DB_PATH = "${dir}/data.db";
      CONFIG_PATH = "${dir}/config.json";
      CONTENT_DIR = "${dir}/content";
    };

    serviceConfig = hardening // {
      ExecStart = "${pkgs.python3}/bin/python3 ${dir}/app.py";
      WorkingDirectory = dir;
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
    unitConfig.ConditionPathExists = "${dir}/tools/backup.sh";
    path = with pkgs; [
      sqlite
      coreutils
      findutils
    ];
    serviceConfig = hardening // {
      Type = "oneshot";
      User = user;
      Group = "users";
      ExecStart = "${pkgs.bash}/bin/bash ${dir}/tools/backup.sh";
    };
  };

  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };
}
