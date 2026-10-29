{
  lib,
  pkgs,
  options,
  ...
}:
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

in
{
  programs.nixcord = {
    enable = true;

    # no theme, just hide the upsell: Nitro, Shop, Quests and the gift button
    quickCss = ''
      li:has(a[href="/store"]),
      li:has(a[href="/shop"]),
      li:has(a[href="/quest-home"]),
      a[href="/store"],
      a[href="/shop"],
      a[href="/quest-home"],
      button[aria-label*="gift" i],
      [role="button"][aria-label*="gift" i] {
        display: none !important;
      }
    '';

    discord = {
      enable = true;
      package = discord;
      vencord = {
        enable = true;
        package = vencord;
      };
      openASAR.enable = false;
      commandLineArgs = [
        "--disable-features=WaylandWpColorManagerV1,EnableDrDc"

      ];
    };

    config = {
      frameless = true;
      transparent = false;
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
