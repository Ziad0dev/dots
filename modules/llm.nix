{
  config,
  lib,
  pkgs,
  username,
  ...
}:

let
  modelDir = "/data/models";
  vulkan = pkgs.llama-cpp-vulkan;

  freeGpu = pkgs.writeShellScript "free-gpu" ''
    set -u
    api=http://127.0.0.1:11434
    ${pkgs.curl}/bin/curl -sf --max-time 2 "$api/api/ps" \
      | ${pkgs.jq}/bin/jq -r '.models[]?.name' 2>/dev/null \
      | while read -r m; do
          [ -n "$m" ] || continue
          ${pkgs.curl}/bin/curl -sf --max-time 5 "$api/api/generate" \
            -d "{\"model\":\"$m\",\"keep_alive\":0}" >/dev/null || true
        done
    exit 0
  '';

  gpuUnit = self: {
    after = [ "data.mount" ];
    conflicts = lib.filter (n: n != self) [
      "llama-cpp.service"
      "llama-sec.service"
      "llama-agent.service"
      "llama-gemma.service"
      "llama-coder.service"
      "llama-fim.service"
    ];
    unitConfig = {
      RequiresMountsFor = "/data";
      StartLimitBurst = 5;
    };
    wantedBy = lib.mkForce [ ];
    serviceConfig.ExecStartPre = freeGpu;
  };
in
{

  services.llama-cpp = {
    enable = true;
    package = vulkan;
    settings = {
      model = "${modelDir}/Qwen3.5-9B-Q6_K.gguf";
      host = "127.0.0.1";
      port = 8080;
      ctx-size = 16384;
      n-gpu-layers = 99;
      flash-attn = "on";
    };
  };

  systemd.services.llama-cpp = gpuUnit "llama-cpp.service";

  systemd.services.llama-sec = lib.recursiveUpdate (gpuUnit "llama-sec.service") {
    description = "WhiteRabbitNeo V3-7B (security)";
    serviceConfig.ExecStart = ''
      ${vulkan}/bin/llama-server \
        -m ${modelDir}/WhiteRabbitNeo_WhiteRabbitNeo-V3-7B-Q5_K_M.gguf \
        --host 127.0.0.1 --port 8080 \
        -c 16384 -ngl 99 --flash-attn on --jinja
    '';
  };

  systemd.services.llama-agent = lib.recursiveUpdate (gpuUnit "llama-agent.service") {
    description = "Qwen2.5-Coder-14B (agent / tool-calling)";
    serviceConfig.ExecStart = ''
      ${vulkan}/bin/llama-server \
        -m ${modelDir}/Qwen2.5-Coder-14B-Instruct-Q4_K_M.gguf \
        --host 127.0.0.1 --port 8080 \
        -c 16384 -ngl 99 --flash-attn on --jinja
    '';
  };

  systemd.services.llama-gemma = lib.recursiveUpdate (gpuUnit "llama-gemma.service") {
    description = "Gemma 4 12B Unified (general / vision / audio)";
    serviceConfig.ExecStart = ''
      ${vulkan}/bin/llama-server \
        -m ${modelDir}/gemma-4-12B-it-Q4_K_M.gguf \
        --host 127.0.0.1 --port 8080 \
        -c 16384 -ngl 99 --flash-attn on --jinja \
        --temp 1.0 --top-p 0.95 --top-k 64
    '';
  };

  systemd.services.llama-coder = lib.recursiveUpdate (gpuUnit "llama-coder.service") {
    description = "Gemma 4 26B A4B MoE (coding / agentic)";
    serviceConfig.ExecStart = ''
      ${vulkan}/bin/llama-server \
        -m ${modelDir}/gemma-4-26B-A4B-it-Q4_K_M.gguf \
        --host 127.0.0.1 --port 8080 \
        -c 16384 -ngl 99 --n-cpu-moe 10 --flash-attn on --jinja \
        --temp 1.0 --top-p 0.95 --top-k 64 \
        --cache-type-k q8_0 --cache-type-v q8_0
    '';
  };

  systemd.services.llama-fim = lib.recursiveUpdate (gpuUnit "llama-fim.service") {
    description = "Qwen2.5-Coder-3B FIM (llama.vim)";
    serviceConfig.ExecStart = ''
      ${vulkan}/bin/llama-server \
        -m ${modelDir}/qwen2.5-coder-3b-q8_0.gguf \
        --host 127.0.0.1 --port 8012 \
        -c 8192
    '';
  };

  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units"
          && subject.local && subject.active && subject.user == "ziad0dev") {
        var u = action.lookup("unit");
        if (u == "llama-cpp.service" || u == "llama-sec.service"
            || u == "llama-agent.service" || u == "llama-gemma.service"
            || u == "llama-coder.service" || u == "llama-fim.service"
            || u == "ollama.service") {
          return polkit.Result.YES;
        }
      }
    });
  '';

  systemd.tmpfiles.rules = [
    "d /data/models 0755 ${username} users -"
  ];

  environment.systemPackages = with pkgs; [
    nvtopPackages.nvidia

    vulkan
  ];
}
