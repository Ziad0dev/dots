{ pkgs, config, username, ... }:

# ── Local LLM inference ───────────────────────────────────────────────────────
# llama.cpp with CUDA, serving one model over an OpenAI-compatible HTTP API on
# 127.0.0.1:8080. Weights live on /data (they're 6-20 GB each and there's no
# reason to burn root space or push them through the Nix store).
#
# Sizing note — this box has ~15.4 GiB RAM and 12 GiB VRAM, and swapDevices is
# empty (zram only). That rules out the MoE-offload trick, where routed experts
# of a 35B-A3B live in system RAM: that wants 32 GB. So everything here is
# built around a dense model that fits entirely in VRAM, which is also the
# faster and much less fiddly option.
#
# This file owns nothing that configuration.nix owns except an extra entry in
# nix.settings.substituters — that option is a list and merges across modules,
# so both declarations coexist.

{
  # ── CUDA binary cache ──────────────────────────────────────────────────────
  # llama-cpp.override { cudaSupport = true; } pulls a large CUDA closure. Get
  # it from cuda-maintainers rather than compiling it on 6 cores.
  #
  # Caveat: nixpkgs follows chaotic/nixpkgs here, and this cache is populated
  # against nixpkgs-unstable revisions. Chaotic tracks unstable closely so hits
  # are likely but not guaranteed — if the first rebuild starts compiling
  # cudatoolkit, that's a miss and it's worth waiting for the next flake update
  # rather than sitting through the build.
  nix.settings = {
    substituters = [ "https://cuda-maintainers.cachix.org" ];
    trusted-public-keys = [
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
    ];
  };

  # ── The server ─────────────────────────────────────────────────────────────
  # Model file is a *quoted string* path deliberately: an unquoted path literal
  # would be copied into the Nix store at eval time, which for a 7 GB GGUF is
  # not what anyone wants.
  #
  # Download the weights once, imperatively:
  #   mkdir -p /data/models && cd /data/models
  #   nix run nixpkgs#huggingface-hub -- \
  #     hf download unsloth/Qwen3.5-9B-Instruct-GGUF \
  #     Qwen3.5-9B-Instruct-UD-Q6_K_XL.gguf --local-dir .
  #
  # Q6_K on a 9B is ~7.5 GB of weights. With a q8_0 KV cache that leaves room
  # for a 64k context inside 12 GiB, so there's no reason to drop to Q4 here —
  # Q4 is for when the model doesn't otherwise fit, and this one does.
  services.llama-cpp = {
    enable  = true;
    package = pkgs.llama-cpp.override { cudaSupport = true; };
    model   = "/data/models/Qwen3.5-9B-Instruct-UD-Q6_K_XL.gguf";
    host    = "127.0.0.1";
    port    = 8080;
    openFirewall = false;   # loopback only; tunnel over ssh if you want it remote

    extraFlags = [
      "-ngl" "99"            # every layer on the GPU — the whole point of a dense fit
      "--flash-attn" "on"    # newer llama.cpp takes on/off/auto here, not 0/1
      "-c" "65536"           # 64k context; drop to 32768 if VRAM gets tight
      "-ctk" "q8_0"          # quantized KV cache, roughly halves cache VRAM
      "-ctv" "q8_0"
      "-t" "6"               # 12400f is 6 physical cores, no E-cores.
                             # Hyperthreads hurt llama.cpp — do not use 12.
      "-b" "2048"            # bigger prompt-processing batch; helps long prompts
      "-ub" "512"
      "--jinja"              # use the model's own chat template
      "--mlock"              # keep weights resident; matters more with no swap
    ];
  };

  # /data is mounted nofail behind a LUKS unlock. Without this the service
  # races the mount on boot and fails with a missing model file.
  systemd.services.llama-cpp = {
    unitConfig.RequiresMountsFor = "/data";
    serviceConfig = {
      # --mlock needs the capability, and the unit runs sandboxed by default.
      AmbientCapabilities = [ "CAP_IPC_LOCK" ];
      LimitMEMLOCK = "infinity";
      Restart = "on-failure";
      RestartSec = 10;
    };
  };

  systemd.tmpfiles.rules = [
    "d /data/models 0755 ${username} users -"
  ];

  environment.systemPackages = with pkgs; [
    nvtopPackages.nvidia   # watch VRAM headroom while tuning -c / -ctk
    # llama-bench and llama-cli ship inside the llama-cpp package above, but
    # that package isn't in systemPackages — it's only referenced by the
    # service. Uncomment if you want the CLI tools on PATH:
    # (llama-cpp.override { cudaSupport = true; })
  ];

  # ── Optional frontend ──────────────────────────────────────────────────────
  # llama-server has a usable built-in web UI at http://127.0.0.1:8080 already.
  # open-webui only earns its keep if you want persistent chat history and
  # multi-model switching — it drags in a Python stack and its own state dir.
  #
  # services.open-webui = {
  #   enable = true;
  #   port = 8081;
  #   environment = {
  #     OLLAMA_BASE_URL = "";
  #     OPENAI_API_BASE_URL = "http://127.0.0.1:8080/v1";
  #     WEBUI_AUTH = "False";
  #   };
  # };
}
