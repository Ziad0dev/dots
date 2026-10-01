{ lib, pkgs, options, ... }:
let
  vencord = options.programs.nixcord.discord.vencord.package.default.overrideAttrs (o: {
    postPatch = (o.postPatch or "") + ''
      substituteInPlace src/plugins/voiceMessages/index.tsx \
        --replace-fail \
          'IS_DISCORD_DESKTOP ? VoiceRecorderDesktop : VoiceRecorderWeb' \
          'VoiceRecorderWeb'
    '';
  });

  discord = lib.makeOverridable (lib.mirrorFunctionArgs pkgs.discord.override (
    args: pkgs.discord.override (builtins.intersectAttrs (lib.functionArgs pkgs.discord.override) args)
  )) { };

  openasar = builtins.toJSON {
    cmdPreset = "perf";
    customFlags = "--disable-features=WaylandWpColorManagerV1,EnableDrDc --disable-gpu-memory-buffer-video-frames --disable-accelerated-video-decode";
  };
in
{
  home.activation.discordOpenasarFlags = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [[ ! -v DRY_RUN ]]; then
      f="$HOME/.config/discord/settings.json"
      mkdir -p "$(dirname "$f")"
      [ -s "$f" ] || echo '{}' > "$f"
      if ${lib.getExe pkgs.jq} --argjson oa '${openasar}' '.openasar = ((.openasar // {}) + $oa)' "$f" > "$f.tmp"; then
        mv "$f.tmp" "$f"
      else
        rm -f "$f.tmp"
      fi
    fi
  '';

  programs.nixcord = {
    enable = true;

    discord = {
      enable = true;
      package = discord;
      vencord = {
        enable = true;
        package = vencord;
      };
      openASAR.enable = true;
      commandLineArgs = [ "--enable-logging=file" ];
    };

    config = {
      frameless = true;
      useQuickCss = true;
      plugins = {
        anonymiseFileNames.enable = true;
        clearUrls.enable = true;
        crashHandler.enable = true;
        customIdle.enable = true;
        disableDeepLinks.enable = true;
        fakeNitro.enable = true;
        fixImagesQuality.enable = true;
        fixSpotifyEmbeds.enable = true;
        fixYoutubeEmbeds.enable = true;
        gameActivityToggle.enable = true;
        messageLogger.enable = true;
        noMosaic.enable = true;
        noPendingCount.enable = true;
        noTrack.enable = true;
        permissionsViewer.enable = true;
        pictureInPicture.enable = true;
        quickReply.enable = true;
        reverseImageSearch.enable = true;
        settings.enable = true;
        silentTyping.enable = true;
        spotifyControls.enable = true;
        translate.enable = true;
        unsuppressEmbeds.enable = true;
        viewRaw.enable = true;
        volumeBooster.enable = true;
        youtubeAdblock.enable = true;
        disableCallIdle.enable = true;
        memberCount.enable = true;
        spotifyCrack.enable = true;
        voiceChatDoubleClick.enable = true;
        voiceMessages.enable = true;
      };
    };
  };
}
