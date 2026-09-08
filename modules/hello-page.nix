{ pkgs, ... }:

let
  dir = "/home/ziad0dev/the-page";
  user = "ziad0dev";
  port = 8137;

  hardening = import ../lib/hardening.nix // {
    # the page owns its own directory: content, config and the sqlite file
    # all live there so a poem is a save rather than a rebuild
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
  systemd.services.hello-page = {
    description = "the page";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

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

  # tailscaled reports "started" well before it can accept commands, so wait for
  # it to actually answer. no ExecStop: the serve config lives in tailscaled
  # state and tearing it down on every restart is what breaks the page.
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

  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };
}
