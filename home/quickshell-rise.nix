{
  config,
  lib,
  pkgs,
  ...
}:
let
  thumbPrune = pkgs.writeShellApplication {
    name = "dots-thumb-prune";
    runtimeInputs = [ pkgs.coreutils pkgs.findutils ];
    text = ''
      D="$HOME/.cache/quickshell-img-thumbs"
      H="$HOME/.cache/quickshell-img-thumb-hashes.tsv"
      [ -d "$D" ] && find "$D" -type f -name '*-512.jpg' -atime +30 -delete || true
      if [ -f "$H" ]; then
        awk -F '\t' '{ i = index($0, "\t"); k = substr($0, 1, i-1); if (!(k in seen)) o[++n] = k; seen[k] = substr($0, i+1) } END { for (j = 1; j <= n; j++) print o[j] "\t" seen[o[j]] }' "$H" > "$H.t" && mv -f "$H.t" "$H"
      fi
      rm -f "$HOME/.cache/quickshell-theme-picker"/*.tmp 2>/dev/null || true
    '';
  };

  homeDir = config.home.homeDirectory;
  dots = "${homeDir}/dots";

  shimNames = [
    "dots-audio-input-mute"
    "dots-brightness-display"
    "dots-capture-screenrecording"
    "dots-hw-display"
    "dots-launch-audio"
    "dots-launch-bluetooth"
    "dots-launch-floating-terminal-with-presentation"
    "dots-launch-or-focus-tui"
    "dots-launch-wifi"
    "dots-screenrecord-filename"
    "dots-shell" 
    "dots-theme-bg-set"
    "dots-theme-set"
    "dots-toggle-idle"
    "dots-toggle-notification-silencing"
    "dots-tz-select"
    "dots-update"
    "dots-update-available"
    "dots-voxtype-config"
    "dots-voxtype-model"
    "dots-updates"
  ];

  setWallpaper = pkgs.writeShellApplication {
    name = "dots-set-wallpaper";
    runtimeInputs = [ pkgs.coreutils ];
    text = builtins.readFile ../scripts/dots-set-wallpaper.sh;
  };

  currentWallpaper = pkgs.writeShellApplication {
    name = "dots-current-wallpaper";
    runtimeInputs = with pkgs; [ coreutils gnused ];
    text = builtins.readFile ../scripts/dots-current-wallpaper.sh;
  };



  helpers = [
    setWallpaper
    currentWallpaper
  ];

  compatBase = pkgs.writeShellApplication {
    name = "dots-compat";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      fzf
      gnugrep
      ghostty
      procps
      systemd
      wireplumber
    ];
    text = builtins.readFile ../scripts/dots-compat.sh;
  };

  # every shim is the same script; $0 selects the branch
  dotsShims = pkgs.runCommandLocal "dots-shims" { } ''
    mkdir -p $out/bin
    for n in ${lib.escapeShellArgs shimNames}; do
      ln -s ${compatBase}/bin/dots-compat $out/bin/$n
    done
  '';

  risePath = lib.makeBinPath (
    helpers
    ++ (with pkgs; [
      bash
      coreutils
      ffmpegthumbnailer
      findutils
      gawk
      gnugrep
      gnused
      imagemagick
      jq
      libnotify
      pamixer
      procps
      pulseaudio
      socat
      systemd
      wireplumber
      xdg-user-dirs
    ])
  );
in
{
  home.packages = helpers ++ [
    dotsShims
    pkgs.pulseaudio
    pkgs.wireplumber
    pkgs.nvtopPackages.nvidia
    pkgs.material-symbols
    pkgs.nerd-fonts.jetbrains-mono
  ];

  programs.quickshell = {
    enable = true;
    package = pkgs.quickshell;
    activeConfig = "rise";
    systemd = {
      enable = true;
      target = "hyprland-session.target";
    };
  };

  systemd.user.services.quickshell = {
    Unit.PartOf = [ "hyprland-session.target" ];
    Service = {
      Environment = [
        "PATH=${risePath}:${dotsShims}/bin:/etc/profiles/per-user/${config.home.username}/bin:${homeDir}/.nix-profile/bin:/run/wrappers/bin:/run/current-system/sw/bin"
        "DOTS_SHELL_PATH=${dots}/config/quickshell/rise"
      ];
      Slice = "app-graphical.slice";
      KillMode = "process";
      ExecStopPost = [
        "-${pkgs.procps}/bin/pkill -f ${dots}/config/quickshell/rise/scripts/"
      ];
      RestartSec = 2;
    };
  };

  systemd.user.services.dots-thumb-prune = {
    Unit.Description = "Prune quickshell picker thumbnail caches";
    Service = {
      Type = "oneshot";
      ExecStart = "${thumbPrune}/bin/dots-thumb-prune";
    };
  };

  systemd.user.timers.dots-thumb-prune = {
    Unit.Description = "Weekly quickshell thumbnail cache prune";
    Timer = {
      OnCalendar = "weekly";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
