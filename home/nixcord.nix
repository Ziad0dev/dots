{ lib, pkgs, ... }:

let
  openasar = builtins.toJSON {
    cmdPreset = "balanced";
    customFlags = "--enable-gpu-rasterization --enable-zero-copy --ignore-gpu-blocklist --enable-hardware-overlays=single-fullscreen,single-on-top,underlay --enable-features=CanvasOopRasterization,BackForwardCache:TimeToLiveInBackForwardCacheInSeconds/300/should_ignore_blocklists/true/enable_same_site/true,ThrottleDisplayNoneAndVisibilityHiddenCrossOriginIframes,UseSkiaRenderer,WebAssemblyLazyCompilation --disable-features=Vulkan --force_high_performance_gpu";
  };
in
{
  home.activation.discordOpenasarFlags = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    f="$HOME/.config/discord/settings.json"
    mkdir -p "$(dirname "$f")"
    [ -s "$f" ] || echo '{}' > "$f"
    ${lib.getExe pkgs.jq} --argjson oa '${openasar}' '.openasar = ((.openasar // {}) + $oa)' "$f" > "$f.tmp"
    mv "$f.tmp" "$f"
  '';

  programs.nixcord = {
    enable = true;
    discord.vencord.enable = true;
    discord.krisp.enable = true;
    discord.openASAR.enable = true;

    userPlugins = {
      bigFileUpload = "github:ScattrdBlade/bigFileUpload/837e9efe85ce026063a13ef7fef12e96b3a0aa18";
      junkCleanup = "github:Sqaaakoi/vc-junkCleanup/2a3b173d77b4fdd695e7a39a124feb403923401a";
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
    extraConfig.plugins = {
      JunkCleanup.enable = true;

      BigFileUpload = {
        enable = true;
        fileUploader = "Litterbox";
        litterboxTime = "72h";
        respectNitroLimit = "Yes";
        nitroType = "none";
        disableFallbacks = "No";
        autoSend = "No";
        autoFormat = "Yes";
        useNotifications = "No";
        useEmbedsVideo = "Yes";
        embedService = "x266";
        dragAndDropEnabled = "Yes";
        pasteEnabled = "Yes";
        uploadTimeout = "300000";
        loggingLevel = "errors";
      };
    };
  };
}
