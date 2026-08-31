{
  pkgs,
  username,
  hostname,
  ...
}:

{
  networking.hostName = hostname;
  networking.computerName = hostname;

  system.stateVersion = 6;
  system.primaryUser = username;

  users.users.${username} = {
    name = username;
    home = "/Users/${username}";
    shell = pkgs.fish;
  };

  nixpkgs.config.allowUnfree = true;

  nix.enable = true;
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [
      "root"
      username
    ];
    max-jobs = "auto";
    keep-outputs = true;
    keep-derivations = true;
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  nix.gc = {
    automatic = true;
    options = "--delete-older-than 30d";
  };
  nix.optimise.automatic = true;

  programs.fish.enable = true;
  environment.shells = [ pkgs.fish ];

  environment.systemPackages = with pkgs; [
    git
    curl
    wget
    jq
    tree
    neovim
    htop
    btop
  ];

  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
    nerd-fonts.jetbrains-mono
  ];

  security.pam.services.sudo_local.touchIdAuth = true;

  system.defaults = {
    dock = {
      autohide = true;
      mru-spaces = false;
      show-recents = false;
      tilesize = 42;
    };
    finder = {
      AppleShowAllExtensions = true;
      FXPreferredViewStyle = "clmv";
      ShowPathbar = true;
    };
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
      "com.apple.swipescrolldirection" = false;
    };
    screencapture.type = "png";
    trackpad.Clicking = true;
  };

  homebrew = {
    enable = false;
    onActivation = {
      autoUpdate = true;
      cleanup = "zap";
    };
    brews = [ ];
    casks = [
      "ghostty"
      "zen"
      "raycast"
      "rectangle"
      "iina"
      "obs"
    ];
  };
}
