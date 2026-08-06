# modules/llm.nix — local LLM inference (llama.cpp + Vulkan on the RTX 3060)
#
# NOTE: your nixpkgs pin uses the newer services.llama-cpp interface — a
# freeform `settings` attrset (model/host/port live inside it; extraFlags is
# gone). Each settings key maps to a `--key value` llama-server flag. If you diff
# against your real file, that's the block that changed.
#
# Invariant: only ONE model holds the 3060 at a time (12 GB VRAM). Every unit
# below Conflicts with the others, and none autostart — start the one you want:
#
#   systemctl start llama-cpp     # Qwen3.5-9B      general / coding chat  :8080
#   systemctl start llama-sec     # WhiteRabbitNeo  security Q&A + agent   :8080
#   systemctl start llama-agent   # Qwen2.5-Coder   14B tool-calling loop  :8080
#   systemctl start llama-fim     # Qwen2.5-Coder   3B FIM for llama.vim   :8012
#
# All four expose an OpenAI-compatible API, so your chat client and any ReAct
# harness just point at the port of whichever is running.

{ config, lib, pkgs, ... }:

let
  modelDir = "/data/models";
  vulkan   = pkgs.llama-cpp-vulkan;

  # Shared unit conventions for every model server. Pass the unit's own name so
  # it's excluded from its Conflicts= set.
  gpuUnit = self: {
    after     = [ "data.mount" ];
    conflicts = lib.filter (n: n != self) [
      "llama-cpp.service"
      "llama-sec.service"
      "llama-agent.service"
      "llama-fim.service"
    ];
    unitConfig = {
      RequiresMountsFor = "/data";
      StartLimitBurst   = 5;      # raise if a flapping start trips the limiter
    };
    wantedBy = lib.mkForce [ ];   # manual start only — never autostart at boot
  };
in
{
  #############################################################################
  # Main chat / coding model — Qwen3.5-9B Q6_K (~7.5 GB), via the upstream
  # module. New interface: everything goes under `settings`. Keys are the
  # llama-server long-flag names; the module renders each as `--key value`.
  #############################################################################
  services.llama-cpp = {
    enable  = true;
    package = vulkan;
    settings = {
      model        = "${modelDir}/Qwen3.5-9B-Q6_K.gguf";   # <-- match your real filename
      host         = "127.0.0.1";
      port         = 8080;
      ctx-size     = 16384;
      n-gpu-layers = 99;
      flash-attn   = "on";
    };
  };

  # Overlay our conventions onto the module-generated llama-cpp.service.
  # (mkForce on wantedBy is required — the module sets multi-user.target.)
  systemd.services.llama-cpp = gpuUnit "llama-cpp.service";

  #############################################################################
  # Security model — WhiteRabbitNeo V3-7B Q5_K_M (~6 GB). Trained on
  # offensive/defensive security and ships a no-refuse system prompt. Serves the
  # same :8080 OpenAI API, so it's a drop-in swap for the 9B.
  #   huggingface-cli download bartowski/WhiteRabbitNeo_WhiteRabbitNeo-V3-7B-GGUF \
  #     --include "*Q5_K_M.gguf" --local-dir /data/models
  #############################################################################
  systemd.services.llama-sec = (gpuUnit "llama-sec.service") // {
    description = "WhiteRabbitNeo V3-7B (security)";
    serviceConfig.ExecStart = ''
      ${vulkan}/bin/llama-server \
        -m ${modelDir}/WhiteRabbitNeo_WhiteRabbitNeo-V3-7B-Q5_K_M.gguf \
        --host 127.0.0.1 --port 8080 \
        -c 16384 -ngl 99 --flash-attn on --jinja
    '';
  };

  #############################################################################
  # Agent model — Qwen2.5-Coder-14B-Instruct Q4_K_M (~9 GB). Stronger multi-step
  # tool-calling than the 7B for the ReAct loop; --jinja turns on template-driven
  # tool calls. Needs its weights present before it'll start:
  #   huggingface-cli download bartowski/Qwen2.5-Coder-14B-Instruct-GGUF \
  #     --include "*Q4_K_M.gguf" --local-dir /data/models
  #############################################################################
  systemd.services.llama-agent = (gpuUnit "llama-agent.service") // {
    description = "Qwen2.5-Coder-14B (agent / tool-calling)";
    serviceConfig.ExecStart = ''
      ${vulkan}/bin/llama-server \
        -m ${modelDir}/Qwen2.5-Coder-14B-Instruct-Q4_K_M.gguf \
        --host 127.0.0.1 --port 8080 \
        -c 16384 -ngl 99 --flash-attn on --jinja
    '';
  };

  #############################################################################
  # FIM completer — Qwen2.5-Coder-3B Q8_0 (~3.3 GB) for llama.vim, on :8012.
  # No -ngl (kept light); Conflicts with the GPU units as you had it, so it
  # can't collide with a model already holding the card.
  #
  # NOTE: if you'd rather run completions *while* chatting, drop this unit out of
  # the Conflicts set (remove "llama-fim.service" from the gpuUnit list) — with
  # no -ngl it stays on CPU and won't touch the 3060's VRAM.
  #############################################################################
  systemd.services.llama-fim = (gpuUnit "llama-fim.service") // {
    description = "Qwen2.5-Coder-3B FIM (llama.vim)";
    serviceConfig.ExecStart = ''
      ${vulkan}/bin/llama-server \
        -m ${modelDir}/qwen2.5-coder-3b-q8_0.gguf \
        --host 127.0.0.1 --port 8012 \
        -c 8192
    '';
  };
}
