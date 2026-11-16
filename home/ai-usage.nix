{
  config,
  lib,
  pkgs,
  ...
}:
let
  scripts = "${config.xdg.configHome}/quickshell/rise/scripts";

  refresh = pkgs.writeShellScript "dots-ai-usage" ''
    f="${scripts}/claude-usage"
    # stderr (HTTP/fetch errors) goes to journalctl --user -u dots-ai-usage
    [ -f "$f" ] && ${pkgs.python3}/bin/python3 "$f" >/dev/null || true
  '';
in
{
  systemd.user.services.dots-ai-usage = {
    Unit.Description = "Refresh the Claude Code quota cache read by the Quickshell bar";
    Service = {
      Type = "oneshot";
      ExecStart = "${refresh}";
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

  systemd.user.timers.dots-ai-usage = {
    Unit.Description = "Refresh the Claude Code quota cache every 10 minutes";
    Timer = {
      OnStartupSec = "2min";
      OnUnitActiveSec = "10min";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
