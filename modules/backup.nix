{ username, ... }:

{
  services.restic.backups.home = {
    initialize = true;
    repository = "/mnt/backup/restic";
    passwordFile = "/etc/restic/password";

    paths = [ "/home/${username}" ];

    exclude = [
      "/home/${username}/.cache"
      "/home/${username}/.local/share/Steam"
      "/home/${username}/.local/share/Trash"
      "/home/${username}/.local/share/containers"
      "/home/${username}/.local/state/nix"
      "/home/${username}/Downloads"
      "**/node_modules"
      "**/.direnv"
      "**/target"
      "**/zig-cache"
      "**/zig-out"
      "**/.venv"
      "**/__pycache__"
    ];

    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };

    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 6"
    ];
  };

  systemd.services.restic-backups-home = {
    unitConfig.RequiresMountsFor = [ "/mnt/backup" ];
    unitConfig.ConditionPathIsMountPoint = "/mnt/backup";
    serviceConfig = {
      Nice = 19;
      IOSchedulingClass = "idle";
    };
  };
}
