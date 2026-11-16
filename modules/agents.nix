{
  config,
  lib,
  inputs,
  system,
  ...
}:

let
  cfg = config.programs.agents;
  # numtide/llm-agents.nix: updated daily, prebuilt on cache.numtide.com
  agentPkgs = inputs.llm-agents.packages.${system};
in
{
  options.programs.agents = {
    enable = lib.mkEnableOption "herdr agent stack";
    herdr.package = lib.mkOption {
      type = lib.types.package;
      default = agentPkgs.herdr;
      defaultText = lib.literalExpression "inputs.llm-agents.packages.\${system}.herdr";
      description = "The herdr package to use.";
    };
    pi.enable = lib.mkEnableOption "Pi coding agent (pi.dev)";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      cfg.herdr.package
    ]
    ++ lib.optional cfg.pi.enable agentPkgs.pi;

    nix.settings = {
      extra-substituters = [ "https://cache.numtide.com" ];
      extra-trusted-public-keys = [
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      ];
    };

    programs.tmux = {
      enable = true;
      historyLimit = 50000;
      extraConfig = ''
        set -g mouse on
      '';
    };
  };
}
