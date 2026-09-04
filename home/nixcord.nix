{ ... }:

{
  programs.nixcord = {
    enable = true;
    discord.vencord.enable = true;
    discord.krisp.enable = true;

    userPlugins = {
      bigFileUpload = "github:ScattrdBlade/bigFileUpload/837e9efe85ce026063a13ef7fef12e96b3a0aa18";
      showMeYourTime = "github:ih8js-git/showMeYourTime/7d5b742b6eab4aa72bfa2874f758e6d77704fe4e";
      vAnalyzer = "github:nay-cat/vAnalyzer/4cae389775defc5277627ae6d354d27616e923a4";
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
      };
    };
    extraConfig.plugins = {
      ShowMeYourTime.enable = true;

      vAnalyzer.enable = true;

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
