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

  # For the official NVIDIA GeForce NOW client, which is only distributed as a
  # Flatpak (NVIDIA's .bin installer is a PyInstaller/Tk bundle that dies on
  # NixOS with `ImportError: libxcb.so.1`, so add the remotes by hand instead):
  #
  #   flatpak remote-add --user --if-not-exists flathub \
  #     https://flathub.org/repo/flathub.flatpakrepo
  #   flatpak remote-add --user --if-not-exists GeForceNOW \
  #     https://international.download.nvidia.com/GFNLinux/flatpak/geforcenow.flatpakrepo
  #   flatpak install -y --user GeForceNOW com.nvidia.geforcenow
  #
  # Flathub is required even though the app lives on NVIDIA's remote: the
  # matching org.freedesktop.Platform.GL.nvidia-<driver> extension and the
  # freedesktop runtime come from Flathub.
  services.flatpak.enable = true;

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

    # WAS config.boot.kernelPackages.nvidiaPackages.latest. That resolves inside
    # chaotic's linuxPackages_cachyos scope. pkgs.nvidia_cachyos is a plain pkgs
    # attribute and is built by chaotic against the CachyOS kernel, so the module
    # ABI still matches. Do NOT use pkgs.linuxPackages.nvidiaPackages.latest --
    # it evaluates, but builds against the vanilla kernel.
    package = pkgs.nvidia_cachyos;
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

  # iOS device access over USB. Provides usbmuxd.service, the usbmux user,
  # and the udev rules that let a local user reach /var/run/usbmuxd.
  services.usbmuxd.enable    = true;

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

  # Kept only until `nix flake update chaotic` lands the fix for
  # chaotic-cx/nyx#2276 (PR #2304, "cache-friendly: evaluate deferred nixpkgs
  # config before re-import"). Recent nixpkgs made nixpkgs.config a deferred
  # module; chaotic passed it unevaluated into its own `import nixpkgs`, so its
  # instance ran with no config and every chaotic-provided unfree package
  # refused. Drop this line once a pure `nh os switch` succeeds without it.
  nixpkgs.config.allowUnfreePredicate = _: true;

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
    gparted tauon obs-studio jrnl 

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

    usbutils
    libimobiledevice
    ifuse

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
      noto-fonts-cjk-serif
      noto-fonts-color-emoji
      font-awesome

      # Document authoring. Typst embeds New Computer Modern, Libertine and
      # DejaVu Sans Mono internally, so it renders without any of these — they
      # matter for documents that deviate from the defaults, and for typix
      # builds, which are hermetic and only see the font paths handed to them.
      newcomputermodern
      libertinus          # Libertinus Serif/Sans/Math
      stix-two            # STIX Two Math
      lmodern             # Latin Modern, for TeX-alike output in Typst
      dejavu_fonts
      liberation_ttf
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
