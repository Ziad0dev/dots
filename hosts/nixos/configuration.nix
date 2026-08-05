{ config, pkgs, inputs, username, hostname, system, ... }:

{
  imports = [

    inputs.hyprland.nixosModules.default
  ];

   systemd.services.systemd-suspend.environment.SYSTEMD_SLEEP_FREEZE_USER_SESSIONS = "false";

   boot.kernelModules = [ "nct6775" ];

   systemd.sleep.settings.Sleep = {
    AllowSuspend = "no";
    AllowHibernation = "no";
    AllowHybridSleep = "no";
    AllowSuspendThenHibernate = "no";
    };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 3;

  networking.hostName            = hostname;
  networking.networkmanager.enable = true;

  time.timeZone      = "Europe/Stockholm";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS        = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT    = "en_US.UTF-8";
    LC_MONETARY       = "en_US.UTF-8";
    LC_NAME           = "en_US.UTF-8";
    LC_NUMERIC        = "en_US.UTF-8";
    LC_PAPER          = "en_US.UTF-8";
    LC_TELEPHONE      = "en_US.UTF-8";
    LC_TIME           = "en_US.UTF-8";
  };

  services.xserver = {
    enable      = true;
    xkb.layout  = "us";
  };

  zramSwap = {
    enable = true;
    memoryPercent = 50;

  };
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.graphics = {
    enable      = true;
    enable32Bit = true;
  };
  hardware.nvidia = {
  modesetting.enable = true;
  open = true;
  package = config.boot.kernelPackages.nvidiaPackages.latest;
};

  services.displayManager.sddm = {
    enable         = true;
    wayland.enable = true;
    theme          = "breeze";
  };
  services.prowlarr = {
    enable = true;
    openFirewall = true;
  };
  services.flaresolverr = {
    enable = true;
    openFirewall = true;
  };

  services.desktopManager.plasma6.enable = true;
  programs.coolercontrol.enable = true;
  services.resolved.enable = true;

  programs.hyprland = {
    enable         = true;
    package        = inputs.hyprland.packages.${system}.hyprland;
    xwayland.enable = true;
  };

  xdg.portal = {
    enable = true;
    config = {
      common.default           = [ "kde" ];
      hyprland.default         = [ "hyprland" "kde" ];
      hyprland."org.freedesktop.impl.portal.Secret" = [ "kde" ];
    };
  };

  services.dbus.enable       = true;
  security.polkit.enable     = true;

  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id.indexOf("org.freedesktop.udisks2.") === 0 &&
          subject.local && subject.active) {
        return polkit.Result.YES;
      }
    });
  '';
  services.printing.enable   = true;
  services.gvfs.enable       = true;
  services.udisks2.enable    = true;

  hardware.bluetooth = {
    enable      = false;
    powerOnBoot = false;
  };
  services.blueman.enable = false;

  virtualisation.docker = {
    enable           = true;
    enableOnBoot     = true;
  };

  users.users.${username} = {
    isNormalUser = true;
    description  = username;

    uid          = 1001;
    extraGroups  = [ "wheel" "networkmanager" "docker" "audio" "video" "input" ];
    shell        = pkgs.fish;
  };
  programs.fish.enable = true;

  nixpkgs.overlays = [ inputs.zig-overlay.overlays.default ];
  nixpkgs.config.allowUnfree = true;

  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store   = true;

      substituters          = [
        "https://cache.nixos.org"
        "https://hyprland.cachix.org"
      ];
      trusted-public-keys   = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      ];
    };

  };

  environment.systemPackages = with pkgs; [

    inputs.zen-browser.packages.${system}.default
    pkgs.coolercontrol.coolercontrol-gui
    pkgs.spotify
    inputs.helium.defaultPackage.${system}

    git curl wget jq tree unzip zip
    htop btop ripgrep fd nicotine-plus
    gcc gnumake pkg-config podman
    gparted tauon obs-studio

    nodejs_22

    go
    rustup
    lua
    fastfetch
    cmake

    luarocks
    chromium
    lm_sensors

    weechat
    tor
    tor-browser
    element-desktop
    vesktop
    calibre

    neovim
    vscode

    waybar
    dunst
    haruna
    mpv
    qbittorrent
    rofi
    ghostty
    wl-clipboard
    grim
    slurp
    playerctl
    awww
    pamixer
    mpc-qt
    jujutsu
    pavucontrol
    brightnessctl
    networkmanagerapplet
    libnotify
    hypridle
    hyprlock
    hyprpolkitagent
    kdePackages.qt6ct

    ranger
    yazi
    broot
    satty
    flameshot
    (flameshot.override { enableWlrSupport = true; })
    gammastep
    rmpc
    exfatprogs

    kdePackages.dolphin
    kdePackages.ark
    kdePackages.kate
    kdePackages.kwallet
    kdePackages.kwalletmanager
    kdePackages.ksystemlog
  ];

  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      nerd-fonts.fira-code
      nerd-fonts.jetbrains-mono
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      font-awesome
    ];
    fontconfig.defaultFonts = {
      monospace  = [ "FiraCode Nerd Font Mono" ];
      sansSerif  = [ "Noto Sans" ];
      serif      = [ "Noto Serif" ];
      emoji      = [ "Noto Color Emoji" ];
    };
  };

  programs.git.enable    = true;
  programs.nix-ld.enable = true;
  programs.dconf.enable  = true;

  system.stateVersion = "24.05";
}
