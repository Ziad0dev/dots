{ pkgs, username, ... }:

{
  services.restic.backups.home = {
    initialize = true;
    repository = "/mnt/backup/restic";
    passwordFile = "/etc/restic/password";

    paths = [
      "/home/${username}"
      # the media apps' own state: indexers, libraries, users, watch history
      "/var/lib/sonarr"
      "/var/lib/radarr"
      "/var/lib/private/prowlarr" # DynamicUser
      "/var/lib/qBittorrent"
      "/var/lib/jellyfin"
      "/var/lib/audiobookshelf"
      "/var/lib/calibre-web"
      # Secure Boot keys: losing them means clearing and re-enrolling in firmware
      "/var/lib/sbctl"
    ];

    exclude = [
      "/home/${username}/.cache"
      "/home/${username}/.local/share/Steam"
      "/home/${username}/Games"
      "/home/${username}/Videos/Replays"
      "/home/${username}/.local/share/Trash"
      "/home/${username}/.local/share/containers"
      "/home/${username}/.local/state/nix"
      "/home/${username}/Downloads"
      "/home/${username}/.local/share/flatpak"
      "/home/${username}/.local/share/umu"
      "/home/${username}/.local/share/baloo"
      "/home/${username}/.config/heroic"
      # regenerable: artwork, scraped metadata, logs
      "/var/lib/jellyfin/metadata"
      "/var/lib/jellyfin/log"
      "/var/lib/**/MediaCover"
      "/var/lib/**/logs"
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
