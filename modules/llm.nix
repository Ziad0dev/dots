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
#   systemctl start llama-gemma   # Gemma 4 12B     general + vision/audio :8080
#   systemctl start llama-coder   # Gemma 4 26B A4B MoE coder, expert offload :8080
#   systemctl start llama-fim     # Qwen2.5-Coder   3B FIM for llama.vim   :8012
#
# All six expose an OpenAI-compatible API, so your chat client and any ReAct
# harness just point at the port of whichever is running.

{ config, lib, pkgs, username, ... }:

let
  modelDir = "/data/models";
  vulkan   = pkgs.llama-cpp-vulkan;

  # Ollama (modules/ollama.nix) shares this card. Before any llama-server
  # takes the GPU, ask ollama to release whatever it's holding — setting
  # keep_alive 0 on a loaded model unloads it immediately. Every step is
  # best-effort: if ollama isn't running, this is a no-op and the unit starts
  # normally.
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

  # Shared unit conventions for every model server. Pass the unit's own name so
  # it's excluded from its Conflicts= set.
  gpuUnit = self: {
    after     = [ "data.mount" ];
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
      StartLimitBurst   = 5;      # raise if a flapping start trips the limiter
    };
    wantedBy = lib.mkForce [ ];   # manual start only — never autostart at boot
    serviceConfig.ExecStartPre = freeGpu;
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
  systemd.services.llama-sec = lib.recursiveUpdate (gpuUnit "llama-sec.service") {
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
  systemd.services.llama-agent = lib.recursiveUpdate (gpuUnit "llama-agent.service") {
    description = "Qwen2.5-Coder-14B (agent / tool-calling)";
    serviceConfig.ExecStart = ''
      ${vulkan}/bin/llama-server \
        -m ${modelDir}/Qwen2.5-Coder-14B-Instruct-Q4_K_M.gguf \
        --host 127.0.0.1 --port 8080 \
        -c 16384 -ngl 99 --flash-attn on --jinja
    '';
  };

  #############################################################################
  # Gemma 4 12B Unified Q4_K_M (~7.5 GB) — fits the 3060 entirely with room
  # for a long context. Apache 2.0, 48 layers, 256K native context.
  #
  # "Unified" = encoder-free: image patches and audio waveforms are projected
  # straight into the embedding space by linear layers, so there is NO
  # separate mmproj file to pass. Vision and audio come from the one GGUF.
  #
  # Google's recommended sampling is temp 1.0 / top-p 0.95 / top-k 64 across
  # all use cases — unusual, but it's what the model was tuned against.
  #
  # THINKING IS PROMPT-CONTROLLED, not a flag: put the literal token <|think|>
  # at the start of your system prompt to enable it, omit it to disable. With
  # thinking off the model still emits an empty thought block, which is
  # expected, not a template bug.
  #
  #   hf download <a Q4_K_M GGUF quant of google/gemma-4-12B-it> \
  #     --include "*Q4_K_M.gguf" --local-dir /data/models
  #############################################################################
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

  #############################################################################
  # Gemma 4 26B A4B Q4_K_M (~14.5 GB) — the best coder that is actually
  # PRACTICAL on a 12 GB card. 25.2B total but only 3.8B active per token
  # (8 of 128 experts + 1 shared), so the ~3 GB that won't fit in VRAM costs
  # far less than the same spill would on a dense model: idle experts occupy
  # RAM without sitting on the decode path.
  #
  # LiveCodeBench v6 77.1% / Codeforces 1718 — ahead of the 12B (72.0 / 1659)
  # and close to the 31B dense, which does not fit here at all.
  #
  # --n-cpu-moe pushes expert tensors for N layers to system RAM while keeping
  # attention on the GPU. 10 of 30 layers is a starting guess; lower it until
  # llama-server OOMs on the 3060, then add one back. Watch total RAM — you
  # have 15.4 GB and Plasma wants its share.
  #
  # Text and image only on this one; audio is 12B/E2B/E4B.
  #
  # The dense alternative is Qwen3.6-27B (77.2 SWE-bench Verified, the best
  # dense open coder), but at ~16 GB Q4_K_M every spilled layer runs on every
  # token — single-digit tok/s here. Use it only for one-shot hard problems:
  #   -m Qwen3.6-27B-Q4_K_M.gguf -ngl 40 --cache-type-k q8_0 --cache-type-v q8_0
  #############################################################################
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

  #############################################################################
  # FIM completer — Qwen2.5-Coder-3B Q8_0 (~3.3 GB) for llama.vim, on :8012.
  # No -ngl (kept light); Conflicts with the GPU units as you had it, so it
  # can't collide with a model already holding the card.
  #
  # NOTE: if you'd rather run completions *while* chatting, drop this unit out of
  # the Conflicts set (remove "llama-fim.service" from the gpuUnit list) — with
  # no -ngl it stays on CPU and won't touch the 3060's VRAM.
  #############################################################################
  systemd.services.llama-fim = lib.recursiveUpdate (gpuUnit "llama-fim.service") {
    description = "Qwen2.5-Coder-3B FIM (llama.vim)";
    serviceConfig.ExecStart = ''
      ${vulkan}/bin/llama-server \
        -m ${modelDir}/qwen2.5-coder-3b-q8_0.gguf \
        --host 127.0.0.1 --port 8012 \
        -c 8192
    '';
  };

  #############################################################################
  # Host-side bits. These were in this module originally and were lost when it
  # got rewritten in 403d687 — restored here.
  #
  # The tmpfiles rule matters more than it looks: without it a fresh machine
  # (or a wiped /data) has no model directory, and every llama-* unit above
  # fails to start with nothing obvious in the logs to explain why.
  #
  # /data/models/ollama is NOT listed here — modules/ollama.nix points the
  # daemon at it and the upstream module creates it with the right ownership.
  #############################################################################
  systemd.tmpfiles.rules = [
    "d /data/models 0755 ${username} users -"
  ];

  environment.systemPackages = with pkgs; [
    nvtopPackages.nvidia

    # Puts llama-cli / llama-bench / llama-quantize on PATH. The units above
    # reference the store path directly, so they work without this — but the
    # CLI tools don't.
    vulkan
  ];
}
