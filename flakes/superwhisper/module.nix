# Home Manager module: the package, its launcher entry and the
# superwhisper.service user unit that upstream install.sh would write into
# ~/.config/systemd/user. The update timer is left out (the package refuses
# `update`); settings, models and history stay in the XDG dirs as upstream.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.superwhisper;
  bin = lib.getExe cfg.package;

  # Superwhisper only writes into a bindings file that exists (it takes the
  # file for the config's entry point), so start it empty.
  prepare = pkgs.writeShellApplication {
    name = "superwhisper-prepare";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      f=${lib.escapeShellArg cfg.hyprlandBindingsFile}
      mkdir -p -- "$(dirname -- "$f")"
      [ -e "$f" ] || : >"$f"
    '';
  };

  # The daemon rewrites its bindings when they change, but never writes the
  # first ones; upstream install.sh runs `shortcuts apply` once for that.
  # Once only (the stamp), so shortcuts cleared in settings stay cleared.
  applyShortcuts = pkgs.writeShellApplication {
    name = "superwhisper-apply-shortcuts";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      cfg.package
    ];
    text = ''
      f=${lib.escapeShellArg cfg.hyprlandBindingsFile}
      stamp="$(dirname -- "$f")/.shortcuts-applied"
      [ -e "$stamp" ] && exit 0
      if ! grep -qF -- '-- Superwhisper managed shortcuts BEGIN' "$f" 2>/dev/null; then
        for _ in $(seq 1 40); do
          superwhisper status >/dev/null 2>&1 && break
          sleep 0.5
        done
        superwhisper shortcuts apply >/dev/null
      fi
      : >"$stamp"
    '';
  };
in
{
  options.services.superwhisper = {
    enable = lib.mkEnableOption "Superwhisper dictation";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ./package.nix { };
      defaultText = lib.literalExpression "pkgs.callPackage ./package.nix { }";
      description = "The Superwhisper package (unfree).";
    };

    hyprlandBindingsFile = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.stateHome}/superwhisper/hyprland.lua";
      defaultText = lib.literalExpression ''"''${config.xdg.stateHome}/superwhisper/hyprland.lua"'';
      description = ''
        Where Superwhisper writes its Hyprland shortcuts. Upstream edits
        ~/.config/hypr/bindings.lua, which is read-only when Home Manager
        manages the Hyprland config, so it writes here instead. Load it from
        the Lua config with `pcall(dofile, "<this path>")`, and export
        SUPERWHISPER_HYPR_BINDINGS to the compositor (`hl.env`) so apps it
        starts write here too; this repo's 65-superwhisper.lua does both.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    # The CLI (`superwhisper shortcuts set` in a terminal) writes the
    # bindings too, not only the daemon.
    home.sessionVariables.SUPERWHISPER_HYPR_BINDINGS = cfg.hyprlandBindingsFile;

    systemd.user.services.superwhisper = {
      Unit = {
        Description = "Superwhisper dictation";
        After = [
          "graphical-session.target"
          "pipewire.service"
        ];
        PartOf = [ "graphical-session.target" ];
        # Without a compositor it exits at once; don't let it loop.
        ConditionEnvironment = "WAYLAND_DISPLAY";
        StartLimitIntervalSec = 300;
        StartLimitBurst = 5;
      };
      Service = {
        Type = "simple";
        Environment = [ "SUPERWHISPER_HYPR_BINDINGS=${cfg.hyprlandBindingsFile}" ];
        ExecStartPre = lib.getExe prepare;
        ExecStart = "${bin} daemon";
        # Upstream's: give back the playback it ducked and the shortcuts it
        # held. At logout the compositor may be gone already; that's no failure.
        ExecStopPost = [
          "-${bin} playback-restore"
          "-${bin} desktop-release"
        ];
        Restart = "on-failure";
        RestartSec = 2;
        KillMode = "control-group";
        TimeoutStopSec = 15;
        UMask = "0077";
        # lib/hardening.nix minus what this breaks: ProtectHome (settings,
        # models, ~/.config/wireplumber), PrivateDevices (/dev/dri for Vulkan),
        # PrivateTmp/ProtectSystem (it starts systemd-run scopes and talks to
        # the compositor and PipeWire in /run/user), and the Protect*/
        # CapabilityBoundingSet ones, which need privileges a user manager
        # doesn't have. AF_INET* is for Cloud mode.
        NoNewPrivileges = true;
        LockPersonality = true;
        RestrictNamespaces = true;
        SystemCallArchitectures = "native";
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
          "AF_NETLINK"
        ];
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    # Separate from the daemon's unit: `superwhisper status` starts
    # superwhisper.service when it isn't up, which would wait on itself from
    # an ExecStartPost.
    systemd.user.services.superwhisper-shortcuts = {
      Unit = {
        Description = "Write Superwhisper's first Hyprland shortcuts";
        After = [ "superwhisper.service" ];
        Requires = [ "superwhisper.service" ];
        ConditionEnvironment = "HYPRLAND_INSTANCE_SIGNATURE";
      };
      Service = {
        Type = "oneshot";
        Environment = [ "SUPERWHISPER_HYPR_BINDINGS=${cfg.hyprlandBindingsFile}" ];
        ExecStart = lib.getExe applyShortcuts;
        TimeoutStartSec = 60;
        NoNewPrivileges = true;
        LockPersonality = true;
        RestrictNamespaces = true;
        SystemCallArchitectures = "native";
        RestrictAddressFamilies = [ "AF_UNIX" ];
      };
      Install.WantedBy = [ "superwhisper.service" ];
    };
  };
}
