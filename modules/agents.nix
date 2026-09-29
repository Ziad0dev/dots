{ config, lib, pkgs, ... }:

let
  cfg = config.programs.agents;

  buildTools = lib.makeBinPath [ pkgs.python3 pkgs.gnumake pkgs.gcc ];

  openrigBin = name: pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = [ cfg.nodejs pkgs.tmux pkgs.git ];
    text = ''
      prefix="''${XDG_DATA_HOME:-$HOME/.local/share}/openrig/${cfg.openrig.version}"
      if [ ! -x "$prefix/bin/${name}" ]; then
        PATH="${buildTools}:$PATH" npm install --global --prefix "$prefix" "@openrig/cli@${cfg.openrig.version}" >&2
      fi
      exec "$prefix/bin/${name}" "$@"
    '';
  };
in
{
  options.programs.agents = {
    enable = lib.mkEnableOption "herdr + OpenRig agent stack";
    nodejs = lib.mkPackageOption pkgs "nodejs_22" { };
    herdr.package = lib.mkPackageOption pkgs "herdr" { };
    openrig.version = lib.mkOption {
      type = lib.types.str;
      default = "0.5.17";
    };
    claude.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    codex.enable = lib.mkEnableOption "Codex CLI";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      cfg.herdr.package
      cfg.nodejs
      (openrigBin "rig")
      (openrigBin "openrig-tui")
    ]
    ++ lib.optional cfg.claude.enable pkgs.claude-code
    ++ lib.optional cfg.codex.enable pkgs.codex;

    programs.tmux = {
      enable = true;
      historyLimit = 50000;
      extraConfig = ''
        set -g mouse on
      '';
    };
  };
}
