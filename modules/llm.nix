{ pkgs, lib, username, ... }:

{

  services.llama-cpp = {
    enable  = true;
    package = pkgs.llama-cpp-vulkan;
    openFirewall = false;

    settings = {
      host  = "127.0.0.1";
      port  = 8080;
      model = "/data/models/Qwen3.5-9B-Q6_K.gguf";

      n-gpu-layers = 99;
      ctx-size     = 65536;
      cache-type-k = "q8_0";
      cache-type-v = "q8_0";
      flash-attn   = "auto";

      threads      = 6;

      batch-size   = 2048;
      ubatch-size  = 512;
      jinja        = true;
    };
  };

  systemd.services.llama-cpp.unitConfig.RequiresMountsFor = "/data";

  systemd.services.llama-cpp.wantedBy = lib.mkForce [ ];

  systemd.services.llama-fim = {
    description = "llama-server FIM (Qwen2.5-Coder-3B) for llama.vim on :8012";
    unitConfig.RequiresMountsFor = "/data";
    serviceConfig = {
      DynamicUser = true;
      Restart = "on-failure";
      ExecStart = lib.concatStringsSep " " [
        "${pkgs.llama-cpp-vulkan}/bin/llama-server"
        "-m /data/models/qwen2.5-coder-3b-q8_0.gguf"
        "--host 127.0.0.1"
        "--port 8012"
        "--n-gpu-layers 99"
        "--ctx-size 0"
        "--cache-reuse 256"
        "--batch-size 1024"
        "--ubatch-size 1024"
        "--defrag-thold 0.1"
        "--flash-attn auto"
        "--cache-type-k q8_0"
        "--cache-type-v q8_0"
        "--threads 6"
      ];
    };
  };

  systemd.tmpfiles.rules = [
    "d /data/models 0755 ${username} users -"
  ];

  environment.systemPackages = with pkgs; [
    nvtopPackages.nvidia

    llama-cpp-vulkan
  ];

}
