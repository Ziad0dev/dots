{
  config,
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

    modelsDir = "/var/lib/ollama";

    loadModels = [
      "qwen3.5:9b"
      "qwen2.5-coder:14b"
      "qwen2.5-coder:7b"
      "devstral-small-2:24b"
    ];

    environmentVariables = {

      OLLAMA_MAX_LOADED_MODELS = "1";

      # starts at boot but holds no VRAM until a model is requested; pi's
      # ollama-unload extension frees it on exit, KEEP_ALIVE covers crashes
      OLLAMA_KEEP_ALIVE = "5m";

      OLLAMA_FLASH_ATTENTION = "1";

      OLLAMA_KV_CACHE_TYPE = "q8_0";

      # Repository agents need more than the old 16k default. 32k fits the
      # 9B/14B models on the 16 GB card; larger models can offload KV cache.
      OLLAMA_CONTEXT_LENGTH = "131072";
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/ollama 0750 ollama ollama -"
  ];

  users.users.ollama.extraGroups = [
    "video"
    "render"
  ];

  environment.shellAliases = {
    gpu-check = "systemctl list-units 'llama-*' --state=running --no-legend; ollama ps";
    # stopping the units leaves Ollama's loaded models in VRAM; unload them too
    gpu-free = "systemctl stop 'llama-*'; ollama ps | awk 'NR > 1 { print $1 }' | xargs -r -n1 ollama stop; ollama ps";
  };
}
