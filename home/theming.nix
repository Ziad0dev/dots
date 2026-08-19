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
in
{
  home.packages = [ themectl ];
}
