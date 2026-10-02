{
  config,
  pkgs,
  ...
}:
let
  link = sub: config.lib.file.mkOutOfStoreSymlink "${config.dots.repoPath}/config/${sub}";

  # Under Hyprland quickshell is the notification daemon; dunst only runs in
  # sway. It is started by path and kept out of home.packages so its D-Bus
  # activation file can't spawn it under Hyprland and take the bus name.
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
  home.file.".config/sway".source = link "sway";
  home.file.".config/dunst".source = link "dunst";

  home.packages = with pkgs; [
    autotiling-rs
    i3status-rust
  ];

  systemd.user.services.dunst = {
    Unit = {
      Description = "dunst (sway session only)";
      PartOf = [ "sway-session.target" ];
      After = [ "sway-session.target" ];
    };
    Service = {
      Type = "dbus";
      BusName = "org.freedesktop.Notifications";
      ExecStart = "${pkgs.dunst}/bin/dunst";
    };
    Install.WantedBy = [ "sway-session.target" ];
  };

  systemd.user.services.dotsDunstTheme = {
    Unit = {
      Description = "Apply the themed dunst config once dunst is up";
      PartOf = [ "sway-session.target" ];
      After = [ "dunst.service" ];
      Requires = [ "dunst.service" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${dunstTheme}";
    };
    Install.WantedBy = [ "sway-session.target" ];
  };
}
