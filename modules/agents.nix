{ config, lib, pkgs, ... }:

let
  cfg = config.programs.agents;
in
{
  options.programs.agents = {
    enable = lib.mkEnableOption "herdr agent stack";
    herdr.package = lib.mkPackageOption pkgs "herdr" { };
    codex.enable = lib.mkEnableOption "Codex CLI";
    pi.enable = lib.mkEnableOption "Pi coding agent (pi.dev)";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      cfg.herdr.package
    ]
    ++ lib.optional cfg.codex.enable pkgs.codex
    ++ lib.optional cfg.pi.enable pkgs.pi-coding-agent;

    programs.tmux = {
      enable = true;
      historyLimit = 50000;
      extraConfig = ''
        set -g mouse on
      '';
    };
  };
}
