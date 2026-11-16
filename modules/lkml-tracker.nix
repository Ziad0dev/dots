# Kernel & Nix tracker dashboard on http://127.0.0.1:8138.
#
# Optional GitHub token for the PR/release cards (higher rate limit):
#   /var/lib/secrets/lkml-tracker.env   GITHUB_TOKEN=...
{
  pkgs,
  username,
  ...
}:

let
  source = ../pkgs/lkml-tracker;
  port = 8138; # 8080 is llama.cpp (llm.nix)

  hardening = import ../lib/hardening.nix // {
    ProtectHome = true;
    ProtectSystem = "strict";
    SystemCallFilter = [
      "@system-service"
      "~@privileged"
      "~@resources"
    ];
  };
in
{
  systemd.services.lkml-tracker = {
    description = "Kernel & Nix tracker dashboard";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    environment.PYTHONDONTWRITEBYTECODE = "1";

    serviceConfig = hardening // {
      ExecStart = "${pkgs.python3}/bin/python3 ${source}/tracker.py --host 127.0.0.1 --port ${toString port}";
      WorkingDirectory = "${source}";
      User = username;
      Group = "users";
      Restart = "always";
      RestartSec = 5;
      EnvironmentFile = "-/var/lib/secrets/lkml-tracker.env";
    };
  };
}
