{ config, pkgs, inputs, username, hostname, system, ... }:


{
  imports = [
    # Hyprland NixOS module from the flake for the most up-to-date version
    inputs.hyprland.nixosModules.default
  ];

  # ── Boot ──────────────────────────────────────────────────────────────────
  boot.loader.grub = {
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

};

  # ── Networking ────────────────────────────────────────────────────────────
  networking.hostName            = hostname;
  networking.networkmanager.enable = true;
  virtualisation.vmware.guest.enable = true;
  # ── Locale / Time ─────────────────────────────────────────────────────────
  time.timeZone      = "America/New_York";
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

  # ── Display / Desktop ─────────────────────────────────────────────────────
  # X server (required by SDDM even in Wayland mode)
  services.xserver = {
    enable      = true;
    xkb.layout  = "us";
  };

  # SDDM — shared greeter for both KDE and Hyprland sessions
  services.displayManager.sddm = {
    enable         = true;
    wayland.enable = true;
    theme          = "breeze"; # ships with plasma-workspace
  };

  # KDE Plasma 6
  services.desktopManager.plasma6.enable = true;

  # Hyprland (from flake input — keeps it in sync with home-manager module)
  programs.hyprland = {
    enable         = true;
    package        = inputs.hyprland.packages.${system}.hyprland;
    xwayland.enable = true;
  };

  # ── XDG Portals ───────────────────────────────────────────────────────────
  # KDE provides xdg-desktop-portal-kde; Hyprland needs its own portal.
  # lxqt-portals.conf (or the portal's own config) handles per-session routing.
  xdg.portal = {
    enable = true;
    config = {
      common.default           = [ "kde" ];
      hyprland.default         = [ "hyprland" "kde" ];
      hyprland."org.freedesktop.impl.portal.Secret" = [ "kde" ];
    };
  };

  # ── System Services ───────────────────────────────────────────────────────
  services.dbus.enable       = true;
  security.polkit.enable     = true;
  services.printing.enable   = true;
  services.gvfs.enable       = true;
  services.udisks2.enable    = true;

  # Bluetooth
  hardware.bluetooth = {
    enable      = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;

  # ── Audio (PipeWire) ──────────────────────────────────────────────────────
  # sound.enable and hardware.pulseaudio are mutually exclusive with PipeWire.
  security.rtkit.enable = true;
  services.pipewire = {
    enable            = true;
    alsa.enable       = true;
    alsa.support32Bit = true;
    pulse.enable      = true;
    jack.enable       = true;
    wireplumber.enable = true;
  };

  # ── Virtualisation ────────────────────────────────────────────────────────
  virtualisation.docker = {
    enable           = true;
    enableOnBoot     = true;
  };

  # ── Users ─────────────────────────────────────────────────────────────────
  users.users.${username} = {
    isNormalUser = true;
    description  = username;
    extraGroups  = [ "wheel" "networkmanager" "docker" "audio" "video" "input" ];
    shell        = pkgs.bash;
  };

  # ── Nix Settings ──────────────────────────────────────────────────────────
  nixpkgs.config.allowUnfree = true;

  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store   = true;
      # Hyprland Cachix — speeds up Hyprland builds
      substituters          = [
        "https://cache.nixos.org"
        "https://hyprland.cachix.org"
      ];
      trusted-public-keys   = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      ];
    };
    gc = {
      automatic = true;
      dates     = "weekly";
      options   = "--delete-older-than 14d";
    };
  };

  # ── System Packages ───────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    # Browser
    inputs.zen-browser.packages.${system}.default

    # Core utils
    git gh curl wget jq tree unzip zip
    htop btop ripgrep fd fzf
    gcc gnumake pkg-config podman

    # Runtimes / languages
    nodejs_22
    python313
    python313Packages.pip
    python313Packages.virtualenv
    go
    rustup
    lua
    luarocks

    # Editors
    neovim
    vscode

    # Shell / env
    direnv
    nix-direnv

    # Hyprland / Wayland stack
    waybar
    dunst
    rofi
    ghostty
    wl-clipboard
    grim
    slurp
    swaylock-effects   # maintained fork of swaylock
    playerctl
    pamixer
    pavucontrol
    brightnessctl
    networkmanagerapplet
    libnotify
    hyprpaper
    hypridle
    hyprlock
    # Polkit agent — KDE's agent works in both sessions
    kdePackages.polkit-kde-agent-1

    # File managers / terminal tools
    ranger
    yazi
    broot
    flameshot
    gammastep
    rmpc

    # KDE integration helpers (useful even when using Hyprland)
    kdePackages.dolphin
    kdePackages.ark
    kdePackages.kate
    kdePackages.kwallet
    kdePackages.kwalletmanager
    kdePackages.ksystemlog
  ];

  # ── Fonts ─────────────────────────────────────────────────────────────────
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

  # ── Misc Programs ─────────────────────────────────────────────────────────
  programs.git.enable    = true;
  programs.nix-ld.enable = true;         # run unpatched dynamic binaries
  programs.dconf.enable  = true;         # required by some GTK apps under KDE/Hyprland

  programs.bash.interactiveShellInit = ''
    eval "$(direnv hook bash)"
  '';

  system.stateVersion = "24.05";
}
