{
  config,
  lib,
  pkgs,
  ...
}:
let
  scripts = "${config.home.homeDirectory}/dots/config/quickshell/rise/scripts";

  refresh = pkgs.writeShellScript "dots-ai-usage" ''
    for s in claude-usage codex-usage opencode-usage; do
      f="${scripts}/$s"
      [ -f "$f" ] || continue
      ${pkgs.python3}/bin/python3 "$f" >/dev/null 2>&1 || true
    done
  '';
in
{
  systemd.user.services.dots-ai-usage = {
    Unit.Description = "Refresh AI quota caches read by the Quickshell bar";
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
    Unit.Description = "Refresh AI quota caches every 10 minutes";
    Timer = {
      OnStartupSec = "2min";
      OnUnitActiveSec = "10min";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
