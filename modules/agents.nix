{ config, lib, pkgs, inputs, system, ... }:

let
  cfg = config.programs.agents;
in
{
  options.programs.agents = {
    enable = lib.mkEnableOption "herdr agent stack";
    herdr.package = lib.mkPackageOption pkgs "herdr" { };
    codex.enable = lib.mkEnableOption "Codex CLI";
    pi.enable = lib.mkEnableOption "Pi coding agent (pi.dev)";
    opencode.enable = lib.mkEnableOption "OpenCode";
    hermes.enable = lib.mkEnableOption "Hermes Agent (Nous Research)";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      cfg.herdr.package
    ]
    ++ lib.optional cfg.codex.enable pkgs.codex
    ++ lib.optional cfg.pi.enable pkgs.pi-coding-agent
    ++ lib.optional cfg.opencode.enable pkgs.opencode
    # upstream flake's default output: the CLI with every provider SDK bundled
    ++ lib.optional cfg.hermes.enable inputs.hermes-agent.packages.${system}.default;

    programs.tmux = {
      enable = true;
      historyLimit = 50000;
      extraConfig = ''
        set -g mouse on
      '';
    };
  };
}
