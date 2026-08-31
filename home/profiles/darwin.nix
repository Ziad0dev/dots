{ pkgs, ... }:

{
  home.sessionVariables.BROWSER = "open";

  home.packages = with pkgs; [
    coreutils
    findutils
    gnused
    gnugrep
    gnutar
    gawk
    watch
    pinentry_mac
    mas
  ];

  programs.fish.shellAbbrs = {
    o = "open";
    oo = "open .";
    brewup = "brew update && brew upgrade";
  };

  programs.fish.interactiveShellInit = ''
    fish_add_path /opt/homebrew/bin
    fish_add_path /run/current-system/sw/bin
  '';

  targets.darwin.defaults = {
    NSGlobalDomain = {
      AppleShowAllExtensions = true;
      ApplePressAndHoldEnabled = false;
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      NSNavPanelExpandedStateForSaveMode = true;
    };
    "com.apple.finder" = {
      AppleShowAllFiles = true;
      FXPreferredViewStyle = "clmv";
      ShowPathbar = true;
      ShowStatusBar = true;
      _FXShowPosixPathInTitle = true;
    };
    "com.apple.screencapture".location = "~/Pictures/screenshots";
  };
}
