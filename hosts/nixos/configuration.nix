{
  config,
  pkgs,
  inputs,
  username,
  hostname,
  system,
  ...
}:

let
  fixZstdRefs = import ../../lib/nvidia-zstd-refs.nix { inherit pkgs; };
in
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

  dots.sddm.theme = "kanagawa";
  networking.hostName = hostname;
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Stockholm";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  services.xserver = {
    enable = true;
    xkb.layout = "us";
  };

  zramSwap = {
    enable = true;
    memoryPercent = 50;

  };
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    nvidiaPersistenced = true;
    package = fixZstdRefs pkgs.nvidia_cachyos;
  };
  services.prowlarr = {
    enable = true;
    openFirewall = false;
  };
  services.flaresolverr = {
    enable = true;
    openFirewall = false;
  };

  systemd.services.flaresolverr.serviceConfig = {
    NoNewPrivileges = true;
    PrivateTmp = true;
    ProtectHome = true;
    ProtectSystem = "strict";
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectKernelLogs = true;
    ProtectControlGroups = true;
    ProtectClock = true;
    ProtectHostname = true;
    ProtectProc = "invisible";
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
    LockPersonality = true;
    SystemCallArchitectures = "native";
    RestrictAddressFamilies = [
      "AF_INET"
      "AF_INET6"
      "AF_UNIX"
      "AF_NETLINK"
    ];
  };

  programs.coolercontrol.enable = true;

  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${system}.hyprland;
    portalPackage = inputs.hyprland.packages.${system}.xdg-desktop-portal-hyprland;
    xwayland.enable = true;
  };

  xdg.portal = {
    enable = true;
    # Do NOT put xdg-desktop-portal-hyprland here — programs.hyprland already provides it
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];
    config = {
      common.default = [
        "hyprland"
        "gtk"
      ];
      hyprland = {
        default = [
          "hyprland"
          "gtk"
        ];
        "org.freedesktop.impl.portal.ScreenCast" = [ "hyprland" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "hyprland" ];
        "org.freedesktop.impl.portal.Secret" = [ "gtk" ];
      };
    };
  };

  services.dbus.enable = true;
  security.polkit.enable = true;

  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (subject.local && subject.active &&
          (action.id == "org.freedesktop.udisks2.filesystem-mount" ||
           action.id == "org.freedesktop.udisks2.filesystem-unmount-others" ||
           action.id == "org.freedesktop.udisks2.eject-media" ||
           action.id == "org.freedesktop.udisks2.power-off-drive")) {
        return polkit.Result.YES;
      }
    });
  '';
  services.printing.enable = true;
  services.gvfs.enable = true;
  services.udisks2.enable = true;

  services.usbmuxd.enable = true;

  hardware.bluetooth = {
    enable = false;
    powerOnBoot = false;
  };
  services.blueman.enable = false;

  virtualisation.docker = {
    enable = true;
    enableOnBoot = false;
    rootless = {
      enable = true;
      setSocketVariable = true;
    };
  };

  users.users.${username} = {
    isNormalUser = true;
    description = username;

    uid = 1001;
    extraGroups = [
      "wheel"
      "networkmanager"
      "audio"
      "video"
      "input"
      "libvirtd"
    ];
    shell = pkgs.fish;
  };
  programs.fish.enable = true;

  nixpkgs.overlays = [
    inputs.zig-overlay.overlays.default
    inputs.obsidian-extensions.overlays.default
  ];
  nixpkgs.config.allowUnfree = true;

  nix.optimise.automatic = true;

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      substituters = [
        "https://cache.nixos.org"
        "https://hyprland.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      ];
    };

  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
    QT_QPA_PLATFORM = "wayland;xcb";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    _JAVA_AWT_WM_NONREPARENTING = "1";
  };

  environment.systemPackages = [
    inputs.hyprland-preview-share-picker.packages.${system}.default
  ]
  ++ (with pkgs; [
    git
    curl
    wget
    jq
    tree
    unzip
    zip
    neovim
    # Diagnostics / hardware
    htop
    btop
    lm_sensors
    usbutils
    gparted
    exfatprogs
    # Pairs with services.usbmuxd
    libimobiledevice
    ifuse
    hyprpolkitagent
    # Pairs with programs.coolercontrol
    coolercontrol.coolercontrol-gui
    inputs.dvr-patched.packages.${system}.default
    # Container runtime
    podman
    kdePackages.ark
    kdePackages.qt6ct
  ]);

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

      newcomputermodern
      libertinus
      stix-two
      lmodern
      dejavu_fonts
      liberation_ttf
    ];
    fontconfig.defaultFonts = {
      monospace = [ "FiraCode Nerd Font Mono" ];
      sansSerif = [ "Noto Sans" ];
      serif = [ "Noto Serif" ];
      emoji = [ "Noto Color Emoji" ];
    };
  };

  programs.git.enable = true;
  programs.dconf.enable = true;

  system.stateVersion = "24.05";
}
