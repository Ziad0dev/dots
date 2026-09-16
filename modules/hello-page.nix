{ pkgs, username, ... }:

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
      Restart = "on-failure";
      RestartSec = 5;
      ExecStart = pkgs.writeShellScript "hello-page-serve" ''
        i=0
        while [ $i -lt 60 ]; do
          state=$(${pkgs.tailscale}/bin/tailscale status --json 2>/dev/null | ${pkgs.jq}/bin/jq -r '.BackendState // empty')
          if [ "$state" = "Running" ]; then
            exec ${pkgs.tailscale}/bin/tailscale serve --bg --https 443 http://127.0.0.1:${toString port}
          fi
          ${pkgs.coreutils}/bin/sleep 2
          i=$((i + 1))
        done
        echo "tailscaled never became ready (last state: ''${state:-none})" >&2
        exit 1
      '';
    };
  };
}
