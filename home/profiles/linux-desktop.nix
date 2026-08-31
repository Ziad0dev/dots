{
  config,
  pkgs,
  inputs,
  username,
  system,
  ...
}:

let
  link = sub: config.lib.file.mkOutOfStoreSymlink "${config.dots.repoPath}/config/${sub}";
in
{
  imports = [
    inputs.nixcord.homeModules.nixcord
    ../nixcord.nix
    ../emacs.nix
    ../virt-home.nix
    ../gaming-home.nix
    ../documents.nix
    ../quickshell-rise.nix
    ../theming.nix
    ../ai-usage.nix
    ../kvantum.nix
    ../obsidian.nix
  ];

  home.sessionVariables = {
    BROWSER = "zen";
    SDL_VIDEODRIVER = "wayland";
  };

  home.pointerCursor = {
    enable = true;
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 24;
  };

  gtk = {
    enable = true;
    theme = {
      package = pkgs.adw-gtk3;
      name = "adw-gtk3-dark";
    };
    iconTheme = {
      package = pkgs.papirus-icon-theme;
      name = "Papirus-Dark";
    };
    gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
    gtk4.theme = null;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
  };

  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";

  xdg.configFile."vesktop/settings/settings.json".enable = false;

  xdg.desktopEntries.discord = {
    name = "Discord";
    genericName = "Internet Messenger";
    exec = "discord --ozone-platform-hint=auto --enable-features=WaylandWindowDecorations %U";
    icon = "discord";
    terminal = false;
    categories = [
      "Network"
      "InstantMessaging"
    ];
    mimeType = [ "x-scheme-handler/discord" ];
  };

  services.ssh-agent.enable = true;

  home.file = {
    ".config/hypr".source = link "hypr";
    ".config/dunst".source = link "dunst";
    ".config/Kvantum/KvGlass".source = link "kvantum/KvGlass";
    ".config/Kvantum/Glass-Kv".source = link "kvantum/Glass-Kv";
    ".config/quickshell".source = link "quickshell";
    ".config/flameshot".source = link "flameshot";
    ".config/gammastep".source = link "gammastep";
    ".config/rmpc".source = link "rmpc";
    ".config/mpv".source = link "mpv";
    ".config/zen-theme".source = link "zen";
    ".config/hyprland-preview-share-picker".source = link "hyprland-preview-share-picker";
  };

  home.packages =
    let
      beamPkgs = pkgs.beam.packages.erlang_27;
    in
    (with pkgs; [
      dunst
      ghostty
      hypridle
      hyprpicker
      awww
      cliphist
      wl-clipboard
      wtype
      grim
      slurp
      satty
      (tesseract.override { enableLanguages = [ "eng" "swe" "ara" "fra" "deu" ]; })
      zbar
      (flameshot.override { enableWlrSupport = true; })
      gammastep
      brightnessctl
      libnotify
      impala
      bluetui
      wiremix
      networkmanager
      playerctl

      pamixer
      pavucontrol
      mpc
      rmpc
      tauon
      easyeffects
      qpwgraph

      mpv
      haruna
      mpc-qt
      qt6.qtwayland
      obs-studio
      cliamp

      chromium
      tor
      tor-browser
      element-desktop
      weechat

      qbittorrent
      nicotine-plus
      calibre
      spotify

      vscode
      gcc
      xdotool
    ])
    ++ [
      beamPkgs.erlang
      beamPkgs.elixir
      beamPkgs.elixir-ls
      inputs.zen-browser.packages.${system}.default
      inputs.helium.defaultPackage.${system}
      inputs.vm-curator.packages.${system}.default
    ];

  services.cliphist.enable = true;

  systemd.user.targets.hyprland-session = {
    Unit = {
      Description = "Hyprland session";
      Documentation = [ "man:systemd.special(7)" ];
      BindsTo = [ "graphical-session.target" ];
      Wants = [ "graphical-session-pre.target" ];
      After = [ "graphical-session-pre.target" ];
      PropagatesStopTo = [ "graphical-session.target" ];
    };
  };

  systemd.user.services.hypridle = {
    Unit = {
      Description = "hypridle";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.hypridle}/bin/hypridle";
      ExecStartPost = "${pkgs.bash}/bin/sh -c 'rm -f %S/dots/indicators/stay-awake'";
      ExecStopPost = "${pkgs.bash}/bin/sh -c 'mkdir -p %S/dots/indicators && touch %S/dots/indicators/stay-awake'";
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.lastfm-secret = {
    Unit = {
      Description = "Materialize the last.fm password from secretspec";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      Before = [ "mpdscribble.service" ];
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      WorkingDirectory = config.dots.repoPath;
      ExecStart = toString (
        pkgs.writeShellScript "lastfm-secret" ''
          set -eu
          umask 077
          mkdir -p "$HOME/.local/share/secrets"
          v=$(${pkgs.secretspec}/bin/secretspec get LASTFM_PASSWORD)
          [ -n "$v" ] || { echo "secretspec returned nothing, refusing to write" >&2; exit 1; }
          printf '%s' "$v" > "$HOME/.local/share/secrets/mpdscribble"
        ''
      );
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  services.udiskie = {
    enable = true;
    automount = true;
    notify = true;
    tray = "auto";
    settings = {
      device_config = [
        {
          id_uuid = "6087-5FAB";
          ignore = true;
        }
        {
          id_uuid = "2A0B-58D1";
          ignore = true;
        }
        {
          id_uuid = "4619-E5D1";
          ignore = true;
        }
      ];
    };
  };

  services.mpd = {
    enable = true;

    musicDirectory = "/mnt/media/music";
    network = {
      listenAddress = "127.0.0.1";
      port = 6600;
      startWhenNeeded = true;
    };
    extraConfig = ''
      restore_paused "yes"

      audio_output {
        type "pipewire"
        name "PipeWire"
      }

      audio_output {
        type "alsa"
        name "DAC bit-perfect"
        device "hw:CARD=G30"
        auto_resample "no"
        auto_format "no"
        auto_channels "no"
        mixer_type "none"
        enabled "no"
      }
    '';
  };

  systemd.user.services.mpd.Unit.RequiresMountsFor = [ "/mnt/media" ];

  services.mpdris2 = {
    enable = true;
    mpd.host = "127.0.0.1";
    notifications = true;
    multimediaKeys = true;
  };

  services.mpdscribble = {
    enable = true;
    endpoints."last.fm" = {
      username = "";
      passwordFile = "${config.home.homeDirectory}/.local/share/secrets/mpdscribble";
    };
  };
}
