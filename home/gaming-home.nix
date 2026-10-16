{
  lib,
  pkgs,
  config,
  ...
}:

let
  # Millennium (modules/gaming.nix) has one active theme, so the theme is
  # Simply Dark (minimal, dark) with QOL Toggles' options added to it: both
  # sets show up in Millennium → Themes → options. Its colours follow the
  # dots theme.
  simplyDark = pkgs.fetchFromGitHub {
    owner = "ejalxndr";
    repo = "simply-dark";
    rev = "5163dcbca3cbde75e6aad29af0c6025612ba8607";
    hash = "sha256-5xmz1wF2blEcuPDhNcmovB2IVhXg6q4yndcbLKWXQT0=";
  };
  qolToggles = pkgs.fetchFromGitHub {
    owner = "madmaxgrey";
    repo = "QOL-Toggles-Steam";
    rev = "d6001ed168451133f9992c1284dc6a2030984edb";
    hash = "sha256-Kh6UqjBVPqLBEzvysjV6NDJpdqIxE4LM3ck1nIK0dfw=";
  };
  theme = {
    name = "simply-dark";
    src = pkgs.runCommand "millennium-simply-dark-qol" { nativeBuildInputs = [ pkgs.jq ]; } ''
      cp -r ${simplyDark} $out
      chmod -R u+w $out
      cp -r ${qolToggles}/config $out/qol
      # colours from the dots theme (steam-colors.css, rendered by themectl);
      # without RootColors Millennium doesn't keep its own copy of them
      for f in colors.css webkit/reservedWebkitColors.css; do
        ln -sf ${config.xdg.stateHome}/dots/theme/steam-colors.css $out/$f
      done
      jq --slurpfile q ${qolToggles}/skin.json '
        .name = "Simply Dark + QOL Toggles"
        | del(.RootColors)
        | .Conditions += ($q[0].Conditions | map_values(.values |= map_values(
            if .TargetCss then .TargetCss.src |= sub("^config/"; "qol/") else . end)))
      ' ${simplyDark}/skin.json > $out/skin.json
    '';
  };

  # Millennium plugins, as released (frontend already built); the key is the
  # plugin.json name, which is what Millennium enables them by
  plugins = {
    # How Long To Beat times on library and store pages
    hltb-for-millennium = pkgs.fetchzip {
      url = "https://github.com/jcdoll/hltb-millennium-plugin/releases/download/v2.2.0/hltb-for-millennium-2.2.0.zip";
      hash = "sha256-LH9JzLHSIOgJcasPEsFwQkninysyyzty37xDnFv0m/g=";
    };
    # live player count on game pages
    playercount-badge = pkgs.fetchzip {
      url = "https://github.com/swindlesmccoop/playercount-badge/releases/download/v1.0/playercount-badge.zip";
      hash = "sha256-DIhDLoVue358KMsDG7EsjUyARxTdhjk/mQeJQgSTVlM=";
    };
    # ProtonDB ratings on store pages
    protondb = pkgs.fetchzip {
      url = "https://github.com/unicxrn/protondb-millennium/releases/download/v1.0.0/protondb-v1.0.0.zip";
      hash = "sha256-1rmpPsk1CPsLJ8sb/15q/Ay4fzTUF1c1T3iZ3fSJNms=";
    };
  };
in
{
  programs.mangohud = {
    enable = true;
    settings = {
      position = "top-left";
      toggle_hud = "Shift_R+F12";
      no_display = true;
      fps = true;
      frametime = true;
      frame_timing = true;
      gpu_stats = true;
      gpu_temp = true;
      cpu_stats = true;
      cpu_temp = true;
      ram = true;
      vram = true;
    };
  };

  # Millennium writes into themes and plugins (settings, updates, caches), so
  # they are copied rather than linked. A copy marked with its store path is
  # ours and is refreshed when the pin changes; one without the marker
  # (updated or replaced from Millennium) is left alone.
  home.activation.millennium = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [[ ! -v DRY_RUN ]]; then
      jq=${lib.getExe pkgs.jq}
      cfg="${config.xdg.configHome}/millennium/config.json"
      mkdir -p "$(dirname "$cfg")"
      [ -s "$cfg" ] || echo '{}' > "$cfg"
      setcfg() { $jq "$@" "$cfg" > "$cfg.tmp" && mv "$cfg.tmp" "$cfg"; }

      # place <src> <dir>: copy src to dir; succeeds if dir was new
      place() {
        local new=1
        [ -e "$2" ] && new=
        if [ -n "$new" ] || { [ -f "$2/.dots-managed" ] && [ "$(cat "$2/.dots-managed")" != "$1" ]; }; then
          rm -rf "$2"
          mkdir -p "$(dirname "$2")"
          cp -r "$1" "$2"
          chmod -R u+w "$2"
          printf '%s\n' "$1" > "$2/.dots-managed"
        fi
        [ -n "$new" ]
      }

      place ${theme.src} "${config.xdg.dataHome}/Steam/millennium/themes/${theme.name}" || true
      # make it the active theme, unless another one was picked in Millennium
      if $jq -e '(.themes.activeTheme // "default") == "default"' "$cfg" >/dev/null; then
        setcfg --arg t ${lib.escapeShellArg theme.name} \
          '.themes = ({allowedStyles: true, allowedScripts: true} + .themes + {activeTheme: $t})'
      fi
      # colours Millennium saved for it would override the dots theme's
      if $jq -e --arg t ${lib.escapeShellArg theme.name} '.themes.themeColors | has($t)?' "$cfg" >/dev/null; then
        setcfg --arg t ${lib.escapeShellArg theme.name} 'del(.themes.themeColors[$t])'
      fi

      # plugins are enabled when first installed; disabling one in Millennium sticks
      ${lib.concatStrings (
        lib.mapAttrsToList (name: src: ''
          if place ${src} "${config.xdg.dataHome}/millennium/plugins/${name}"; then
            setcfg --arg p ${name} '.plugins.enabledPlugins = ((.plugins.enabledPlugins // []) - [$p] + [$p])'
          fi
        '') plugins
      )}
    fi
  '';
}
