{
  config,
  lib,
  pkgs,
  ...
}:
let
  script = "${config.dots.repoPath}/config/quickshell/rise/scripts/github-inbox";
in
{
  home.packages = with pkgs; [
    gh
    jq
  ];

  systemd.user.services.dots-github-inbox = {
    Unit.Description = "Refresh the GitHub inbox cache read by the Quickshell bar";
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c '[ -x ${script} ] && ${script} >/dev/null 2>&1 || true'";
      Environment = [
        "PATH=${
          lib.concatStringsSep ":" [
            "/etc/profiles/per-user/${config.home.username}/bin"
            "${config.home.homeDirectory}/.nix-profile/bin"
            "${config.home.homeDirectory}/.local/bin"
            "/run/wrappers/bin"
            "/run/current-system/sw/bin"
          ]
        }"
      ];
    };
  };

  systemd.user.timers.dots-github-inbox = {
    Unit.Description = "Refresh the GitHub inbox cache every 5 minutes";
    Timer = {
      OnStartupSec = "1min";
      OnUnitActiveSec = "5min";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
