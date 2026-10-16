# Kernel & Nix tracker: the dashboard from ~/Ziad0dev/LKML (tracker.py), on
# http://127.0.0.1:8138. Runs straight from the checkout, so a code change
# only needs `systemctl restart lkml-tracker`.
#
# Optional GitHub token for the PR/release cards (higher rate limit):
#   /var/lib/secrets/lkml-tracker.env   GITHUB_TOKEN=...
{
  pkgs,
  username,
  ...
}:

let
  dir = "/home/${username}/Ziad0dev/LKML";
  port = 8138; # 8080 is llama.cpp (llm.nix)

  hardening = import ../lib/hardening.nix // {
    ProtectHome = false;
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
    # the app lives outside the repo; a fresh install doesn't have it yet
    unitConfig.ConditionPathExists = "${dir}/tracker.py";

    # the checkout is read-only to the service
    environment.PYTHONDONTWRITEBYTECODE = "1";

    serviceConfig = hardening // {
      ExecStart = "${pkgs.python3}/bin/python3 ${dir}/tracker.py --host 127.0.0.1 --port ${toString port}";
      WorkingDirectory = dir;
      User = username;
      Group = "users";
      Restart = "always";
      RestartSec = 5;
      EnvironmentFile = "-/var/lib/secrets/lkml-tracker.env";
    };
  };
}
