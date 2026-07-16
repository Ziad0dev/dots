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
  # HM `wayland.windowManager.hyprland` is intentionally NOT used — it would
  # collide with the symlinked dots/hypr directory. Hyprland is enabled
  # system-wide in configuration.nix; the config in dots/hypr/hyprland.conf
  # is read directly.

  # ── Shell ──────────────────────────────────────────────────────────────
  # bash kept enabled for the rare script that needs it; fish is the login shell.
  programs.bash.enable = true;

  programs.direnv = {
    enable            = true;
    nix-direnv.enable = true;
    # programs.direnv auto-hooks fish, bash, and zsh when they're enabled.
  };

  programs.fish = {
    enable = true;

    # Regular aliases — work like bash aliases.
    shellAliases = {
      ll     = "ls -l";
      la     = "ls -la";
      edit   = "sudo -e";
    };

    # Fish abbreviations — expand inline when you hit space, so you SEE the
    # full command before running it. Great for things you want to be
    # deliberate about. Try them; you'll see the difference.
    shellAbbrs = {
      update  = "sudo nixos-rebuild switch --flake /home/${username}/dots#nixos";
      flakeup = "nix flake update --flake /home/${username}/dots";
      g       = "git";
      gst     = "git status";
      gco     = "git checkout";
      gp      = "git push";
      gl      = "git pull";
    };

    interactiveShellInit = 
      fish_vi_key_bindings
  };

  # ── Dotfile Symlinks (live — point at ~/dots, no rebuild on edits) ─────
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
    ".config/mpd"       = { source = link "mpd"; };
    ".config/mpdscribble" = { source = link "mpdscribble"; };
  };

  # ── Qt / GTK ───────────────────────────────────────────────────────────
  qt = {
    enable             = true;
    platformTheme.name = "kde";
    style.name         = "breeze";
  };

  imports = [
    inputs.nix-index-database.homeModules.default
    inputs.nixcord.homeModules.nixcord
  ];

  # ── Discord / Vencord ──────────────────────────────────────────────────
  programs.nixcord = {
    enable = true;
    vesktop.enable = true;        # Wayland-native client; screenshare works on Hyprland

    config = {
      frameless = true;
      plugins = {
        # confirmed from your setup history
        screenShareAudio.enable = true;   # your Hyprland stream-audio fix
        messageLogger.enable = true;

        # standard QoL set — prune what you don't want
        alwaysTrust.enable = true;
        betterFolders.enable = true;
        callTimer.enable = true;
        clearURLs.enable = true;
        fakeNitro.enable = true;
        fixSpotifyEmbeds.enable = true;
        imageZoom.enable = true;
        noF1.enable = true;
        noTypingAnimation.enable = true;
        silentTyping.enable = true;
        volumeBooster.enable = true;
        webScreenShareFixes.enable = true;
        youtubeAdblock.enable = true;
      };
    };
  };


  # ── Clipboard ──────────────────────────────────────────────────────────
  home.packages = with pkgs; [
    cliphist
    wl-clipboard
  ];
  services.cliphist.enable = true;

  # ── Hyprland autostart reminder ────────────────────────────────────────
  # Daemons that need configs from dots are started from
  # ~/dots/hypr/hyprland.conf via `exec-once`, e.g.:
  #   exec-once = dunst
  #   exec-once = gammastep
  #   exec-once = waybar
  #   exec-once = dbus-update-activation-environment --systemd --all
  #   exec-once = systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE
}
