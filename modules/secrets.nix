{ pkgs, ... }:

{
  environment.systemPackages = [
    pkgs.secretspec
    pkgs.pass
    pkgs.gnupg
    pkgs.pinentry-gnome3
    pkgs.bitwarden-cli
  ];

  programs.gnupg.agent = {
    enable = true;
    pinentryPackage = pkgs.pinentry-gnome3;
  };
}
