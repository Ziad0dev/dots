{ pkgs, ... }:
let
  themectl = pkgs.writeShellApplication {
    name = "themectl";
    runtimeInputs = with pkgs; [
      coreutils
      findutils
      gettext
      gnugrep
      gnused
      procps
    ];
    text = builtins.readFile ../scripts/themectl.sh;
  };

  dunstTheme = pkgs.writeShellScript "dots-dunst-theme" ''
    static="$HOME/.config/dunst/dunstrc"
    themed="$HOME/.local/state/dots/theme/dunstrc"
    [ -f "$themed" ] || exit 0
    for _ in $(seq 1 20); do
      if ${pkgs.dunst}/bin/dunstctl reload "$static" "$themed" 2>/dev/null; then
        exit 0
      fi
      sleep 0.5
    done
  '';
in
{
  home.packages = [ themectl ];

  systemd.user.services.dotsDunstTheme = {
    Unit = {
      Description = "Apply the themed dunst config once dunst is up";
      PartOf = [ "hyprland-session.target" ];
      After = [ "hyprland-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${dunstTheme}";
    };
    Install.WantedBy = [ "hyprland-session.target" ];
  };
}
