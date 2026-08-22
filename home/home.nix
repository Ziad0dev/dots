{
  config,
  pkgs,
  lib,
  inputs,
  username,
  system,
  ...
}:

let

  dotsPath = "/home/${username}/dots";

  link = sub: config.lib.file.mkOutOfStoreSymlink "${dotsPath}/config/${sub}";
in
{
  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "24.05";

  programs.home-manager.enable = true;

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    TERMINAL = "ghostty";
    BROWSER = "zen";
    MOZ_ENABLE_WAYLAND = "1";
    NIXOS_OZONE_WL = "1";
    QT_QPA_PLATFORM = "wayland;xcb";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    SDL_VIDEODRIVER = "wayland";
    _JAVA_AWT_WM_NONREPARENTING = "1";
  };

  programs.bash.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;

  };

  services.ssh-agent.enable = true;

  programs.ssh = {
    enable = true;

    enableDefaultConfig = false;

    settings = {
      "*" = {
        AddKeysToAgent = "yes";
        ForwardAgent = false;
        Compression = false;
        ServerAliveInterval = 0;
        ServerAliveCountMax = 3;
        HashKnownHosts = false;
        UserKnownHostsFile = "~/.ssh/known_hosts";
        ControlMaster = "no";
        ControlPath = "~/.ssh/master-%r@%n:%p";
        ControlPersist = "no";
      };

      "github.com" = {
        User = "git";
        IdentityFile = "~/.ssh/id_ed25519";
        IdentitiesOnly = true;

        ControlMaster = "auto";
        ControlPersist = "10m";
      };
    };
  };

  programs.fish = {
    enable = true;

    shellAliases = {
      ll = "ls -l";
      la = "ls -la";
      edit = "sudo -e";
    };

    shellAbbrs = {
      update = "nh os switch";
      upall = "nh os switch -u";
      flakeup = "nix flake update --flake /home/${username}/dots";
      llm = "sudo systemctl start llama-cpp";
      fim = "sudo systemctl start llama-fim";
      llmoff = "sudo systemctl stop llama-cpp llama-fim";
      g = "git";
      gst = "git status";
      gco = "git checkout";
      gp = "git push";
      gl = "git pull";

      tw = "typst watch";
      tc = "typst compile";
      tf = "typstyle -i";
      lmk = "latexmk -pdf -pvc -interaction=nonstopmode";
      lmc = "latexmk -C";
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
    ".config/hypr" = {
      source = link "hypr";
    };
    ".config/dunst" = {
      source = link "dunst";
    };
    ".config/quickshell" = {
      source  = link "quickshell";
    };
    ".config/ghostty" = {
      source = link "ghostty";
    };
    ".config/tmux" = {
      source = link "tmux";
    };
    ".config/nvim" = {
      source = link "nvim";
    };
    ".config/flameshot" = {
      source = link "flameshot";
    };
    ".config/gammastep" = {
      source = link "gammastep";
    };
    ".config/ranger" = {
      source = link "ranger";
    };
    ".config/broot" = {
      source = link "broot";
    };

    ".config/rmpc" = {
      source = link "rmpc";
    };
    ".config/mpv" = {
      source = link "mpv";
    };
    ".config/zen-theme" = {
      source = link "zen";
    };

  };

  qt = {
    enable = true;
    platformTheme.name = "kde";
    style.name = "breeze";
  };

  imports = [
    inputs.nix-index-database.homeModules.default
    inputs.nixcord.homeModules.nixcord
    ./emacs.nix
    ./virt-home.nix
    ./dev-home.nix
    ./gaming-home.nix
    ./documents.nix
    ./fastfetch.nix
    ./quickshell-rise.nix
    ./theming.nix
    ./git-hooks.nix
  ];

  programs.nixcord = {
    enable = true;
    vesktop.enable = true;
    discord.vencord.enable = true;
    discord.krisp.enable = true;
    config = {
      frameless = true;
      plugins = {
        accountPanelServerProfile.enable = true;
        alwaysExpandRoles.enable = true;
        alwaysTrust.enable = true;
        anonymiseFileNames.enable = true;
        autoDndWhilePlaying.enable = true;
        betterFolders.enable = true;
        betterGifAltText.enable = true;
        betterGifPicker.enable = true;
        betterRoleContext.enable = true;
        betterRoleDot.enable = true;
        betterSessions.enable = true;
        betterSettings.enable = true;
        betterUploadButton.enable = true;
        biggerStreamPreview.enable = true;
        blurNsfw.enable = true;
        callTimer.enable = true;
        characterCounter.enable = true;
        clearUrls.enable = true;
        clientTheme.enable = true;
        colorSighted.enable = true;
        concatenatedComponentExtractor.enable = true;
        consoleJanitor.enable = true;
        consoleShortcuts.enable = true;
        copyEmojiMarkdown.enable = true;
        copyFileContents.enable = true;
        copyStickerLinks.enable = true;
        copyUserUrls.enable = true;
        crashHandler.enable = true;
        customCommands.enable = true;
        customIdle.enable = true;
        devCompanion.enable = true;
        disableCallIdle.enable = true;
        disableDeepLinks.enable = true;
        dontRoundMyTimestamps.enable = true;
        experiments.enable = true;
        expressionCloner.enable = true;
        f8Break.enable = true;
        fakeNitro.enable = true;
        fakeProfileThemes.enable = true;
        favoriteEmojiFirst.enable = true;
        fixCodeblockGap.enable = true;
        fixImagesQuality.enable = true;
        fixSpotifyEmbeds.enable = true;
        fixYoutubeEmbeds.enable = true;
        forceOwnerCrown.enable = true;
        friendInvites.enable = true;
        fullSearchContext.enable = true;
        fullUserInChatbox.enable = true;
        gameActivityToggle.enable = true;
        gifPaste.enable = true;
        greetStickerPicker.enable = true;
        hideMedia.enable = true;
        ignoreActivities.enable = true;
        imageFilename.enable = true;
        imageLink.enable = true;
        imageZoom.enable = true;
        implicitRelationships.enable = true;
        ircColors.enable = true;
        keepCurrentChannel.enable = true;
        loadingQuotes.enable = true;
        memberCount.enable = true;
        mentionAvatars.enable = true;
        messageClickActions.enable = true;
        messageLatency.enable = true;
        messageLinkEmbeds.enable = true;
        messageLogger.enable = true;
        moreQuickReactions.enable = true;
        mutualGroupDms.enable = true;
        newGuildSettings.enable = true;
        noBlockedMessages.enable = true;
        noDevtoolsWarning.enable = true;
        noF1.enable = true;
        noMaskedUrlPaste.enable = true;
        noMiddleClickPaste.enable = true;
        noMosaic.enable = true;
        noOnboardingDelay.enable = true;
        noPendingCount.enable = true;
        noReplyMention.enable = true;
        noServerEmojis.enable = true;
        noSystemBadge.enable = true;
        notificationVolume.enable = true;
        noTrack.enable = true;
        noTypingAnimation.enable = true;
        noUnblockToJump.enable = true;
        onePingPerDm.enable = true;
        overrideForumDefaults.enable = true;
        pauseInvitesForever.enable = true;
        permissionFreeWill.enable = true;
        permissionsViewer.enable = true;
        pictureInPicture.enable = true;
        pinDms.enable = true;
        plainFolderIcon.enable = true;
        platformIndicators.enable = true;
        previewMessage.enable = true;
        quickMention.enable = true;
        quickReply.enable = true;
        reactErrorDecoder.enable = true;
        readAllNotificationsButton.enable = true;
        relationshipNotifier.enable = true;
        replyTimestamp.enable = true;
        revealAllSpoilers.enable = true;
        reverseImageSearch.enable = true;
        roleColorEverywhere.enable = true;
        secretRingToneEnabler.enable = true;
        sendTimestamps.enable = true;
        serverInfo.enable = true;
        serverListIndicators.enable = true;
        settings.enable = true;
        shikiCodeblocks.enable = true;
        showAllMessageButtons.enable = true;
        showConnections.enable = true;
        showHiddenChannels.enable = true;
        showHiddenThings.enable = true;
        showMeYourName.enable = true;
        showTimeoutDuration.enable = true;
        silentMessageToggle.enable = true;
        silentTyping.enable = true;
        sortFriendRequests.enable = true;
        spotifyControls.enable = true;
        spotifyCrack.enable = true;
        spotifyShareCommands.enable = true;
        startupTimings.enable = true;
        stickerPaste.enable = true;
        summaries.enable = true;
        superReactionTweaks.enable = true;
        supportHelper.enable = true;
        tenorGifSearch.enable = true;
        textReplace.enable = true;
        themeAttributes.enable = true;
        translate.enable = true;
        typingIndicator.enable = true;
        typingTweaks.enable = true;
        unindent.enable = true;
        unlockedAvatarZoom.enable = true;
        unsuppressEmbeds.enable = true;
        userMessagesPronouns.enable = true;
        userVoiceShow.enable = true;
        validReply.enable = true;
        validUser.enable = true;
        vencordToolbox.enable = true;
        viewIcons.enable = true;
        viewRaw.enable = true;
        voiceChatDoubleClick.enable = true;
        voiceDownload.enable = true;
        voiceMessages.enable = true;
        volumeBooster.enable = true;
        webContextMenus.enable = true;
        webKeybinds.enable = true;
        webRichPresence.enable = true;
        webScreenShareFixes.enable = true;
        whoReacted.enable = true;
        xsOverlay.enable = true;
        youtubeAdblock.enable = true;
      };
    };
  };

  home.packages =
    let
      beamPkgs = pkgs.beam.packages.erlang_27;
    in
    (with pkgs; [
      # ── Wayland session ────────────────────────────────────────────────
      dunst
      ghostty
      hyprlock
      hypridle
      awww
      cliphist
      wl-clipboard
      grim
      slurp
      satty
      (flameshot.override { enableWlrSupport = true; })
      gammastep
      brightnessctl
      libnotify
      impala
      bluetui
      wiremix
      networkmanager
      # media keys: hyprland binds -> playerctl -> mpdris2 -> mpd
      playerctl
      shellcheck

      # ── Audio ─────────────────────────────────────────────────────────
      pamixer
      pavucontrol
      mpc
      rmpc
      tauon
      easyeffects

      # ── Video / media ─────────────────────────────────────────────────
      mpv
      haruna
      mpc-qt
      obs-studio
      cliamp

      # ── Browsers / chat ───────────────────────────────────────────────
      chromium
      tor
      tor-browser
      element-desktop
      # vesktop NOT here — programs.nixcord (vesktop.enable = true) installs
      # its own patched build; listing it again collides in buildEnv.
      weechat

      # ── Files / TUI ───────────────────────────────────────────────────
      ripgrep
      fd
      ranger
      yazi
      broot
      tmux
      jujutsu
      jrnl

      # ── Downloads / library ───────────────────────────────────────────
      qbittorrent
      nicotine-plus
      calibre
      spotify

      # ── Editors / toolchains ──────────────────────────────────────────
      # rustup deliberately dropped: it shadows the nix-provided rust in
      # `nix flake init -t ~/dots#rust` devshells. Use the template instead.
      vscode
      gcc
      gnumake
      pkg-config
      xdotool
      cmake
      go
      nodejs_22
      lua
      tree-sitter
      luarocks
    ])
    ++ [
      beamPkgs.erlang
      beamPkgs.elixir
      beamPkgs.elixir-ls
      inputs.zen-browser.packages.${system}.default
      inputs.helium.defaultPackage.${system}
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
      WorkingDirectory = "%h/dots";
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
