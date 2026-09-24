{
  config,
  pkgs,
  ...
}:
let
  link = sub: config.lib.file.mkOutOfStoreSymlink "${config.dots.repoPath}/config/${sub}";
in
{
  home.file.".config/sway".source = link "sway";

  home.packages = with pkgs; [
    autotiling-rs
    i3status-rust
  ];

  systemd.user.services.dotsDunstTheme = {
    Unit = {
      PartOf = [ "sway-session.target" ];
      After = [ "sway-session.target" ];
    };
    Install.WantedBy = [ "sway-session.target" ];
  };
}
