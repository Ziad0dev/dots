{ ... }:

{
  programs.nixcord = {
    enable = true;
    discord.vencord.enable = true;
    discord.krisp.enable = true;
    discord.openASAR.enable = false;

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
