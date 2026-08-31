{ pkgs, ... }:

{
  environment.systemPackages = [
    pkgs.secretspec
    pkgs.pass
    pkgs.gnupg
    pkgs.pinentry-curses
    pkgs.bitwarden-cli
  ];

  programs.gnupg.agent = {
    enable = true;
    pinentryPackage = pkgs.pinentry-curses;
  };
}
