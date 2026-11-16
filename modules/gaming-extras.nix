{
  config,
  lib,
  pkgs,
  ...
}:

{
  environment.systemPackages = with pkgs; [
    protontricks
    winetricks
    lutris

  ];

}
