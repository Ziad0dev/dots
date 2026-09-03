{ pkgs, username, ... }:

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
      "/home/${username}/.local/share/flatpak"
      "/home/${username}/.local/share/umu"
      "/home/${username}/.local/share/baloo"
      "/home/${username}/.config/heroic"
      "**/Cache"
      "**/CachedData"
      "**/Code Cache"
      "**/GPUCache"
      "**/ShaderCache"
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

    checkOpts = [ "--read-data-subset=5%" ];
  };

  systemd.services.restic-backups-home = {
    unitConfig.RequiresMountsFor = [ "/mnt/backup" ];
    unitConfig.ConditionPathIsMountPoint = "/mnt/backup";
    serviceConfig = {
      Nice = 19;
      IOSchedulingClass = "idle";
      ExecStartPre = [
        "${pkgs.coreutils}/bin/test -s /etc/restic/password"
      ];
    };
  };

  systemd.tmpfiles.rules = [ "d /etc/restic 0700 root root -" ];

  environment.systemPackages = [ pkgs.restic ];
}
