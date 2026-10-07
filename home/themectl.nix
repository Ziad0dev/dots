{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dots;
  state = "${config.xdg.stateHome}/dots/theme";

  themectl = pkgs.writeShellApplication {
    name = "themectl";
    runtimeInputs =
      with pkgs;
      [
        coreutils
        dconf
        findutils
        gettext
        gnugrep
        gnused
        jq
        matugen
        procps
      ]
      # only reached through `systemctl --user` in the app reloads
      ++ lib.optional stdenv.isLinux systemd;
    # live: the checkout's themes; pure: the ones in the store
    text = ''
      DOTS_DIR="''${DOTS_DIR:-${cfg.src}}"
    ''
    + builtins.readFile ../scripts/themectl.sh;
  };
in
{
  home.packages = [ themectl ];

  # A fresh home gets dots.theme on its first activation, so nothing starts
  # unstyled. In pure mode the rendered files and links point into this
  # generation's store path, so every switch re-renders the current theme
  # (quietly: no app reloads, no wallpaper change).
  home.activation.dotsTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e ${lib.escapeShellArg "${state}/current"} ]; then
      run ${themectl}/bin/themectl set ${lib.escapeShellArg cfg.theme} || true
    ${lib.optionalString (!cfg.liveConfig) ''
      else
        run ${themectl}/bin/themectl render || true
    ''}
    fi
  '';
}
