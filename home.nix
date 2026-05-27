{ config, pkgs, lib, inputs, username, system, ... }:

let
  # Local clone of github:Ziad0dev/dots — edits here are live, no rebuild needed.
  # Clone once with:
  #   git clone https://github.com/Ziad0dev/dots ~/dots
  dotsPath = "/home/${username}/dots";

  # Helper: live symlink into the source tree (instead of a copy into /nix/store).
  link = sub: config.lib.file.mkOutOfStoreSymlink "${dotsPath}/${sub}";
in
{
  home.username      = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion  = "24.05";

  programs.home-manager.enable = true;

  # ── Session Variables ──────────────────────────────────────────────────
  home.sessionVariables = {
    EDITOR   = "nvim";
    VISUAL   = "nvim";
    TERMINAL = "ghostty";
    BROWSER  = "zen";
    MOZ_ENABLE_WAYLAND = "1";
    NIXOS_OZONE_WL     = "1";
    QT_QPA_PLATFORM    = "wayland;xcb";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    SDL_VIDEODRIVER    = "wayland";
    _JAVA_AWT_WM_NONREPARENTING = "1";
  };

  # ── Hyprland ───────────────────────────────────────────────────────────
  # NOTE: the HM `wayland.windowManager.hyprland` module is intentionally NOT
  # used here, because it wants to write ~/.config/hypr/hyprland.conf and
  # that collides with the symlinked dots/hypr directory below.
  #
  # Hyprland is enabled system-wide in configuration.nix
  # (`programs.hyprland.enable = true`) and SDDM offers it as a session.
  # The config in dots/hypr/hyprland.conf is read directly.

  # ── Shell ──────────────────────────────────────────────────────────────
  programs.bash.enable = true;

  programs.direnv = {
    enable            = true;
    nix-direnv.enable = true;
  };

  # ── Dotfile Symlinks (live — point at ~/dots, no rebuild on edits) ─────
  # Any HM module that writes a file inside one of these dirs WILL fail
  # the build. Do not enable services.dunst, services.gammastep,
  # wayland.windowManager.hyprland, programs.waybar, etc.
  home.file = {
    ".config/hypr"      = { source = link "hypr"; };
    ".config/waybar"    = { source = link "waybar"; };
    ".config/dunst"     = { source = link "dunst"; };
    ".config/rofi"      = { source = link "rofi"; };
    ".config/ghostty"   = { source = link "ghostty"; };
    ".config/nvim"      = { source = link "nvim"; };
    ".config/flameshot" = { source = link "flameshot"; };
    ".config/gammastep" = { source = link "gammastep"; };
    ".config/ranger"    = { source = link "ranger"; };
    ".config/yazi"      = { source = link "yazi"; };
    ".config/broot"     = { source = link "broot"; };
    ".config/rmpc"      = { source = link "rmpc"; };
  };

  # ── Qt / GTK ───────────────────────────────────────────────────────────
  qt = {
    enable             = true;
    platformTheme.name = "kde";
    style.name         = "breeze";
  };

  gtk = {
    enable = true;
    gtk4.theme = config.gtk.theme;  # silence default-change warning
    theme = {
      name    = "Breeze";
      package = pkgs.kdePackages.breeze-gtk;
    };
    iconTheme = {
      name    = "breeze";
      package = pkgs.kdePackages.breeze-icons;
    };
    cursorTheme = {
      name    = "breeze_cursors";
      package = pkgs.kdePackages.breeze;
      size    = 24;
    };
  };

  # ── Clipboard ──────────────────────────────────────────────────────────
  # cliphist has no config file, so its HM service is safe to use.
  home.packages = with pkgs; [
    cliphist
    wl-clipboard
  ];
  services.cliphist.enable = true;
  # git 
  programs.git.enable = true;
  # zsh  
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      ll = "ls -l";
      edit = "sudo -e";
      update = "sudo nixos-rebuild switch";
    };

    history.size = 10000;
    history.ignoreAllDups = true;
    history.path = "$HOME/.zsh_history";
    history.ignorePatterns = ["rm *" "pkill *" "cp *"];
  };
  # ── Notifications / Gammastep / Hyprland autostart ────────────────────
  # All daemons that need configs from dots are started from
  # ~/dots/hypr/hyprland.conf via `exec-once` lines. Recommended additions:
  #
  #   exec-once = dunst
  #   exec-once = gammastep
  #   exec-once = waybar
  #   exec-once = dbus-update-activation-environment --systemd --all
  #   exec-once = systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE
}
