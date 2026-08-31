{
  config,
  lib,
  pkgs,
  ...
}:

{
  services.ollama = {
    enable = true;

    package = pkgs.ollama-vulkan;

    user = "ollama";
    group = "ollama";

    host = "127.0.0.1";
    port = 11434;

    modelsDir = "/data/models/ollama";

    environmentVariables = {

      OLLAMA_MAX_LOADED_MODELS = "1";

      OLLAMA_KEEP_ALIVE = "5m";

      OLLAMA_FLASH_ATTENTION = "1";

      OLLAMA_KV_CACHE_TYPE = "q8_0";

      OLLAMA_CONTEXT_LENGTH = "16384";
    };
  };

  systemd.tmpfiles.rules = [
    "d /data/models/ollama 0750 ollama ollama -"
  ];

  systemd.services.ollama = {
    wantedBy = lib.mkForce [ ];
    unitConfig.RequiresMountsFor = "/data";
    after = [ "data.mount" ];
  };

  users.users.ollama.extraGroups = [
    "video"
    "render"
  ];

  environment.shellAliases = {
    gpu-check = "systemctl list-units 'llama-*' --state=running --no-legend; ollama ps";
    gpu-free = "systemctl stop 'llama-*'; ollama ps";
  };
}
