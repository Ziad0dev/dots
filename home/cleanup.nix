{ lib, pkgs, ... }:
lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
  systemd.user.tmpfiles.rules = [
    "e %C/thumbnails - - - 60d"
    "e %C/quickshell-img-thumbs - - - 60d"
    "e %C/nvidia - - - 30d"
    "e %C/mpv - - - 30d"
    "e %h/.local/share/Trash - - - 30d"
  ];

  systemd.user.services.flatpak-prune = {
    Unit.Description = "Remove unused user flatpak runtimes";
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.flatpak}/bin/flatpak uninstall --user --unused -y --noninteractive";
    };
  };

  systemd.user.timers.flatpak-prune = {
    Unit.Description = "Weekly flatpak prune";
    Timer = {
      OnCalendar = "weekly";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
