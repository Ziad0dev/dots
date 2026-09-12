{ pkgs, ... }:

{
  environment.systemPackages = [
    pkgs.secretspec
    pkgs.pass
    pkgs.gnupg
    pkgs.pinentry-qt
    pkgs.pinentry-curses
    pkgs.bitwarden-cli
  ];

  programs.gnupg.agent = {
    enable = true;
    pinentryPackage = pkgs.pinentry-qt;
    settings = {
      default-cache-ttl = 28800;
      max-cache-ttl = 86400;
      no-allow-external-cache = "";
    };
  };
}
