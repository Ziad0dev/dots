{ config, pkgs, lib, inputs, username, system, ... }:

let

  dotsPath = "/home/${username}/dots";

  link = sub: config.lib.file.mkOutOfStoreSymlink "${dotsPath}/config/${sub}";
in
{
  home.username      = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion  = "24.05";

  programs.home-manager.enable = true;

  home.sessionVariables = {
    EDITOR   = "nvim";
    VISUAL   = "nvim";
    TERMINAL = "ghostty";
    BROWSER  = "zen";
    MOZ_ENABLE_WAYLAND = "1";
    NIXOS_OZONE_WL     = "1";
    QT_QPA_PLATFORM    = "wayland;xcb";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    SDL_VIDEODRIVER    = "wayland";
    _JAVA_AWT_WM_NONREPARENTING = "1";
  };

  programs.bash.enable = true;

  programs.direnv = {
    enable            = true;
    nix-direnv.enable = true;

  };

  programs.fish = {
    enable = true;

    shellAliases = {
      ll     = "ls -l";
      la     = "ls -la";
      edit   = "sudo -e";
    };

    shellAbbrs = {
      update  = "nh os switch";
      upall   = "nh os switch -u";
      flakeup = "nix flake update --flake /home/${username}/dots";
      llm     = "sudo systemctl start llama-cpp";
      fim     = "sudo systemctl start llama-fim";
      llmoff  = "sudo systemctl stop llama-cpp llama-fim";
      g       = "git";
      gst     = "git status";
      gco     = "git checkout";
      gp      = "git push";
      gl      = "git pull";
    };

    functions = {
      dnx = {
        description = "Transcode video to DNxHR HQ for DaVinci Resolve";
        body = ''
          for f in $argv
            ffmpeg -n -i $f -c:v dnxhd -profile:v dnxhr_hq -c:a pcm_s16le \
              -pix_fmt yuv422p (path change-extension mov $f)
          end
        '';
      };
    };

    interactiveShellInit = "fish_vi_key_bindings";
  };

  home.file = {
    ".config/hypr"      = { source = link "hypr"; };
    ".config/waybar"    = { source = link "waybar"; };
    ".config/dunst"     = { source = link "dunst"; };
    ".config/rofi"      = { source = link "rofi"; };
    ".config/ghostty"   = { source = link "ghostty"; };
    ".config/nvim"      = { source = link "nvim"; };
    ".config/flameshot" = { source = link "flameshot"; };
    ".config/gammastep" = { source = link "gammastep"; };
    ".config/ranger"    = { source = link "ranger"; };
    ".config/yazi"      = { source = link "yazi"; };
    ".config/broot"     = { source = link "broot"; };

    ".config/rmpc"      = { source = link "rmpc"; };
    ".config/mpv"       = { source = link "mpv"; };
    ".config/zen-theme"  = { source = link "zen"; };

  };

  qt = {
    enable             = true;
    platformTheme.name = "kde";
    style.name         = "breeze";
  };

  imports = [
    inputs.nix-index-database.homeModules.default
    inputs.nixcord.homeModules.nixcord
    ./emacs.nix
    ./virt-home.nix
    ./dev-home.nix
    ./gaming-home.nix
  ];

  programs.nixcord = {
    enable = true;
    vesktop.enable = true;
    discord.vencord.enable = true;
    discord.krisp.enable = true;
    config = {
      frameless = true;
     plugins = {
        messageLogger.enable = true;
        alwaysTrust.enable = true;
        betterFolders.enable = true;
        blurNsfw.enable = true;
        callTimer.enable = true;
        clearUrls.enable = true;
        fakeNitro.enable = true;
        fixSpotifyEmbeds.enable = true;
        imageZoom.enable = true;
        noF1.enable = true;
        noTypingAnimation.enable = true;
        silentTyping.enable = true;
        volumeBooster.enable = true;
        webScreenShareFixes.enable = true;
        youtubeAdblock.enable = true;
      };
    };
  };

  home.packages = let
    beamPkgs = pkgs.beam.packages.erlang_27;
  in (with pkgs; [
    cliphist
    wl-clipboard
    mpc
  ]) ++ [
    beamPkgs.erlang
    beamPkgs.elixir
    beamPkgs.elixir-ls
  ];

  services.cliphist.enable = true;

  systemd.user.targets.hyprland-session = {
    Unit = {
      Description      = "Hyprland session";
      Documentation    = [ "man:systemd.special(7)" ];
      BindsTo          = [ "graphical-session.target" ];
      Wants            = [ "graphical-session-pre.target" ];
      After            = [ "graphical-session-pre.target" ];
      PropagatesStopTo = [ "graphical-session.target" ];
    };
  };

  services.udiskie = {
    enable       = true;
    automount    = true;
    notify       = true;
    tray         = "auto";
    settings = {
      device_config = [
        { id_uuid = "6087-5FAB"; ignore = true; }
        { id_uuid = "2A0B-58D1"; ignore = true; }
        { id_uuid = "4619-E5D1"; ignore = true; }
      ];
    };
  };

  services.mpd = {
    enable         = true;

    musicDirectory = "/mnt/media/music";
    network = {
      listenAddress   = "127.0.0.1";
      port            = 6600;
      startWhenNeeded = true;
    };
    extraConfig = ''
      restore_paused "yes"

      # auto_update deliberately off: inotify across a whole USB exFAT drive
      # is expensive and breaks when the drive goes away. Use `mpc update`.

      audio_output {
        type "pipewire"
        name "PipeWire"
      }

      # Bit-perfect path: straight to the DAC, exclusive access, hardware
      # rates, no software mixer. Find the id with `aplay -l` and fix the
      # device line. Off by default — flip it on from rmpc's outputs view
      # (or `mpc enable 2`) for critical listening; PipeWire loses the
      # device while it's active.
      audio_output {
        type "alsa"
        name "DAC bit-perfect"
        device "hw:CARD=DAC"   # ← adjust after `aplay -l`
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
    enable        = true;
    mpd.host      = "127.0.0.1";
    notifications = true;
    multimediaKeys = true;
  };

  services.mpdscribble = {
    enable = true;
    endpoints."last.fm" = {
      username     = "";
      passwordFile = "${config.home.homeDirectory}/.local/share/secrets/mpdscribble";
    };
  };

}
